import type { AppState } from '../state/AppState';
import type { StrokeRenderer } from '../rendering/StrokeRenderer';
import type { Stroke, StrokePoint } from '../state/types';
import type { Ripple, Sparkle, AmbientBloom } from '../rendering/ParticleRenderer';
import { DrawMode } from '../state/types';
import { generateTransforms, transformCount } from '../rendering/SymmetryTransform';
import { chaikinSmooth, uid } from '../utils/math';

/**
 * Manages strokes, undo/redo, and particle systems (ripples, sparkles, ambient blooms).
 */
export class DrawingEngine {
  private state: AppState;
  private strokeRenderer: StrokeRenderer;
  private getCanvasSize: () => { width: number; height: number };

  // Stroke data
  strokes: Stroke[] = [];
  private undoneStrokes: Stroke[] = [];
  private activeStroke: Stroke | null = null;

  // Particles
  ripples: Ripple[] = [];
  sparkles: Sparkle[] = [];
  ambientBlooms: AmbientBloom[] = [];

  private lastRippleTime = 0;
  private lastBloomSpawnTime = 0;

  constructor(
    state: AppState,
    strokeRenderer: StrokeRenderer,
    getCanvasSize: () => { width: number; height: number },
  ) {
    this.state = state;
    this.strokeRenderer = strokeRenderer;
    this.getCanvasSize = getCanvasSize;
  }

  beginStroke(x: number, y: number, pressure: number, altitude: number): void {
    const point: StrokePoint = { x, y, pressure, altitude, cumulDist: 0 };

    this.activeStroke = {
      id: uid(),
      points: [point],
      color: this.state.currentInkRGBA,
      brushSize: this.state.brushSize,
      mode: this.state.drawMode,
      lineStyle: this.state.lineStyle,
      symmetry: this.state.symmetry,
    };

    // Spawn initial ripple
    if (this.state.ripplesEnabled) {
      this.spawnRipples(x, y);
    }
  }

  addPoint(x: number, y: number, pressure: number, altitude: number, isPencil = false): void {
    if (!this.activeStroke) return;

    const points = this.activeStroke.points;
    const prev = points[points.length - 1];

    const dx = x - prev.x;
    const dy = y - prev.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    // Skip if too close
    if (dist < 1) return;

    const point: StrokePoint = {
      x, y, pressure, altitude,
      cumulDist: prev.cumulDist + dist,
    };

    points.push(point);

    // Render the new segment incrementally
    if (points.length >= 2) {
      this.renderIncrementalSegment();
    }

    // Spawn ripples along stroke
    if (this.state.ripplesEnabled) {
      this.spawnRipples(x, y);
    }

    // Spawn sparkles along pencil strokes
    if (isPencil && dist > 2 && this.state.sparklesEnabled) {
      this.spawnSparkles(x, y);
    }
  }

  endStroke(): void {
    if (!this.activeStroke) return;

    // Apply path smoothing if enabled
    if (this.state.pathSmoothingEnabled && this.activeStroke.points.length > 2) {
      this.activeStroke.points = chaikinSmooth(this.activeStroke.points);
      // Re-render the smoothed stroke
      this.strokeRenderer.reRenderAll([...this.strokes, this.activeStroke], this.state.glowIntensity);
    }

    this.strokes.push(this.activeStroke);
    this.undoneStrokes = [];
    this.activeStroke = null;

    this.state.canUndo = this.strokes.length > 0;
    this.state.canRedo = false;
  }

  undo(): void {
    if (this.strokes.length === 0) return;
    const stroke = this.strokes.pop()!;
    this.undoneStrokes.push(stroke);
    this.strokeRenderer.reRenderAll(this.strokes, this.state.glowIntensity);
    this.state.canUndo = this.strokes.length > 0;
    this.state.canRedo = this.undoneStrokes.length > 0;
  }

  redo(): void {
    if (this.undoneStrokes.length === 0) return;
    const stroke = this.undoneStrokes.pop()!;
    this.strokes.push(stroke);
    this.strokeRenderer.renderStroke(stroke, this.state.glowIntensity);
    this.state.canUndo = this.strokes.length > 0;
    this.state.canRedo = this.undoneStrokes.length > 0;
  }

  reRenderAll(): void {
    this.strokeRenderer.reRenderAll(this.strokes, this.state.glowIntensity);
  }

  clear(): void {
    this.strokes = [];
    this.undoneStrokes = [];
    this.activeStroke = null;
    this.ripples = [];
    this.sparkles = [];
    this.ambientBlooms = [];
    this.state.canUndo = false;
    this.state.canRedo = false;
  }

  // ── Particle updates (called each frame) ──

  updateParticles(canvasWidth: number, canvasHeight: number, time: number): void {
    this.updateRipples();
    this.updateSparkles();
    this.updateAmbientBlooms(canvasWidth, canvasHeight, time);
  }

  private updateRipples(): void {
    for (let i = this.ripples.length - 1; i >= 0; i--) {
      const r = this.ripples[i];
      r.radius += r.speed;
      const progress = r.radius / r.maxRadius;
      const decay = 1.0 - (0.002 + 0.025 * progress * progress);
      r.alpha *= decay;
      if (r.alpha < 0.01 || r.radius > r.maxRadius) {
        this.ripples.splice(i, 1);
      }
    }
  }

