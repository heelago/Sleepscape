import type { StrokePoint } from '../state/types';

/** Exponential moving average smoothing for touch input. */
export function emaSmooth(
  prev: { x: number; y: number },
  curr: { x: number; y: number },
  factor: number,
): { x: number; y: number } {
  return {
    x: prev.x + (curr.x - prev.x) * factor,
    y: prev.y + (curr.y - prev.y) * factor,
  };
}

/** Chaikin corner-cutting smoothing (5 iterations, max 500 points). */
export function chaikinSmooth(points: StrokePoint[], iterations = 5): StrokePoint[] {
  let current = points;
  for (let iter = 0; iter < iterations; iter++) {
    if (current.length < 2) return current;
    const next: StrokePoint[] = [current[0]]; // keep first point

    for (let i = 0; i < current.length - 1; i++) {
      const a = current[i];
      const b = current[i + 1];

      // Q = 75% A + 25% B
      next.push({
        x: a.x * 0.75 + b.x * 0.25,
        y: a.y * 0.75 + b.y * 0.25,
        pressure: a.pressure * 0.75 + b.pressure * 0.25,
        altitude: a.altitude * 0.75 + b.altitude * 0.25,
        cumulDist: 0,
      });

      // R = 25% A + 75% B
      next.push({
        x: a.x * 0.25 + b.x * 0.75,
        y: a.y * 0.25 + b.y * 0.75,
        pressure: a.pressure * 0.25 + b.pressure * 0.75,
        altitude: a.altitude * 0.25 + b.altitude * 0.75,
        cumulDist: 0,
      });
    }

    next.push(current[current.length - 1]); // keep last point
    current = next;
  }

  // Downsample if exceeding 500 points
  if (current.length > 500) {
    const stride = current.length / 500;
    const downsampled: StrokePoint[] = [];
    for (let i = 0; i < 500; i++) {
      downsampled.push(current[Math.floor(i * stride)]);
    }
    current = downsampled;
  }

  // Recalculate cumulative distance
  current[0].cumulDist = 0;
  for (let i = 1; i < current.length; i++) {
    const dx = current[i].x - current[i - 1].x;
    const dy = current[i].y - current[i - 1].y;
    current[i].cumulDist = current[i - 1].cumulDist + Math.sqrt(dx * dx + dy * dy);
  }

  return current;
}

/** Generate a unique ID. */
export function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}
