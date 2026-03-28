import { createProgram } from './WebGLRenderer';
import type { WebGLRenderer } from './WebGLRenderer';

import quadVertSrc from './shaders/quad.vert.glsl';
import breathPulseFrag from './shaders/breathpulse.frag.glsl';

/**
 * Renders the breathing pulse ring -- a 60-dot gaussian ring that expands/contracts
 * through 4 phases (inhale, hold, exhale, hold2).
 */
export class BreathPulse {
  private gl: WebGL2RenderingContext;
  private renderer: WebGLRenderer;

  private program: WebGLProgram;
  private u_canvasSize: WebGLUniformLocation;
  private u_center: WebGLUniformLocation;
  private u_maxRadius: WebGLUniformLocation;
  private u_time: WebGLUniformLocation;
  private u_color: WebGLUniformLocation;
  private u_fadeIn: WebGLUniformLocation;
  private u_inhale: WebGLUniformLocation;
  private u_hold: WebGLUniformLocation;
  private u_exhale: WebGLUniformLocation;
  private u_hold2: WebGLUniformLocation;

  constructor(gl: WebGL2RenderingContext, renderer: WebGLRenderer) {
    this.gl = gl;
    this.renderer = renderer;

    this.program = createProgram(gl, quadVertSrc, breathPulseFrag);
    this.u_canvasSize = gl.getUniformLocation(this.program, 'uCanvasSize')!;
    this.u_center = gl.getUniformLocation(this.program, 'uCenter')!;
    this.u_maxRadius = gl.getUniformLocation(this.program, 'uMaxRadius')!;
    this.u_time = gl.getUniformLocation(this.program, 'uTime')!;
    this.u_color = gl.getUniformLocation(this.program, 'uColor')!;
    this.u_fadeIn = gl.getUniformLocation(this.program, 'uFadeIn')!;
    this.u_inhale = gl.getUniformLocation(this.program, 'uInhale')!;
    this.u_hold = gl.getUniformLocation(this.program, 'uHold')!;
    this.u_exhale = gl.getUniformLocation(this.program, 'uExhale')!;
    this.u_hold2 = gl.getUniformLocation(this.program, 'uHold2')!;
  }

  render(
    target: WebGLFramebuffer | null,
    time: number,
    color: [number, number, number],
    fadeIn: number,
    phases: { inhale: number; hold: number; exhale: number; hold2: number },
    maxRadius?: number,
  ): void {
    const gl = this.gl;
    const w = this.renderer.pixelWidth;
    const h = this.renderer.pixelHeight;
    const radius = maxRadius ?? Math.min(w, h) * 0.25;

    gl.bindFramebuffer(gl.FRAMEBUFFER, target);
    gl.viewport(0, 0, w, h);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive

    gl.useProgram(this.program);
    gl.uniform2f(this.u_canvasSize, w, h);
    gl.uniform2f(this.u_center, w / 2, h / 2);
    gl.uniform1f(this.u_maxRadius, radius);
    gl.uniform1f(this.u_time, time);
    gl.uniform4f(this.u_color, color[0], color[1], color[2], 1.0);
    gl.uniform1f(this.u_fadeIn, fadeIn);
    gl.uniform1f(this.u_inhale, phases.inhale);
    gl.uniform1f(this.u_hold, phases.hold);
    gl.uniform1f(this.u_exhale, phases.exhale);
    gl.uniform1f(this.u_hold2, phases.hold2);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
}
