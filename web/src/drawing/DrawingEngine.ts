import type { AppState } from '../state/AppState';
import type { StrokeRenderer } from '../rendering/StrokeRenderer';
import type { EllipseRenderer } from '../rendering/EllipseRenderer';
import type { Stroke, StrokePoint, EllipseShape } from '../state/types';
import type { Ripple, Sparkle, AmbientBloom } from '../rendering/ParticleRenderer';
import { DrawMode } from '../state/types';
import { generateTransforms, transformCount } from '../rendering/SymmetryTransform';
import { chaikinSmooth, uid } from '../utils/math';

type RenderEntry =
  | { type: 'stroke'; stroke: Stroke }
  | { type: 'ellipse'; ellipse: EllipseShape };

type ActionEntry =
  | { type: 'stroke'; stroke: Stroke }
  | { type: 'ellipseGesture'; ellipses: EllipseShape[] };

interface ActiveEllipseGesture {
  center: [number, number];
  color: [number, number, number, number];
  lineWidth: number;
  mode: DrawMode;
  symmetry: number;
  lineStyle: Stroke['lineStyle'];
  ellipses: EllipseShape[];
}

/**
 * Manages drawing (strokes + ellipses), undo/redo, and particle systems.
 */
export class DrawingEngine {
  private state: AppState;
  private strokeRenderer: StrokeRenderer;
  private ellipseRenderer: EllipseRenderer;
  private getCanvasSize: () => { width: number; height: number };

  // Drawing data
  strokes: Stroke[] = [];
  ellipses: EllipseShape[] = [];
  private renderEntries: RenderEntry[] = [];
  private actions: ActionEntry[] = [];
  private undoneActions: ActionEntry[] = [];
  private activeStroke: Stroke | null = null;
  private activeEllipse: ActiveEllipseGesture | null = null;

  // Particles
  ripples: Ripple[] = [];
  sparkles: Sparkle[] = [];
  ambientBlooms: AmbientBloom[] = [];

  private lastRippleTime = 0;
  private lastBloomSpawnTime = 0;

  constructor(
    state: AppState,
    strokeRenderer: StrokeRenderer,
    ellipseRenderer: EllipseRenderer,
    getCanvasSize: () => { width: number; height: number },
  ) {
    this.state = state;
    this.strokeRenderer = strokeRenderer;
    this.ellipseRenderer = ellipseRenderer;
    this.getCanvasSize = getCanvasSize;
  }

  beginStroke(x: number, y: number, pressure: number, altitude: number): void {
    if (this.state.drawMode === DrawMode.Ellipse) {
      this.activeStroke = null;
      this.activeEllipse = {
        center: [x, y],
        color: this.state.currentInkRGBA,
        lineWidth: this.state.brushSize,
        mode: this.state.drawMode,
        symmetry: this.state.symmetry,
        lineStyle: this.state.lineStyle,
        ellipses: [],
      };
    } else {
      const point: StrokePoint = { x, y, pressure, altitude, cumulDist: 0 };
      this.activeEllipse = null;
      this.activeStroke = {
        id: uid(),
        points: [point],
        color: this.state.currentInkRGBA,
        brushSize: this.state.brushSize,
        mode: this.state.drawMode,
        lineStyle: this.state.lineStyle,
        symmetry: this.state.symmetry,
      };
    }

    // Spawn initial ripple
    if (this.state.ripplesEnabled) {
      this.spawnRipples(x, y);
    }
  }

  addPoint(x: number, y: number, pressure: number, altitude: number, isPencil = false): void {
    if (this.activeEllipse) {
      this.addEllipsePoint(x, y);

      if (this.state.ripplesEnabled) {
        this.spawnRipples(x, y);
      }
      return;
    }

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
    if (this.activeEllipse) {
      this.endEllipseGesture();
      return;
    }
    if (!this.activeStroke) return;

    const stroke = this.activeStroke;
    this.activeStroke = null;

    // Apply path smoothing if enabled
    let didSmooth = false;
    if (this.state.pathSmoothingEnabled && stroke.points.length > 2) {
      stroke.points = chaikinSmooth(stroke.points);
      didSmooth = true;
    }

    this.strokes.push(stroke);
    this.renderEntries.push({ type: 'stroke', stroke });
    this.actions.push({ type: 'stroke', stroke });
    this.undoneActions = [];

    // Re-render only when smoothing changed points already drawn incrementally.
    if (didSmooth) {
      this.reRenderAll();
    }

    this.updateUndoRedoState();
  }

  undo(): void {
    if (this.actions.length === 0) return;

    const action = this.actions.pop()!;
    this.undoneActions.push(action);

    if (action.type === 'stroke') {
      this.strokes.pop();
      this.renderEntries.pop();
    } else {
      const removeCount = action.ellipses.length;
      if (removeCount > 0) {
        this.ellipses.splice(Math.max(0, this.ellipses.length - removeCount), removeCount);
        this.renderEntries.splice(Math.max(0, this.renderEntries.length - removeCount), removeCount);
      }
    }

    this.reRenderAll();
    this.updateUndoRedoState();
  }

