import type { WebGLRenderer } from './WebGLRenderer';
import { createProgram } from './WebGLRenderer';
import { generateTransforms, transformCount } from './SymmetryTransform';
import type { EllipseShape } from '../state/types';
import { LineStyle } from '../state/types';
import { GLOW_PASSES } from './glowPasses';

import ellipseVertSrc from './shaders/ellipse.vert.glsl';
import ellipseFragSrc from './shaders/ellipse.frag.glsl';

/**
 * Renders symmetry-instanced ellipse rings into the persistent stroke FBO.
 */
export class EllipseRenderer {
  private gl: WebGL2RenderingContext;
  private renderer: WebGLRenderer;

  private program: WebGLProgram;
  private uCanvasSize: WebGLUniformLocation;
  private uCenter: WebGLUniformLocation;
  private uRadii: WebGLUniformLocation;
  private uLineWidth: WebGLUniformLocation;
  private uAlpha: WebGLUniformLocation;
  private uColor: WebGLUniformLocation;

  private vao: WebGLVertexArrayObject;
  private quadCornerBuffer: WebGLBuffer;
  private transformBuffer: WebGLBuffer;

  constructor(gl: WebGL2RenderingContext, renderer: WebGLRenderer) {
    this.gl = gl;
    this.renderer = renderer;

    this.program = createProgram(gl, ellipseVertSrc, ellipseFragSrc);

    this.uCanvasSize = gl.getUniformLocation(this.program, 'uCanvasSize')!;
    this.uCenter = gl.getUniformLocation(this.program, 'uCenter')!;
    this.uRadii = gl.getUniformLocation(this.program, 'uRadii')!;
    this.uLineWidth = gl.getUniformLocation(this.program, 'uLineWidth')!;
    this.uAlpha = gl.getUniformLocation(this.program, 'uAlpha')!;
    this.uColor = gl.getUniformLocation(this.program, 'uColor')!;

    this.quadCornerBuffer = gl.createBuffer()!;
    this.transformBuffer = gl.createBuffer()!;

    const quadCorners = new Float32Array([
      -1, -1,
       1, -1,
      -1,  1,
      -1,  1,
       1, -1,
       1,  1,
    ]);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadCornerBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, quadCorners, gl.STATIC_DRAW);

    this.vao = this.buildVAO();
  }

  private buildVAO(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadCornerBuffer);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.transformBuffer);
    for (let col = 0; col < 3; col++) {
      const loc = 1 + col;
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 3, gl.FLOAT, false, 36, col * 12);
      gl.vertexAttribDivisor(loc, 1);
    }

    gl.bindVertexArray(null);
    return vao;
  }

  renderEllipse(ellipse: EllipseShape, glowIntensity: number): void {
    const gl = this.gl;
    const rx = Math.abs(ellipse.radii[0]);
    const ry = Math.abs(ellipse.radii[1]);
    if (rx < 0.5 && ry < 0.5) return;

    const passes = GLOW_PASSES[ellipse.lineStyle] || GLOW_PASSES[LineStyle.Neon];
    const transforms = generateTransforms(
      ellipse.mode,
      ellipse.symmetry,
      this.renderer.pixelWidth,
      this.renderer.pixelHeight,
    );
    const numTransforms = transformCount(ellipse.mode, ellipse.symmetry);

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.renderer.strokeFBO.framebuffer);
    gl.viewport(0, 0, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.enable(gl.BLEND);
    gl.blendEquation(gl.FUNC_ADD);
    gl.blendFuncSeparate(
      gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA,
      gl.ONE, gl.ONE_MINUS_SRC_ALPHA,
    );

    gl.bindBuffer(gl.ARRAY_BUFFER, this.transformBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, transforms, gl.DYNAMIC_DRAW);

    gl.useProgram(this.program);
    gl.uniform2f(this.uCanvasSize, this.renderer.pixelWidth, this.renderer.pixelHeight);
    gl.uniform2f(this.uCenter, ellipse.center[0], ellipse.center[1]);
    gl.uniform2f(this.uRadii, rx, ry);
    gl.uniform4f(this.uColor, ellipse.color[0], ellipse.color[1], ellipse.color[2], ellipse.color[3]);

    gl.bindVertexArray(this.vao);
    for (const pass of passes) {
      const effectiveAlpha = pass.scaleByGlow ? pass.alpha * glowIntensity : pass.alpha;
      const effectiveLineWidth = Math.max(0.5, ellipse.lineWidth * pass.widthMul);
      gl.uniform1f(this.uLineWidth, effectiveLineWidth);
      gl.uniform1f(this.uAlpha, effectiveAlpha);
      gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, numTransforms);
    }
    gl.bindVertexArray(null);

    gl.blendEquation(gl.FUNC_ADD);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }
}
