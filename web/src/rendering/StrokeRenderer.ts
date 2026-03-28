import type { WebGLRenderer } from './WebGLRenderer';
import { createProgram } from './WebGLRenderer';
import { generateTransforms, transformCount } from './SymmetryTransform';
import type { Stroke, StrokePoint, RGBA } from '../state/types';
import { LineStyle, DrawMode } from '../state/types';

import strokeVertSrc from './shaders/stroke.vert.glsl';
import strokeFragSrc from './shaders/stroke.frag.glsl';
import dotVertSrc from './shaders/dot.vert.glsl';
import dotFragSrc from './shaders/dot.frag.glsl';

/**
 * 3-pass glow configuration per line style.
 * Each pass: [widthMultiplier, alpha, glowIntensityScaled]
 */
interface GlowPass {
  widthMul: number;
  alpha: number;
  scaleByGlow: boolean; // whether alpha is scaled by glowIntensity
}

const GLOW_PASSES: Record<number, GlowPass[]> = {
  [LineStyle.Neon]: [
    { widthMul: 3.2, alpha: 0.03, scaleByGlow: true },
    { widthMul: 1.5, alpha: 0.18, scaleByGlow: true },
    { widthMul: 0.5, alpha: 0.90, scaleByGlow: false },
  ],
  [LineStyle.SoftGlow]: [
    { widthMul: 4.0, alpha: 0.06, scaleByGlow: true },
    { widthMul: 2.0, alpha: 0.12, scaleByGlow: true },
    { widthMul: 0.8, alpha: 0.60, scaleByGlow: false },
  ],
  [LineStyle.Dashed]: [
    { widthMul: 3.2, alpha: 0.03, scaleByGlow: true },
    { widthMul: 1.5, alpha: 0.18, scaleByGlow: true },
    { widthMul: 0.5, alpha: 0.90, scaleByGlow: false },
  ],
  [LineStyle.Dotted]: [
    { widthMul: 3.2, alpha: 0.03, scaleByGlow: true },
    { widthMul: 1.5, alpha: 0.18, scaleByGlow: true },
    { widthMul: 0.5, alpha: 0.90, scaleByGlow: false },
  ],
  [LineStyle.Sketch]: [
    { widthMul: 3.0, alpha: 0.04, scaleByGlow: true },
    { widthMul: 1.4, alpha: 0.15, scaleByGlow: true },
    { widthMul: 0.5, alpha: 0.85, scaleByGlow: false },
  ],
};

/** Maximum number of points per stroke buffer upload. */
const MAX_POINTS = 2048;

/**
 * Renders strokes with 3-pass glow system, instanced symmetry, and 5 line styles.
 */
export class StrokeRenderer {
  private gl: WebGL2RenderingContext;
  private renderer: WebGLRenderer;

  // Programs
  private segmentProgram: WebGLProgram;
  private dotProgram: WebGLProgram;

  // Segment program uniforms
  private seg_uCanvasSize: WebGLUniformLocation;
  private seg_uColor: WebGLUniformLocation;
  private seg_uBrushSize: WebGLUniformLocation;
  private seg_uAlpha: WebGLUniformLocation;
  private seg_uLineStyle: WebGLUniformLocation;

  // Dot program uniforms
  private dot_uCanvasSize: WebGLUniformLocation;
  private dot_uColor: WebGLUniformLocation;
  private dot_uBrushSize: WebGLUniformLocation;
  private dot_uAlpha: WebGLUniformLocation;
  private dot_uLineStyle: WebGLUniformLocation;

  // Buffers
  private segmentVAO: WebGLVertexArrayObject;
  private pointBuffer: WebGLBuffer;       // stroke point data
  private pointNextBuffer: WebGLBuffer;   // next point data (for segments)
  private quadCornerBuffer: WebGLBuffer;  // quad corner static data
  private transformBuffer: WebGLBuffer;   // instanced transform matrices

  private dotVAO: WebGLVertexArrayObject;
  private dotPointBuffer: WebGLBuffer;
  private dotTransformBuffer: WebGLBuffer;

