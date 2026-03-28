import { createProgram, createFBO, resizeFBO, type FBO } from './WebGLRenderer';
import type { WebGLRenderer } from './WebGLRenderer';

import quadVertSrc from './shaders/quad.vert.glsl';
import brightpassFrag from './shaders/brightpass.frag.glsl';
import blurFrag from './shaders/blur.frag.glsl';
import compositeFrag from './shaders/composite.frag.glsl';
import vignetteFrag from './shaders/vignette.frag.glsl';
import brightnessCapFrag from './shaders/brightnesscap.frag.glsl';
import centerGlowFrag from './shaders/centerglow.frag.glsl';

/**
 * Post-processing pipeline: bloom extraction, gaussian blur, compositing,
 * center glow, brightness cap, and vignette.
 */
export class PostProcessing {
  private gl: WebGL2RenderingContext;
  private renderer: WebGLRenderer;

  // FBOs (half-resolution for bloom)
  private bloomSourceFBO!: FBO;
  private bloomBlurA!: FBO;
  private bloomBlurB!: FBO;

  // Programs
  private brightpassProg: WebGLProgram;
  private brightpass_uTex: WebGLUniformLocation;
  private brightpass_uBgColor: WebGLUniformLocation;

  private blurProg: WebGLProgram;
  private blur_uTex: WebGLUniformLocation;
  private blur_uDirection: WebGLUniformLocation;

  private compositeProg: WebGLProgram;
  private composite_uTex: WebGLUniformLocation;

  private vignetteProg: WebGLProgram;

  private brightnessCapProg: WebGLProgram;
  private brightnessCap_uTex: WebGLUniformLocation;
  private brightnessCap_uCap: WebGLUniformLocation;

  private centerGlowProg: WebGLProgram;
  private centerGlow_uCanvasInfo: WebGLUniformLocation;
  private centerGlow_uGlowColor: WebGLUniformLocation;

  constructor(gl: WebGL2RenderingContext, renderer: WebGLRenderer) {
    this.gl = gl;
    this.renderer = renderer;

    // Brightpass
    this.brightpassProg = createProgram(gl, quadVertSrc, brightpassFrag);
    this.brightpass_uTex = gl.getUniformLocation(this.brightpassProg, 'uTexture')!;
    this.brightpass_uBgColor = gl.getUniformLocation(this.brightpassProg, 'uBgColor')!;

    // Blur
    this.blurProg = createProgram(gl, quadVertSrc, blurFrag);
    this.blur_uTex = gl.getUniformLocation(this.blurProg, 'uTexture')!;
    this.blur_uDirection = gl.getUniformLocation(this.blurProg, 'uDirection')!;

    // Composite (additive blit)
    this.compositeProg = createProgram(gl, quadVertSrc, compositeFrag);
    this.composite_uTex = gl.getUniformLocation(this.compositeProg, 'uTexture')!;

    // Vignette
    this.vignetteProg = createProgram(gl, quadVertSrc, vignetteFrag);

    // Brightness cap
    this.brightnessCapProg = createProgram(gl, quadVertSrc, brightnessCapFrag);
    this.brightnessCap_uTex = gl.getUniformLocation(this.brightnessCapProg, 'uTexture')!;
    this.brightnessCap_uCap = gl.getUniformLocation(this.brightnessCapProg, 'uCap')!;

    // Center glow
    this.centerGlowProg = createProgram(gl, quadVertSrc, centerGlowFrag);
    this.centerGlow_uCanvasInfo = gl.getUniformLocation(this.centerGlowProg, 'uCanvasInfo')!;
    this.centerGlow_uGlowColor = gl.getUniformLocation(this.centerGlowProg, 'uGlowColor')!;
  }

