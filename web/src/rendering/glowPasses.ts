import { LineStyle } from '../state/types';

/**
 * 3-pass glow configuration per line style.
 * Each pass defines width and alpha scaling behavior.
 */
export interface GlowPass {
  widthMul: number;
  alpha: number;
  scaleByGlow: boolean;
}

export const GLOW_PASSES: Record<number, GlowPass[]> = {
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