  private updateSparkles(): void {
    for (let i = this.sparkles.length - 1; i >= 0; i--) {
      const s = this.sparkles[i];
      s.life -= 1;
      s.alpha *= 0.95;
      s.size *= 0.98;
      if (s.life <= 0 || s.alpha < 0.01) {
        this.sparkles.splice(i, 1);
      }
    }
  }

  private updateAmbientBlooms(canvasWidth: number, canvasHeight: number, time: number): void {
    if (!this.state.bloomsEnabled) {
      this.ambientBlooms.length = 0;
      return;
    }

    // Spawn new blooms at random intervals
    const spawnInterval = 3.0 - this.state.bloomSpawnRate * 2.5;
    if (time - this.lastBloomSpawnTime >= spawnInterval && this.ambientBlooms.length < 8) {
      this.lastBloomSpawnTime = time;

      const [r, g, b] = [
        this.state.currentInkRGBA[0],
        this.state.currentInkRGBA[1],
        this.state.currentInkRGBA[2],
      ];

      this.ambientBlooms.push({
        centerX: 80 + Math.random() * (canvasWidth - 160),
        centerY: 80 + Math.random() * (canvasHeight - 160),
        radius: 3,
        maxRadius: 60 + Math.random() * 120,
        alpha: 0,
        targetAlpha: this.state.bloomIntensity * (0.20 + Math.random() * 0.20),
        colorR: r, colorG: g, colorB: b,
        phase: 'fadeIn',
        phaseTimer: 80 + Math.random() * 60,
      });
    }

    // Update existing blooms
    for (let i = this.ambientBlooms.length - 1; i >= 0; i--) {
      const b = this.ambientBlooms[i];
      b.phaseTimer -= 1;

      const progress = b.radius / b.maxRadius;
      const expandSpeed = 0.08 + (1.0 - progress) * 0.12;
      b.radius += expandSpeed;

      if (b.phase === 'fadeIn') {
        const fadeRate = b.targetAlpha / 60.0;
        b.alpha = Math.min(b.alpha + fadeRate, b.targetAlpha);
        if (b.phaseTimer <= 0) {
          b.phase = 'fadeOut';
          b.phaseTimer = 999;
        }
      } else {
        // fadeOut: gradual continuous fade
        const fadeFactor = 1.0 - (0.002 + 0.008 * progress * progress);
        b.alpha *= fadeFactor;
      }

      if (b.alpha < 0.002 || b.radius > b.maxRadius) {
        this.ambientBlooms.splice(i, 1);
      }
    }
  }

  // ── Particle spawning ──

  private spawnRipples(x: number, y: number): void {
    const now = performance.now() / 1000;
    if (now - this.lastRippleTime < 0.700) return;
    this.lastRippleTime = now;

    const [cr, cg, cb] = [
      this.state.currentInkRGBA[0],
      this.state.currentInkRGBA[1],
      this.state.currentInkRGBA[2],
    ];
    const speed = 0.30 + Math.random() * 0.12;
    const reach = (this.state as any).rippleReach ?? 0.5;
    const baseMax = 120 + reach * 280;
    const maxR = baseMax + Math.random() * 30;

    // Spawn at all symmetry-mirrored positions
    const mode = this.state.drawMode;
    const sym = this.state.symmetry;
    const { width: canvasW, height: canvasH } = this.getCanvasSize();
    const transforms = generateTransforms(mode, sym, canvasW, canvasH);
    const count = transformCount(mode, sym);

    for (let t = 0; t < count; t++) {
      const o = t * 9;
      // Apply 3x3 transform (column-major) to point
      const tx = transforms[o + 0] * x + transforms[o + 3] * y + transforms[o + 6];
      const ty = transforms[o + 1] * x + transforms[o + 4] * y + transforms[o + 7];

      this.ripples.push({
        centerX: tx, centerY: ty,
        radius: 30, maxRadius: maxR,
        alpha: 0.85, speed,
        colorR: cr, colorG: cg, colorB: cb,
        rings: 3,
      });
    }
  }

  private spawnSparkles(x: number, y: number): void {
    if (this.sparkles.length >= 200) return;

    const [cr, cg, cb] = [
      this.state.currentInkRGBA[0],
      this.state.currentInkRGBA[1],
      this.state.currentInkRGBA[2],
    ];

    const count = 1 + Math.floor(Math.random() * 3);
    for (let i = 0; i < count; i++) {
      this.sparkles.push({
        x: x + (Math.random() - 0.5) * 16,
        y: y + (Math.random() - 0.5) * 16,
        alpha: 0.4 + Math.random() * 0.5,
        size: 2 + Math.random() * 3,
        colorR: cr, colorG: cg, colorB: cb,
        life: 20 + Math.random() * 30,
      });
    }
  }

  // ── Incremental rendering ──

  private renderIncrementalSegment(): void {
    if (!this.activeStroke || this.activeStroke.points.length < 2) return;

    const points = this.activeStroke.points;
    const miniStroke: Stroke = {
      ...this.activeStroke,
      points: [points[points.length - 2], points[points.length - 1]],
    };

    this.strokeRenderer.renderStroke(miniStroke, this.state.glowIntensity);
  }
}
