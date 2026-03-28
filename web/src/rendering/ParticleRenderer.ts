import { createProgram } from './WebGLRenderer';
import type { WebGLRenderer } from './WebGLRenderer';

import rippleVertSrc from './shaders/ripple.vert.glsl';
import rippleFragSrc from './shaders/ripple.frag.glsl';
import sparkleVertSrc from './shaders/sparkle.vert.glsl';
import sparkleFragSrc from './shaders/sparkle.frag.glsl';
import bloomVertSrc from './shaders/ambientbloom.vert.glsl';
import bloomFragSrc from './shaders/ambientbloom.frag.glsl';

// ── Particle data types ──

export interface Ripple {
  centerX: number;
  centerY: number;
  radius: number;
  maxRadius: number;
  alpha: number;
  speed: number;
  colorR: number;
  colorG: number;
  colorB: number;
  rings: number;
}

export interface Sparkle {
  x: number;
  y: number;
  alpha: number;
  size: number;
  colorR: number;
  colorG: number;
  colorB: number;
  life: number;
}

export interface AmbientBloom {
  centerX: number;
  centerY: number;
  radius: number;
  maxRadius: number;
  alpha: number;
  targetAlpha: number;
  colorR: number;
  colorG: number;
  colorB: number;
  phase: 'fadeIn' | 'fadeOut';
  phaseTimer: number;
}

const MAX_RIPPLES = 256;
const MAX_SPARKLES = 200;
const MAX_BLOOMS = 8;

/** 6 vertices per quad: 2 triangles */
const QUAD_CORNERS = new Float32Array([
  -1, -1,  1, -1,  -1, 1,
  -1,  1,  1, -1,   1, 1,
]);

/**
 * Renders ripple, sparkle, and ambient bloom particles using instanced quads.
 */
export class ParticleRenderer {
  private gl: WebGL2RenderingContext;
  private renderer: WebGLRenderer;

  // Ripple
  private rippleProgram: WebGLProgram;
  private rippleVAO: WebGLVertexArrayObject;
  private rippleInstanceBuf: WebGLBuffer;
  private rippleQuadBuf: WebGLBuffer;
  private ripple_uCanvasSize: WebGLUniformLocation;

  // Sparkle
  private sparkleProgram: WebGLProgram;
  private sparkleVAO: WebGLVertexArrayObject;
  private sparkleInstanceBuf: WebGLBuffer;
  private sparkleQuadBuf: WebGLBuffer;
  private sparkle_uCanvasSize: WebGLUniformLocation;

  // Ambient bloom
  private bloomProgram: WebGLProgram;
  private bloomVAO: WebGLVertexArrayObject;
  private bloomInstanceBuf: WebGLBuffer;
  private bloomQuadBuf: WebGLBuffer;
  private bloom_uCanvasSize: WebGLUniformLocation;

  constructor(gl: WebGL2RenderingContext, renderer: WebGLRenderer) {
    this.gl = gl;
    this.renderer = renderer;

    // ── Ripple setup ──
    this.rippleProgram = createProgram(gl, rippleVertSrc, rippleFragSrc);
    this.ripple_uCanvasSize = gl.getUniformLocation(this.rippleProgram, 'uCanvasSize')!;
    this.rippleInstanceBuf = gl.createBuffer()!;
    this.rippleQuadBuf = gl.createBuffer()!;
    this.rippleVAO = this.buildRippleVAO();

    // ── Sparkle setup ──
    this.sparkleProgram = createProgram(gl, sparkleVertSrc, sparkleFragSrc);
    this.sparkle_uCanvasSize = gl.getUniformLocation(this.sparkleProgram, 'uCanvasSize')!;
    this.sparkleInstanceBuf = gl.createBuffer()!;
    this.sparkleQuadBuf = gl.createBuffer()!;
    this.sparkleVAO = this.buildSparkleVAO();

    // ── Ambient bloom setup ──
    this.bloomProgram = createProgram(gl, bloomVertSrc, bloomFragSrc);
    this.bloom_uCanvasSize = gl.getUniformLocation(this.bloomProgram, 'uCanvasSize')!;
    this.bloomInstanceBuf = gl.createBuffer()!;
    this.bloomQuadBuf = gl.createBuffer()!;
    this.bloomVAO = this.buildBloomVAO();
  }