  constructor(gl: WebGL2RenderingContext, renderer: WebGLRenderer) {
    this.gl = gl;
    this.renderer = renderer;

    // Compile programs
    this.segmentProgram = createProgram(gl, strokeVertSrc, strokeFragSrc);
    this.dotProgram = createProgram(gl, dotVertSrc, dotFragSrc);

    // Cache uniform locations
    this.seg_uCanvasSize = gl.getUniformLocation(this.segmentProgram, 'uCanvasSize')!;
    this.seg_uColor = gl.getUniformLocation(this.segmentProgram, 'uColor')!;
    this.seg_uBrushSize = gl.getUniformLocation(this.segmentProgram, 'uBrushSize')!;
    this.seg_uAlpha = gl.getUniformLocation(this.segmentProgram, 'uAlpha')!;
    this.seg_uLineStyle = gl.getUniformLocation(this.segmentProgram, 'uLineStyle')!;

    this.dot_uCanvasSize = gl.getUniformLocation(this.dotProgram, 'uCanvasSize')!;
    this.dot_uColor = gl.getUniformLocation(this.dotProgram, 'uColor')!;
    this.dot_uBrushSize = gl.getUniformLocation(this.dotProgram, 'uBrushSize')!;
    this.dot_uAlpha = gl.getUniformLocation(this.dotProgram, 'uAlpha')!;
    this.dot_uLineStyle = gl.getUniformLocation(this.dotProgram, 'uLineStyle')!;

    // Create buffers
    this.pointBuffer = gl.createBuffer()!;
    this.pointNextBuffer = gl.createBuffer()!;
    this.quadCornerBuffer = gl.createBuffer()!;
    this.transformBuffer = gl.createBuffer()!;
    this.dotPointBuffer = gl.createBuffer()!;
    this.dotTransformBuffer = gl.createBuffer()!;

    // Static quad corner data (6 vertices per segment: 2 triangles)
    const quadCorners = new Float32Array(MAX_POINTS * 6 * 2);
    for (let i = 0; i < MAX_POINTS; i++) {
      const o = i * 12;
      // Triangle 1: (0,0), (0,1), (1,0)
      quadCorners[o + 0] = 0; quadCorners[o + 1] = 0;
      quadCorners[o + 2] = 0; quadCorners[o + 3] = 1;
      quadCorners[o + 4] = 1; quadCorners[o + 5] = 0;
      // Triangle 2: (0,1), (1,0), (1,1)
      quadCorners[o + 6] = 0; quadCorners[o + 7] = 1;
      quadCorners[o + 8] = 1; quadCorners[o + 9] = 0;
      quadCorners[o + 10] = 1; quadCorners[o + 11] = 1;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadCornerBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, quadCorners, gl.STATIC_DRAW);

    // Build VAOs
    this.segmentVAO = this.buildSegmentVAO();
    this.dotVAO = this.buildDotVAO();
  }

  private buildSegmentVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    // Per-vertex: point data (repeated 6x per segment via buffer layout)
    // We'll upload interleaved per-segment data and use non-instanced attributes
    // Approach: use separate buffers for current and next points, repeated 6x

