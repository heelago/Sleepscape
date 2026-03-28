import type { AppState } from '../state/AppState';
import type { DrawingEngine } from './DrawingEngine';
import { emaSmooth } from '../utils/math';

/**
 * Handles Pointer Events with pressure, coalesced events, and EMA smoothing.
 */
export class InputHandler {
  private state: AppState;
  private engine: DrawingEngine;
  private canvas: HTMLCanvasElement;
  private dpr: () => number;

  private drawing = false;
  private smoothX = 0;
  private smoothY = 0;
  private lastAcceptedTime = 0;

  constructor(canvas: HTMLCanvasElement, state: AppState, engine: DrawingEngine, dpr: () => number) {
    this.canvas = canvas;
    this.state = state;
    this.engine = engine;
    this.dpr = dpr;

    canvas.addEventListener('pointerdown', this.onPointerDown);
    canvas.addEventListener('pointermove', this.onPointerMove);
    canvas.addEventListener('pointerup', this.onPointerUp);
    canvas.addEventListener('pointercancel', this.onPointerUp);
    canvas.addEventListener('pointerleave', this.onPointerUp);

    // Prevent default touch behaviors
    canvas.addEventListener('touchstart', e => e.preventDefault(), { passive: false });
    canvas.addEventListener('touchmove', e => e.preventDefault(), { passive: false });
  }

  private getSmoothingFactor(pointerType: string): number {
    if (this.state.slowInkEnabled) return 0.06;
    if (pointerType === 'pen') return 0.35;
    return 0.08; // finger / mouse
  }

  private processEvent(e: PointerEvent): void {
    const dpr = this.dpr();
    const rect = this.canvas.getBoundingClientRect();
    const rawX = (e.clientX - rect.left) * dpr;
    const rawY = (e.clientY - rect.top) * dpr;
    const pressure = e.pointerType === 'pen' ? e.pressure : 0.5;
    const altitude = Math.PI / 4; // default

    // Pace throttle
    const now = performance.now();
    if (this.state.paceThrottle > 0 && now - this.lastAcceptedTime < this.state.paceThrottle) {
      return;
    }
    this.lastAcceptedTime = now;

    // EMA smoothing
    const factor = this.getSmoothingFactor(e.pointerType);
    const smoothed = emaSmooth({ x: this.smoothX, y: this.smoothY }, { x: rawX, y: rawY }, factor);
    this.smoothX = smoothed.x;
    this.smoothY = smoothed.y;

    this.engine.addPoint(smoothed.x, smoothed.y, pressure, altitude);
  }

  private onPointerDown = (e: PointerEvent): void => {
    e.preventDefault();
    this.canvas.setPointerCapture(e.pointerId);
    this.drawing = true;

    const dpr = this.dpr();
    const rect = this.canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) * dpr;
    const y = (e.clientY - rect.top) * dpr;
    const pressure = e.pointerType === 'pen' ? e.pressure : 0.5;

    this.smoothX = x;
    this.smoothY = y;
    this.lastAcceptedTime = performance.now();

    this.engine.beginStroke(x, y, pressure, Math.PI / 4);
  };

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.drawing) return;
    e.preventDefault();

    // Use coalesced events if available
    const coalesced = e.getCoalescedEvents?.() ?? [e];
    for (const ce of coalesced) {
      this.processEvent(ce);
    }
  };

  private onPointerUp = (e: PointerEvent): void => {
    if (!this.drawing) return;
    this.drawing = false;
    e.preventDefault();
    this.engine.endStroke();
  };
}