  redo(): void {
    if (this.undoneActions.length === 0) return;

    const action = this.undoneActions.pop()!;
    this.actions.push(action);

    if (action.type === 'stroke') {
      this.strokes.push(action.stroke);
      this.renderEntries.push({ type: 'stroke', stroke: action.stroke });
      this.strokeRenderer.renderStroke(action.stroke, this.state.glowIntensity);
    } else {
      for (const ellipse of action.ellipses) {
        this.ellipses.push(ellipse);
        this.renderEntries.push({ type: 'ellipse', ellipse });
        this.ellipseRenderer.renderEllipse(ellipse, this.state.glowIntensity);
      }
    }

    this.updateUndoRedoState();
  }

  reRenderAll(): void {
    // Clear the persistent drawing surface.
    this.strokeRenderer.reRenderAll([], this.state.glowIntensity);
    for (const entry of this.renderEntries) {
      if (entry.type === 'stroke') {
        this.strokeRenderer.renderStroke(entry.stroke, this.state.glowIntensity);
      } else {
        this.ellipseRenderer.renderEllipse(entry.ellipse, this.state.glowIntensity);
      }
    }
  }

  clear(): void {
    this.strokes = [];
    this.ellipses = [];
    this.renderEntries = [];
    this.actions = [];
    this.undoneActions = [];
    this.activeStroke = null;
    this.activeEllipse = null;
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
    if (now - this.lastRippleTime < 2.0) return;
    this.lastRippleTime = now;

    const [cr, cg, cb] = [
      this.state.currentInkRGBA[0],
      this.state.currentInkRGBA[1],
      this.state.currentInkRGBA[2],
    ];
    const reach = (this.state as any).rippleReach ?? 0.5;
    const baseMax = 120 + reach * 280;

    // Spawn at all symmetry-mirrored positions.
    const mode = this.activeStroke?.mode ?? this.activeEllipse?.mode ?? this.state.drawMode;
    const sym = this.activeStroke?.symmetry ?? this.activeEllipse?.symmetry ?? this.state.symmetry;
    const { width: canvasW, height: canvasH } = this.getCanvasSize();
    const transforms = generateTransforms(mode, sym, canvasW, canvasH);
    const count = transformCount(mode, sym);

    for (let t = 0; t < count; t++) {
      const o = t * 9;
      // Apply 3x3 transform (column-major) to point.
      const tx = transforms[o + 0] * x + transforms[o + 3] * y + transforms[o + 6];
      const ty = transforms[o + 1] * x + transforms[o + 4] * y + transforms[o + 7];

      // Jitter position for organic feel
      const jx = (Math.random() - 0.5) * 20;
      const jy = (Math.random() - 0.5) * 20;
      const cx = tx + jx;
      const cy = ty + jy;

      // Spawn 2 concentric rings like a stone in water
      const baseSpeed = 0.18 + Math.random() * 0.10;
      const ringStarts = [3, 22];
      const ringAlphas = [0.40, 0.20];
      const ringSpeeds = [baseSpeed, baseSpeed * 0.85];
      const maxR = baseMax + (Math.random() - 0.5) * 50;

      for (let r = 0; r < 2; r++) {
        this.ripples.push({
          centerX: cx, centerY: cy,
          radius: ringStarts[r], maxRadius: maxR,
          alpha: ringAlphas[r], speed: ringSpeeds[r],
          colorR: cr, colorG: cg, colorB: cb,
          rings: 3,
        });
      }
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

  private addEllipsePoint(x: number, y: number): void {
    if (!this.activeEllipse) return;

    const [cx, cy] = this.activeEllipse.center;
    const rx = Math.abs(x - cx);
    const ry = Math.abs(y - cy);
    if (rx < 2 && ry < 2) return;

    const ellipse: EllipseShape = {
      center: this.activeEllipse.center,
      radii: [rx, ry],
      color: this.activeEllipse.color,
      lineWidth: this.activeEllipse.lineWidth,
      mode: this.activeEllipse.mode,
      symmetry: this.activeEllipse.symmetry,
      lineStyle: this.activeEllipse.lineStyle,
    };

    // Replace the preview ellipse (only keep the latest one during drag)
    this.activeEllipse.ellipses = [ellipse];

    // Re-render everything + the preview ellipse
    this.reRenderAll();
    this.ellipseRenderer.renderEllipse(ellipse, this.state.glowIntensity);
  }

  private endEllipseGesture(): void {
    if (!this.activeEllipse) return;

    const ellipses = this.activeEllipse.ellipses;
    this.activeEllipse = null;

    if (ellipses.length > 0) {
      this.ellipses.push(...ellipses);
      for (const ellipse of ellipses) {
        this.renderEntries.push({ type: 'ellipse', ellipse });
      }
      this.actions.push({ type: 'ellipseGesture', ellipses });
      this.undoneActions = [];
    }

    this.updateUndoRedoState();
  }

  private updateUndoRedoState(): void {
    this.state.canUndo = this.actions.length > 0;
    this.state.canRedo = this.undoneActions.length > 0;
  }
}
