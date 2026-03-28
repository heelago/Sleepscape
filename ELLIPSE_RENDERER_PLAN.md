# Ellipse Renderer Port — Web Implementation Plan

> **STATUS: ATTEMPTED & REVERTED (2026-03-28)**
>
> An initial implementation was merged (commit `1572f55`) but the behavior
> did not match the native iPad app — ellipses accumulated on every drag
> point, filling the screen. The UI pill was removed (commit `250efaa`)
> but the renderer code remains in the codebase:
>
> - `web/src/rendering/EllipseRenderer.ts` — renderer class (DO NOT expose in UI yet)
> - `web/src/rendering/shaders/ellipse.vert.glsl` / `ellipse.frag.glsl` — shaders
> - `web/src/rendering/glowPasses.ts` — extracted glow pass config (shared with StrokeRenderer)
> - `web/src/drawing/DrawingEngine.ts` — has ellipse gesture handling code
> - `web/src/state/types.ts` — has `EllipseShape` interface
>
> **The ellipse pill is intentionally hidden** in `SettingsSheet.ts` (only `Free` and `Mandala`
> are listed). Do not re-add it without fixing the core interaction model first.
>
> **Key issue to solve:** The native app's ellipse mode places a single ring per
> drag gesture (center on touch-down, radii from drag). The web implementation
> needs to preview the ellipse during drag WITHOUT baking intermediates to the
> persistent stroke texture. This likely requires a separate preview FBO or
> rendering the active ellipse in the composite pass rather than the stroke pass.

## Context

The native iPad app has a dedicated ellipse drawing mode with its own Metal shader pipeline (`ellipseVertex`/`ellipseFragment` in `Shaders.metal`). In ellipse mode, the user drags to place concentric elliptical rings that are mirrored across all symmetry axes. This is fundamentally different from stroke-based drawing — it renders ring shapes with configurable radii and line width, not freehand paths.

## Reference: Native Metal Implementation

Key files to study:
- `Sleepscape/Drawing/Shaders.metal` lines 574-640: `EllipseUniforms`, `EllipseVertex`, `ellipseVertex`, `ellipseFragment`
- `Sleepscape/Drawing/MetalCanvasView.swift` line 55: `GPUEllipseUniforms` struct
- `Sleepscape/Drawing/MetalCanvasView.swift` lines 389-396: ellipse pipeline setup
- `Sleepscape/Drawing/SymmetryTransform.swift`: ellipse-specific transforms (if any)

### How the native ellipse shader works:
1. Vertex shader creates a quad around the ellipse center, sized to `max(radii.x, radii.y) + lineWidth * 2`
2. Quad corners are transformed through symmetry transforms (instanced)
3. Fragment shader computes distance from center in UV space
4. Renders a ring at the ellipse boundary using `smoothstep`: `ring = smoothstep(0.85, 0.90, dist) * (1.0 - smoothstep(0.95, 1.0, dist))`
5. Adds very faint fill inside: `fill = (1.0 - smoothstep(0.0, 0.95, dist)) * 0.05`
6. Final alpha = `(ring + fill) * color.a`

### Ellipse uniforms:
- `canvasSize` (float2)
- `color` (float4)
- `center` (float2) — touch position
- `radii` (float2) — computed from drag distance
- `lineWidth` (float)
- `alpha` (float)

## Implementation Steps

### 1. Create ellipse shaders (`web/src/rendering/shaders/`)

**`ellipse.vert.glsl`**
- Input: quad corner (aQuadCorner), instanced symmetry transforms
- Uniforms: uCanvasSize, uCenter, uRadii, uLineWidth
- Build quad around center at `max(radii) + lineWidth * 2`
- Transform through symmetry matrix
- Output: localUV (for distance calc in frag), color

**`ellipse.frag.glsl`**
- Port the native fragment shader logic directly
- Compute `dist = length(localUV)`
- Ring: `smoothstep(0.85, 0.90, dist) * (1.0 - smoothstep(0.95, 1.0, dist))`
- Fill: `(1.0 - smoothstep(0.0, 0.95, dist)) * 0.05`
- Output: `vec4(color.rgb, (ring + fill) * color.a)`

### 2. Create `EllipseRenderer` class (`web/src/rendering/EllipseRenderer.ts`)

- Compile ellipse vertex/fragment programs
- Cache uniform locations
- Create quad VAO (4 vertices) + transform instance buffer
- `renderEllipse(center, radii, color, alpha, lineWidth, transforms, transformCount)` method
- Renders to stroke FBO with alpha blending

### 3. Integrate into `WebGLRenderer`

- Import and instantiate `EllipseRenderer` in constructor
- Expose it for `DrawingEngine` to call

### 4. Update `DrawingEngine` for ellipse mode

- In ellipse mode, touch-down records the center point
- Touch-drag computes radii from distance: `radiusX = abs(currentX - centerX)`, `radiusY = abs(currentY - centerY)`
- On each move, render the ellipse to stroke FBO (incrementally, like strokes)
- On touch-up, finalize the ellipse as a completed shape
- Store completed ellipses in a separate array (not stroke points)
- Support undo/redo for ellipses

### 5. Update `StrokeRenderer.reRenderAll`

- Must also re-render ellipses when glow intensity changes or undo/redo occurs
- Or create a parallel `reRenderAllEllipses` path

### 6. Define ellipse data type

Add to `web/src/state/types.ts`:
```typescript
interface EllipseShape {
  center: [number, number];
  radii: [number, number];
  color: RGBA;
  lineWidth: number;
  mode: DrawMode;
  symmetry: number;
}
```

### 7. Apply 3-pass glow to ellipses

Like strokes, ellipses should render with the 3-pass glow system:
- Pass 0: wide halo (widthMul 3.2, low alpha)
- Pass 1: mid-glow (widthMul 1.5, medium alpha)
- Pass 2: core (widthMul 0.5, full alpha)

Scale the `lineWidth` uniform by each pass's `widthMul`.

## Testing Checklist

- [ ] Ellipse renders centered on touch-down point
- [ ] Drag away from center grows radii proportionally
- [ ] Symmetry transforms mirror ellipses correctly (4/6/8/12/16 fold)
- [ ] 3-pass glow system produces neon ring effect
- [ ] Undo/redo works for individual ellipses
- [ ] Clear canvas removes all ellipses
- [ ] Ellipses persist on stroke texture (survive across frames)
- [ ] Re-render on glow intensity change includes ellipses
- [ ] Performance: no frame drops with many ellipses

## Estimated Scope

~6 files to create/modify. The shader port is mechanical (Metal -> GLSL is mostly syntax). The main complexity is the drawing engine integration — managing ellipse state alongside stroke state, and ensuring undo/redo works correctly across both types.

---

## Next Session Prompt

Start a new session with this prompt:

> I'm implementing the ellipse renderer for the Sleepscape web app. Read `ELLIPSE_RENDERER_PLAN.md` in the repo root for the full plan. Before starting, pull latest from main and verify the web app builds cleanly with `cd web && npx tsc --noEmit`. Then follow the plan step by step, starting with the shaders. Reference the native Metal implementation in `Sleepscape/Drawing/Shaders.metal` lines 574-640 for the exact ellipse rendering logic to port.
