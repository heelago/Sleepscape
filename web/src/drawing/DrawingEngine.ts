import type { AppState } from '../state/AppState';
import type { StrokeRenderer } from '../rendering/StrokeRenderer';
import type { Stroke, StrokePoint } from '../state/types';
import { chaikinSmooth, uid } from '../utils/math';

/**
 * Manages strokes, undo/redo, and delegates rendering to StrokeRenderer.
 */
export class DrawingEngine {
  private state: AppState;
  private strokeRenderer: StrokeRenderer;

  // Stroke data
  strokes: Stroke[] = [];
  private undoneStrokes: Stroke[] = [];
  private activeStroke: Stroke | null = null;

  constructor(state: AppState, strokeRenderer: StrokeRenderer) {
    this.state = state;
    this.strokeRenderer = strokeRenderer;
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
  }

  addPoint(x: number, y: number, pressure: number, altitude: number): void {
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
    this.undoneStrokes = []; // clear redo stack
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

  clear(): void {
    this.strokes = [];
    this.undoneStrokes = [];
    this.activeStroke = null;
    this.state.canUndo = false;
    this.state.canRedo = false;
  }

  /**
   * Render only the most recent segment of the active stroke (incremental).
   * This avoids re-rendering the entire stroke on every point.
   */
  private renderIncrementalSegment(): void {
    if (!this.activeStroke || this.activeStroke.points.length < 2) return;

    // Create a mini-stroke with just the last 2 points for incremental rendering
    const points = this.activeStroke.points;
    const miniStroke: Stroke = {
      ...this.activeStroke,
      points: [points[points.length - 2], points[points.length - 1]],
    };

    this.strokeRenderer.renderStroke(miniStroke, this.state.glowIntensity);
  }
}
