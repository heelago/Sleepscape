import type { AppState } from '../state/AppState';
import { hexToRgb01 } from '../state/types';
import { StrokeRenderer } from './StrokeRenderer';
import { EllipseRenderer } from './EllipseRenderer';
import { ParticleRenderer } from './ParticleRenderer';
import { PostProcessing } from './PostProcessing';
import { BreathPulse } from './BreathPulse';
import type { DrawingEngine } from '../drawing/DrawingEngine';

export interface FBO {
  framebuffer: WebGLFramebuffer;
  texture: WebGLTexture;
  width: number;
  height: number;
}

/** Compile a shader from source. */
export function compileShader(gl: WebGL2RenderingContext, type: number, source: string): WebGLShader {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const info = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(`Shader compile error: ${info}`);
  }
  return shader;
}

/** Link a program from vertex + fragment shaders. */
export function linkProgram(gl: WebGL2RenderingContext, vs: WebGLShader, fs: WebGLShader): WebGLProgram {
  const prog = gl.createProgram()!;
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(prog);
    gl.deleteProgram(prog);
    throw new Error(`Program link error: ${info}`);
  }
  return prog;
}

/** Create shader program from source strings. */
export function createProgram(gl: WebGL2RenderingContext, vertSrc: string, fragSrc: string): WebGLProgram {
  const vs = compileShader(gl, gl.VERTEX_SHADER, vertSrc);
  const fs = compileShader(gl, gl.FRAGMENT_SHADER, fragSrc);
  return linkProgram(gl, vs, fs);
}

/** Create a framebuffer object with a color texture attachment. */
export function createFBO(gl: WebGL2RenderingContext, width: number, height: number): FBO {
  const tex = gl.createTexture()!;
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

  const fb = gl.createFramebuffer()!;
  gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);

  const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
  if (status !== gl.FRAMEBUFFER_COMPLETE) {
    throw new Error(`Framebuffer not complete: ${status}`);
  }

  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  gl.bindTexture(gl.TEXTURE_2D, null);

  return { framebuffer: fb, texture: tex, width, height };
}

