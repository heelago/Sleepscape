import { DrawMode } from '../state/types';

/**
 * Generate symmetry transform matrices.
 * Each transform is a 3x3 affine matrix stored as 9 floats (column-major).
 * For mandala mode: 2N transforms (N rotations x 2 for Y-axis mirror).
 * For free mode: 1 transform (identity).
 */
export function generateTransforms(
  mode: DrawMode,
  symmetry: number,
  canvasWidth: number,
  canvasHeight: number,
): Float32Array {
  const cx = canvasWidth / 2;
  const cy = canvasHeight / 2;
  const n = mode === DrawMode.Free ? 1 : symmetry;

  const transforms: number[][] = [];

  for (let i = 0; i < n; i++) {
    const angle = i * (2 * Math.PI / n);

    // Normal rotation
    transforms.push(makeTransform(angle, false, cx, cy));

    // Mirrored (Y-axis flip)
    if (mode !== DrawMode.Free) {
      transforms.push(makeTransform(angle, true, cx, cy));
    }
  }

  // Flatten to Float32Array (9 floats per matrix, column-major)
  const flat = new Float32Array(transforms.length * 9);
  for (let i = 0; i < transforms.length; i++) {
    for (let j = 0; j < 9; j++) {
      flat[i * 9 + j] = transforms[i][j];
    }
  }

  return flat;
}

/** Get the number of transforms for a given mode and symmetry. */
export function transformCount(mode: DrawMode, symmetry: number): number {
  if (mode === DrawMode.Free) return 1;
  return symmetry * 2;
}

/**
 * Build a 3x3 affine: translate(-cx,-cy) -> rotate(angle) -> optional Y-flip -> translate(cx,cy)
 * Returns 9 floats in column-major order.
 */
function makeTransform(angle: number, flip: boolean, cx: number, cy: number): number[] {
  const cosA = Math.cos(angle);
  const sinA = Math.sin(angle);

  // Rotation matrix (column-major)
  // col0: [cosA, sinA, 0]
  // col1: [-sinA, cosA, 0]
  // col2: [0, 0, 1]
  let r00 = cosA, r10 = sinA;
  let r01 = -sinA, r11 = cosA;

  // Optional Y-axis flip (mirror: x = -x)
  if (flip) {
    r00 = -r00;
    r10 = -r10;
  }

  // Combined: toCenter * rot * toOrigin
  // Translation component: rot * (-cx, -cy) + (cx, cy)
  const tx = r00 * (-cx) + r01 * (-cy) + cx;
  const ty = r10 * (-cx) + r11 * (-cy) + cy;

  // Column-major 3x3
  return [
    r00, r10, 0,  // column 0
    r01, r11, 0,  // column 1
    tx,  ty,  1,  // column 2
  ];
}