    // Point buffer (loc 0-3): position(2), pressure(1), altitude(1), cumulDist(1) = 5 floats
    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointBuffer);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 20, 0);  // position
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 1, gl.FLOAT, false, 20, 8);  // pressure
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 20, 12); // altitude
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 1, gl.FLOAT, false, 20, 16); // cumulDist

    // Next point buffer (loc 4-7)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointNextBuffer);
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 2, gl.FLOAT, false, 20, 0);
    gl.enableVertexAttribArray(5);
    gl.vertexAttribPointer(5, 1, gl.FLOAT, false, 20, 8);
    gl.enableVertexAttribArray(6);
    gl.vertexAttribPointer(6, 1, gl.FLOAT, false, 20, 12);
    gl.enableVertexAttribArray(7);
    gl.vertexAttribPointer(7, 1, gl.FLOAT, false, 20, 16);

    // Quad corner buffer (loc 8)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadCornerBuffer);
    gl.enableVertexAttribArray(8);
    gl.vertexAttribPointer(8, 2, gl.FLOAT, false, 0, 0);

    // Transform buffer (loc 9-11): 3 vec3 columns, instanced
    gl.bindBuffer(gl.ARRAY_BUFFER, this.transformBuffer);
    for (let col = 0; col < 3; col++) {
      const loc = 9 + col;
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 3, gl.FLOAT, false, 36, col * 12);
      gl.vertexAttribDivisor(loc, 1); // per-instance
    }

    gl.bindVertexArray(null);
    return vao;
  }

  private buildDotVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    // Point buffer (loc 0-3): 5 floats per point
    gl.bindBuffer(gl.ARRAY_BUFFER, this.dotPointBuffer);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 20, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 1, gl.FLOAT, false, 20, 8);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 20, 12);
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 1, gl.FLOAT, false, 20, 16);

    // Transform buffer (loc 4-6): instanced
    gl.bindBuffer(gl.ARRAY_BUFFER, this.dotTransformBuffer);
    for (let col = 0; col < 3; col++) {
      const loc = 4 + col;
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 3, gl.FLOAT, false, 36, col * 12);
      gl.vertexAttribDivisor(loc, 1);
    }

    gl.bindVertexArray(null);
    return vao;
  }

  /**
   * Render a single stroke with the 3-pass glow system to the stroke FBO.
   */
  renderStroke(stroke: Stroke, glowIntensity: number): void {
    const { points, color, brushSize, lineStyle, mode, symmetry } = stroke;
    if (points.length < 2) return;

    const gl = this.gl;
    const passes = GLOW_PASSES[lineStyle] || GLOW_PASSES[LineStyle.Neon];

    // Generate symmetry transforms
    const transforms = generateTransforms(mode, symmetry, this.renderer.pixelWidth, this.renderer.pixelHeight);
    const numTransforms = transformCount(mode, symmetry);

    // Bind stroke FBO
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.renderer.strokeFBO.framebuffer);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    for (const pass of passes) {
      const effectiveAlpha = pass.scaleByGlow ? pass.alpha * glowIntensity : pass.alpha;
      const effectiveBrush = brushSize * pass.widthMul;

      // Render segments (skip for dotted -- segments are discarded in shader anyway)
      if (lineStyle !== LineStyle.Dotted) {
        this.renderSegments(points, color, effectiveBrush, effectiveAlpha, lineStyle, transforms, numTransforms);
      }

      // Render dots
      this.renderDots(points, color, effectiveBrush, effectiveAlpha, lineStyle, transforms, numTransforms);
    }

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }

  private renderSegments(
    points: StrokePoint[],
    color: RGBA,
    brushSize: number,
    alpha: number,
    lineStyle: LineStyle,
    transforms: Float32Array,
    numTransforms: number,
  ): void {
    const gl = this.gl;
    const segCount = points.length - 1;
    if (segCount < 1) return;

    // Build per-vertex data: each segment has 6 vertices, each vertex needs current + next point
    // For efficiency, repeat point data 6x per segment
    const FLOATS_PER_POINT = 5;
    const pointData = new Float32Array(segCount * 6 * FLOATS_PER_POINT);
    const nextData = new Float32Array(segCount * 6 * FLOATS_PER_POINT);

    for (let s = 0; s < segCount; s++) {
      const p0 = points[s];
      const p1 = points[s + 1];
      for (let v = 0; v < 6; v++) {
        const i = (s * 6 + v) * FLOATS_PER_POINT;
        pointData[i] = p0.x; pointData[i + 1] = p0.y;
        pointData[i + 2] = p0.pressure; pointData[i + 3] = p0.altitude;
        pointData[i + 4] = p0.cumulDist;

        nextData[i] = p1.x; nextData[i + 1] = p1.y;
        nextData[i + 2] = p1.pressure; nextData[i + 3] = p1.altitude;
        nextData[i + 4] = p1.cumulDist;
      }
    }

    // Upload
    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, pointData, gl.DYNAMIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointNextBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, nextData, gl.DYNAMIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.transformBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, transforms, gl.DYNAMIC_DRAW);

    // Use segment program
    gl.useProgram(this.segmentProgram);
    gl.uniform2f(this.seg_uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.uniform4f(this.seg_uColor, color[0], color[1], color[2], color[3]);
    gl.uniform1f(this.seg_uBrushSize, brushSize);
    gl.uniform1f(this.seg_uAlpha, alpha);
    gl.uniform1ui(this.seg_uLineStyle, lineStyle);

    gl.bindVertexArray(this.segmentVAO);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, segCount * 6, numTransforms);
    gl.bindVertexArray(null);
  }

  private renderDots(
    points: StrokePoint[],
    color: RGBA,
    brushSize: number,
    alpha: number,
    lineStyle: LineStyle,
    transforms: Float32Array,
    numTransforms: number,
  ): void {
    const gl = this.gl;
    const FLOATS_PER_POINT = 5;

    // Build point data
    const dotData = new Float32Array(points.length * FLOATS_PER_POINT);
    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      const o = i * FLOATS_PER_POINT;
      dotData[o] = p.x; dotData[o + 1] = p.y;
      dotData[o + 2] = p.pressure; dotData[o + 3] = p.altitude;
      dotData[o + 4] = p.cumulDist;
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, this.dotPointBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, dotData, gl.DYNAMIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.dotTransformBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, transforms, gl.DYNAMIC_DRAW);

    gl.useProgram(this.dotProgram);
    gl.uniform2f(this.dot_uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.uniform4f(this.dot_uColor, color[0], color[1], color[2], color[3]);
    gl.uniform1f(this.dot_uBrushSize, brushSize);
    gl.uniform1f(this.dot_uAlpha, alpha);
    gl.uniform1ui(this.dot_uLineStyle, lineStyle);

    gl.bindVertexArray(this.dotVAO);
    gl.drawArraysInstanced(gl.POINTS, 0, points.length, numTransforms);
    gl.bindVertexArray(null);
  }

  /**
   * Re-render all strokes to the stroke FBO (used on undo/redo, glow change, etc.)
   */
  reRenderAll(strokes: Stroke[], glowIntensity: number): void {
    this.renderer.clearStrokeTexture();
    for (const stroke of strokes) {
      this.renderStroke(stroke, glowIntensity);
    }
  }
}