/** Resize an existing FBO. */
export function resizeFBO(gl: WebGL2RenderingContext, fbo: FBO, width: number, height: number): void {
  fbo.width = width;
  fbo.height = height;
  gl.bindTexture(gl.TEXTURE_2D, fbo.texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
  gl.bindTexture(gl.TEXTURE_2D, null);
}

// ── Shader sources ──
import quadVertSrc from './shaders/quad.vert.glsl';
import compositeFrag from './shaders/composite.frag.glsl';

/**
 * Core WebGL2 renderer: manages canvas, FBOs, render loop, and compositing.
 */
export class WebGLRenderer {
  readonly canvas: HTMLCanvasElement;
  readonly gl: WebGL2RenderingContext;
  private state: AppState;

  // FBOs
  strokeFBO!: FBO;
  private compositeFBO!: FBO; // for brightness cap pass

  // Programs
  private compositeProgram!: WebGLProgram;
  private compositeTexLoc!: WebGLUniformLocation;

  // Sub-renderers
  strokeRenderer!: StrokeRenderer;
  ellipseRenderer!: EllipseRenderer;
  particleRenderer!: ParticleRenderer;
  postProcessing!: PostProcessing;
  breathPulse!: BreathPulse;

  // Reference to drawing engine (set after construction)
  drawingEngine: DrawingEngine | null = null;

  // Canvas pixel dimensions
  pixelWidth = 0;
  pixelHeight = 0;
  dpr = 1;

  private animFrame = 0;
  private startTime = performance.now() / 1000;

  constructor(canvas: HTMLCanvasElement, state: AppState) {
    this.canvas = canvas;
    this.state = state;

    const gl = canvas.getContext('webgl2', {
      alpha: false,
      antialias: false,
      premultipliedAlpha: false,
      preserveDrawingBuffer: true,
    });
    if (!gl) throw new Error('WebGL2 not supported');
    this.gl = gl;

    this.setup();
  }

  private setup(): void {
    const gl = this.gl;

    // Composite program (full-screen quad blit)
    this.compositeProgram = createProgram(gl, quadVertSrc, compositeFrag);
    this.compositeTexLoc = gl.getUniformLocation(this.compositeProgram, 'uTexture')!;

    // Stroke renderer
    this.strokeRenderer = new StrokeRenderer(gl, this);

    // Ellipse renderer
    this.ellipseRenderer = new EllipseRenderer(gl, this);

    // Particle renderer
    this.particleRenderer = new ParticleRenderer(gl, this);

    // Post-processing
    this.postProcessing = new PostProcessing(gl, this);

    // Breath pulse
    this.breathPulse = new BreathPulse(gl, this);

    // Initial resize
    this.resize();

    // Listen for resize
    const ro = new ResizeObserver(() => this.resize());
    ro.observe(this.canvas);
  }

  resize(): void {
    const gl = this.gl;
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    const displayWidth = this.canvas.clientWidth;
    const displayHeight = this.canvas.clientHeight;
    this.pixelWidth = Math.floor(displayWidth * this.dpr);
    this.pixelHeight = Math.floor(displayHeight * this.dpr);

    if (this.canvas.width !== this.pixelWidth || this.canvas.height !== this.pixelHeight) {
      this.canvas.width = this.pixelWidth;
      this.canvas.height = this.pixelHeight;

      // Recreate or resize FBOs
      if (!this.strokeFBO) {
        this.strokeFBO = createFBO(gl, this.pixelWidth, this.pixelHeight);
        this.compositeFBO = createFBO(gl, this.pixelWidth, this.pixelHeight);
      } else {
        resizeFBO(gl, this.strokeFBO, this.pixelWidth, this.pixelHeight);
        resizeFBO(gl, this.compositeFBO, this.pixelWidth, this.pixelHeight);
      }

      // Clear stroke FBO to background color
      this.clearStrokeTexture();
    }
  }

  clearStrokeTexture(): void {
    const gl = this.gl;
    const [r, g, b] = hexToRgb01(this.state.canvasBackground.hex);
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.strokeFBO.framebuffer);
    gl.viewport(0, 0, this.pixelWidth, this.pixelHeight);
    gl.clearColor(r, g, b, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }

  /** Blit a texture to the target (null = screen) using the composite program. */
  blitTexture(texture: WebGLTexture, target: WebGLFramebuffer | null, blend: 'none' | 'alpha' | 'additive' = 'none'): void {
    const gl = this.gl;
    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, this.pixelWidth, this.pixelHeight);

    if (blend === 'none') {
      gl.disable(gl.BLEND);
    } else {
      gl.enable(gl.BLEND);
      if (blend === 'alpha') {
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      } else {
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE);
      }
    }

    gl.useProgram(this.compositeProgram);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.uniform1i(this.compositeTexLoc, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  /** Main render loop frame -- full pipeline matching Metal render order. */
  draw = (): void => {
    const gl = this.gl;
    const time = performance.now() / 1000 - this.startTime;
    const state = this.state;
    const bgColor = hexToRgb01(state.canvasBackground.hex);
    const inkColor = hexToRgb01(state.currentInkHex);
    const useBrightnessCap = state.brightnessCap < 1.0;

    // The target for most passes: compositeFBO if we need brightness cap, else screen
    const compositeTarget = useBrightnessCap ? this.compositeFBO.framebuffer : null;

    // Update particles
    if (this.drawingEngine) {
      this.drawingEngine.updateParticles(this.pixelWidth, this.pixelHeight, time);
    }

    // 1. Blit stroke texture to composite target (no blend, overwrites)
    this.blitTexture(this.strokeFBO.texture, compositeTarget, 'none');

    // 2. Center glow (additive)
    this.postProcessing.renderCenterGlow(compositeTarget, inkColor, 0.6);

    // 3. Bloom (bright-pass + blur + additive composite)
    this.postProcessing.renderBloom(this.strokeFBO.texture, compositeTarget, bgColor);

    // 4. Particles
    gl.bindFramebuffer(gl.FRAMEBUFFER, compositeTarget);
    gl.viewport(0, 0, this.pixelWidth, this.pixelHeight);

    if (this.drawingEngine) {
      const engine = this.drawingEngine;

      // Ambient blooms (additive)
      if (engine.ambientBlooms.length > 0) {
        this.particleRenderer.renderAmbientBlooms(engine.ambientBlooms);
      }

      // Sparkles (additive)
      if (engine.sparkles.length > 0) {
        this.particleRenderer.renderSparkles(engine.sparkles);
      }

      // Ripples (alpha blend)
      if (engine.ripples.length > 0) {
        this.particleRenderer.renderRipples(engine.ripples);
      }
    }

    // 5. Breath pulse (additive, rendered on top of all drawing content)
    if (state.breathPulseEnabled) {
      const opacity = (state as any).breathPulseOpacity ?? 0.5;
      this.breathPulse.render(
        compositeTarget, time, inkColor, opacity, state.breathPhases,
      );
    }

    // 6. Brightness cap (reads compositeFBO, writes to screen)
    if (useBrightnessCap) {
      this.postProcessing.renderBrightnessCap(
        this.compositeFBO.texture, null, state.brightnessCap,
      );
    }

    // 7. Vignette (alpha blend, always last)
    this.postProcessing.renderVignette(null);

    this.animFrame = requestAnimationFrame(this.draw);
  };

  start(): void {
    this.animFrame = requestAnimationFrame(this.draw);
  }

  stop(): void {
    cancelAnimationFrame(this.animFrame);
  }
}