  // ── Ripple VAO ──
  // Per-instance: center(2) + radius(1) + alpha(1) + color(4) = 8 floats = 32 bytes
  // Per-vertex: quadCorner(2)
  private buildRippleVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    // Instance data (loc 0-3)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.rippleInstanceBuf);
    // center (loc 0)
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 32, 0);
    gl.vertexAttribDivisor(0, 1);
    // radius (loc 1)
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 1, gl.FLOAT, false, 32, 8);
    gl.vertexAttribDivisor(1, 1);
    // alpha (loc 2)
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 32, 12);
    gl.vertexAttribDivisor(2, 1);
    // color (loc 3)
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 4, gl.FLOAT, false, 32, 16);
    gl.vertexAttribDivisor(3, 1);

    // Quad corners (loc 4)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.rippleQuadBuf);
    gl.bufferData(gl.ARRAY_BUFFER, QUAD_CORNERS, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 2, gl.FLOAT, false, 0, 0);

    gl.bindVertexArray(null);
    return vao;
  }

  // ── Sparkle VAO ──
  // Per-instance: position(2) + alpha(1) + size(1) + color(4) = 8 floats = 32 bytes
  private buildSparkleVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.sparkleInstanceBuf);
    // position (loc 0)
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 32, 0);
    gl.vertexAttribDivisor(0, 1);
    // alpha (loc 1)
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 1, gl.FLOAT, false, 32, 8);
    gl.vertexAttribDivisor(1, 1);
    // size (loc 2)
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 32, 12);
    gl.vertexAttribDivisor(2, 1);
    // color (loc 3)
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 4, gl.FLOAT, false, 32, 16);
    gl.vertexAttribDivisor(3, 1);

    // Quad corners (loc 4)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.sparkleQuadBuf);
    gl.bufferData(gl.ARRAY_BUFFER, QUAD_CORNERS, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 2, gl.FLOAT, false, 0, 0);

    gl.bindVertexArray(null);
    return vao;
  }

  // ── Bloom VAO ──
  // Per-instance: center(2) + radius(1) + alpha(1) + color(4) + progress(1) = 9 floats = 36 bytes
  private buildBloomVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bloomInstanceBuf);
    // center (loc 0)
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 36, 0);
    gl.vertexAttribDivisor(0, 1);
    // radius (loc 1)
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 1, gl.FLOAT, false, 36, 8);
    gl.vertexAttribDivisor(1, 1);
    // alpha (loc 2)
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 36, 12);
    gl.vertexAttribDivisor(2, 1);
    // color (loc 3)
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 4, gl.FLOAT, false, 36, 16);
    gl.vertexAttribDivisor(3, 1);
    // progress (loc 4)
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 1, gl.FLOAT, false, 36, 32);
    gl.vertexAttribDivisor(4, 1);

    // Quad corners (loc 5)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.bloomQuadBuf);
    gl.bufferData(gl.ARRAY_BUFFER, QUAD_CORNERS, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(5);
    gl.vertexAttribPointer(5, 2, gl.FLOAT, false, 0, 0);

    gl.bindVertexArray(null);
    return vao;
  }

  // ── Render methods ──

  renderRipples(ripples: Ripple[]): void {
    if (ripples.length === 0) return;
    const gl = this.gl;
    const count = Math.min(ripples.length, MAX_RIPPLES);

    // Pack instance data: 8 floats per ripple
    const data = new Float32Array(count * 8);
    for (let i = 0; i < count; i++) {
      const r = ripples[i];
      const o = i * 8;
      data[o] = r.centerX; data[o + 1] = r.centerY;
      data[o + 2] = r.radius;
      data[o + 3] = r.alpha;
      data[o + 4] = r.colorR; data[o + 5] = r.colorG; data[o + 6] = r.colorB; data[o + 7] = 1.0;
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, this.rippleInstanceBuf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);

    gl.useProgram(this.rippleProgram);
    gl.uniform2f(this.ripple_uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.bindVertexArray(this.rippleVAO);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, count);
    gl.bindVertexArray(null);
  }

  renderSparkles(sparkles: Sparkle[]): void {
    if (sparkles.length === 0) return;
    const gl = this.gl;
    const count = Math.min(sparkles.length, MAX_SPARKLES);

    // Pack instance data: 8 floats per sparkle
    const data = new Float32Array(count * 8);
    for (let i = 0; i < count; i++) {
      const s = sparkles[i];
      const o = i * 8;
      data[o] = s.x; data[o + 1] = s.y;
      data[o + 2] = s.alpha;
      data[o + 3] = s.size;
      data[o + 4] = s.colorR; data[o + 5] = s.colorG; data[o + 6] = s.colorB; data[o + 7] = 1.0;
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, this.sparkleInstanceBuf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);

    gl.useProgram(this.sparkleProgram);
    gl.uniform2f(this.sparkle_uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive

    gl.bindVertexArray(this.sparkleVAO);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, count);
    gl.bindVertexArray(null);
  }

  renderAmbientBlooms(blooms: AmbientBloom[]): void {
    if (blooms.length === 0) return;
    const gl = this.gl;
    const count = Math.min(blooms.length, MAX_BLOOMS);

    // Pack instance data: 9 floats per bloom
    const data = new Float32Array(count * 9);
    for (let i = 0; i < count; i++) {
      const b = blooms[i];
      const o = i * 9;
      const progress = b.radius / b.maxRadius;
      data[o] = b.centerX; data[o + 1] = b.centerY;
      data[o + 2] = b.radius;
      data[o + 3] = b.alpha;
      data[o + 4] = b.colorR; data[o + 5] = b.colorG; data[o + 6] = b.colorB; data[o + 7] = 1.0;
      data[o + 8] = progress;
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bloomInstanceBuf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);

    gl.useProgram(this.bloomProgram);
    gl.uniform2f(this.bloom_uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive

    gl.bindVertexArray(this.bloomVAO);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, count);
    gl.bindVertexArray(null);
  }
}