  /** Ensure bloom FBOs exist at half resolution. */
  ensureFBOs(fullWidth: number, fullHeight: number): void {
    const halfW = Math.floor(fullWidth / 2);
    const halfH = Math.floor(fullHeight / 2);
    const gl = this.gl;

    if (!this.bloomSourceFBO) {
      this.bloomSourceFBO = createFBO(gl, halfW, halfH);
      this.bloomBlurA = createFBO(gl, halfW, halfH);
      this.bloomBlurB = createFBO(gl, halfW, halfH);
    } else if (this.bloomSourceFBO.width !== halfW || this.bloomSourceFBO.height !== halfH) {
      resizeFBO(gl, this.bloomSourceFBO, halfW, halfH);
      resizeFBO(gl, this.bloomBlurA, halfW, halfH);
      resizeFBO(gl, this.bloomBlurB, halfW, halfH);
    }
  }

  /**
   * Run bloom extraction + blur on the stroke texture, then composite additively
   * onto the target framebuffer (null = screen).
   */
  renderBloom(strokeTexture: WebGLTexture, target: WebGLFramebuffer | null, bgColor: [number, number, number]): void {
    const gl = this.gl;
    this.ensureFBOs(this.renderer.pixelWidth, this.renderer.pixelHeight);
    const halfW = this.bloomSourceFBO.width;
    const halfH = this.bloomSourceFBO.height;

    // 1. Bright-pass extraction (stroke texture -> bloomSourceFBO at half res)
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomSourceFBO.framebuffer);
    gl.viewport(0, 0, halfW, halfH);
    gl.disable(gl.BLEND);

    gl.useProgram(this.brightpassProg);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, strokeTexture);
    gl.uniform1i(this.brightpass_uTex, 0);
    gl.uniform4f(this.brightpass_uBgColor, bgColor[0], bgColor[1], bgColor[2], 1.0);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // 2. Horizontal blur (bloomSource -> bloomBlurA)
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomBlurA.framebuffer);
    gl.viewport(0, 0, halfW, halfH);

    gl.useProgram(this.blurProg);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomSourceFBO.texture);
    gl.uniform1i(this.blur_uTex, 0);
    gl.uniform2f(this.blur_uDirection, 1.0 / halfW, 0.0);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // 3. Vertical blur (bloomBlurA -> bloomBlurB)
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomBlurB.framebuffer);
    gl.viewport(0, 0, halfW, halfH);

    gl.bindTexture(gl.TEXTURE_2D, this.bloomBlurA.texture);
    gl.uniform2f(this.blur_uDirection, 0.0, 1.0 / halfH);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // 4. Additive composite (bloomBlurB -> target at full res)
    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive

    gl.useProgram(this.compositeProg);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomBlurB.texture);
    gl.uniform1i(this.composite_uTex, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  /** Render center glow overlay (additive). */
  renderCenterGlow(target: WebGLFramebuffer | null, inkColor: [number, number, number], intensity: number): void {
    const gl = this.gl;
    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive

    gl.useProgram(this.centerGlowProg);
    gl.uniform4f(this.centerGlow_uCanvasInfo,
      this.renderer.pixelWidth / 2, this.renderer.pixelHeight / 2,
      this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.uniform4f(this.centerGlow_uGlowColor, inkColor[0], inkColor[1], inkColor[2], intensity);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  /** Render vignette darkening overlay (alpha blend). */
  renderVignette(target: WebGLFramebuffer | null): void {
    const gl = this.gl;
    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.useProgram(this.vignetteProg);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  /**
   * Render brightness cap pass. Reads from sourceTexture, writes to target.
   * Since WebGL can't read the framebuffer in-place, this is a render-to-texture pass.
   */
  renderBrightnessCap(sourceTexture: WebGLTexture, target: WebGLFramebuffer | null, cap: number): void {
    if (cap >= 1.0) return; // no capping needed

    const gl = this.gl;
    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.disable(gl.BLEND);

    gl.useProgram(this.brightnessCapProg);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, sourceTexture);
    gl.uniform1i(this.brightnessCap_uTex, 0);
    gl.uniform1f(this.brightnessCap_uCap, cap);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
}
