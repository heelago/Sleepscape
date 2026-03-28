// ── Enums ──

export enum DrawMode {
  Free = 'free',
  Mandala = 'mandala',
  Ellipse = 'ellipse',
}

export enum LineStyle {
  Neon = 0,
  SoftGlow = 1,
  Dashed = 2,
  Dotted = 3,
  Sketch = 4,
}

export const LINE_STYLE_NAMES: Record<LineStyle, string> = {
  [LineStyle.Neon]: 'neon',
  [LineStyle.SoftGlow]: 'soft glow',
  [LineStyle.Dashed]: 'dashed',
  [LineStyle.Dotted]: 'dotted',
  [LineStyle.Sketch]: 'sketch',
};

// ── Stroke data ──

export interface StrokePoint {
  x: number;
  y: number;
  pressure: number;
  altitude: number;
  cumulDist: number;
}

export interface Stroke {
  id: string;
  points: StrokePoint[];
  color: [number, number, number, number]; // RGBA 0-1
  brushSize: number;
  mode: DrawMode;
  lineStyle: LineStyle;
  symmetry: number;
}

export interface EllipseShape {
  center: [number, number];
  radii: [number, number];
  color: RGBA;
  lineWidth: number;
  mode: DrawMode;
  symmetry: number;
  lineStyle: LineStyle;
}

// ── Color helpers ──

export type RGBA = [number, number, number, number];

export function hexToRgba(hex: string, alpha = 1): RGBA {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16) / 255;
  const g = parseInt(h.slice(2, 4), 16) / 255;
  const b = parseInt(h.slice(4, 6), 16) / 255;
  return [r, g, b, alpha];
}

export function hexToRgb01(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  return [
    parseInt(h.slice(0, 2), 16) / 255,
    parseInt(h.slice(2, 4), 16) / 255,
    parseInt(h.slice(4, 6), 16) / 255,
  ];
}
