# Sleepscape -- Architecture Reference

Meditative drawing and ambient sound app for iPad. SwiftUI + Metal + AudioKit. Targets iOS 18+.

## Build & run

```bash
# Build for connected iPad (Xcode must be installed)
xcodebuild -project Sleepscape.xcodeproj -scheme Sleepscape \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates build

# To find a specific connected device ID:
xcrun devicectl list devices

# Build + install + launch on a specific device:
xcodebuild -project Sleepscape.xcodeproj -scheme Sleepscape \
  -destination 'platform=iOS,id=DEVICE_UUID' -allowProvisioningUpdates build
xcrun devicectl device install app --device DEVICE_UUID \
  path/to/DerivedData/.../Build/Products/Debug-iphoneos/Sleepscape.app
xcrun devicectl device process launch --device DEVICE_UUID com.h2eapps.sleepscape
```

Swift packages (AudioKit, SoundpipeAudioKit) resolve automatically on first build.

## Key files

| Area | File | What it owns |
|------|------|-------------|
| State | `Models/AppState.swift` | All app state. `@Observable` class. Drawing, effects, audio, breathing, UI flags. Some properties persisted via UserDefaults (glowIntensity, brightnessCap, pathSmoothing, slowInk, paceThrottle). |
| Palettes | `Models/Palette.swift` | Six palettes (moonlit, dusk, slate, amber, sakura, forest), 8 inks each + dark background. `Color(hex:)` extension. |
| Metal shaders | `Drawing/Shaders.metal` | All GPU fragment/vertex shaders. Stroke rendering, bloom extraction, glow, ripples, ambient blooms, sparkles, ellipses, breath pulse, vignette, brightness cap. |
| Metal pipeline | `Drawing/MetalCanvasView.swift` | `MTKView` wrapper + `Coordinator` that owns 15 pipeline states, all textures, and the per-frame render loop. Touch handling via `TouchCaptureMTKView`. |
| Drawing engine | `Drawing/DrawingEngine.swift` | Stroke management, undo/redo stack, ripple/sparkle/bloom particle systems, path smoothing. |
| Symmetry | `Drawing/SymmetryTransform.swift` | Generates `simd_float3x3` transform arrays for mandala/ellipse/free modes. |
| Settings UI | `UI/SettingsSheet.swift` | Half-screen drawer with card grid (canvas, stroke, effects, breathing, audio). All pill/slider/toggle styling lives here. |
| Audio | `Audio/AudioEngine.swift` | AudioKit node graph: binaural oscillators, melody voice, piano tones, air layer. Generative, never loops. |
| Entry point | `App/ContentView.swift` | Composes MetalCanvasView, TopBar, GripStrip, overlays, settings sheet. |

## Metal rendering pipeline

Render order in `Coordinator.draw(in:)` -- all passes run every frame at 120fps:

1. **Stroke texture** (persistent, accumulates) -- new strokes rendered via 3-pass glow system, stored across frames
2. **Blit stroke texture** to drawable (no blend, overwrites background)
3. **Breath pulse** (additive) -- if enabled, 4-phase breathing ring
4. **Bloom extract** -- `brightPassFragment` extracts stroke pixels that deviate from background
5. **Gaussian blur** -- `MPSImageGaussianBlur` (sigma 12) on extracted bloom
6. **Bloom composite** (additive) -- blurred glow layered on
7. **Ambient blooms** (additive) -- firework-style particle dissipation
8. **Sparkles** (additive) -- bright point particles
9. **Ripples** (alpha blend) -- expanding ring particles
10. **Brightness cap** (framebuffer read via `[[color(0)]]`) -- clamps luminance, skipped when cap=1.0
11. **Vignette** (alpha blend) -- darkens edges

### 3-pass glow stroke system

Every stroke is rendered three times with different widths and alphas:

| Pass | Role | Example (neon) | Glow intensity affects? |
|------|------|---------------|------------------------|
| 0 | Halo (wide, faint) | width x3.2, alpha 0.03 | Yes -- alpha scaled by `glowIntensity` |
| 1 | Mid-glow | width x1.5, alpha 0.18 | Yes -- alpha scaled by `glowIntensity` |
| 2 | Core (sharp) | width x0.5, alpha 0.90 | No -- always full |

Each line style (neon, softGlow, dashed, dotted, sketch) has its own pass table in `renderStroke3Pass`. The stroke texture is persistent -- changing `glowIntensity` triggers a full re-render of all strokes.

### Adding a new visual effect

1. Write vertex/fragment shaders in `Shaders.metal`
2. Add a pipeline state in `Coordinator.setup(for:)` with the right blend mode (alpha or additive)
3. Write a `renderX(encoder:canvasSize:)` method in the Coordinator
4. Insert the call in the render order in `draw(in:)` at the right position
5. Add any controlling state to `AppState` and UI to `SettingsSheet`

### Adding a new palette

Add a `Palette(...)` entry to `Palette.all` in `Models/Palette.swift`. Must have exactly 8 ink colors and a dark background. The rest of the app picks it up automatically.

## UI conventions

- **Font:** CrimsonPro-Light for values, CrimsonPro-ExtraLight for labels. Sizes 10-14pt.
- **Pill buttons:** inactive text 0.60 opacity, border 0.35. Active text 0.95, fill `Color(red: 196/255, green: 184/255, blue: 232/255).opacity(0.16)`, border 0.50.
- **Section/card labels:** 0.55 opacity.
- **Slider tint:** `.white.opacity(0.3)`.
- **Range labels** (left/right of sliders): 0.55 opacity, CrimsonPro-ExtraLight 10pt.
- **Toggle tint:** `.white.opacity(0.3)`, scale 0.75.
- **Card background:** `.white.opacity(0.03)` fill, `.white.opacity(0.06)` stroke, 14pt corner radius.
- **Sheet background:** `Color(hex: "#0c0b14").opacity(0.95)`, 20pt corner radius.
- **Auto-close:** settings sheet dismisses after 10s idle.

Dark aesthetic throughout -- never use bright backgrounds or high-contrast UI elements.

## State persistence

Most state resets on app launch (drawing mode, effects toggles, etc). These persist via UserDefaults:

| Key | Type | Default | What it controls |
|-----|------|---------|-----------------|
| `glowIntensity` | Float | 0.65 | Halo/mid-glow alpha multiplier |
| `brightnessCap` | Float | 0.70 | Post-bloom luminance ceiling |
| `pathSmoothing` | Bool | false | Chaikin curve smoothing |
| `slowInk` | Bool | false | Viscous drawing feel |
| `paceThrottle` | Float | 0 | Point acceptance delay (0-120ms) |

## GPU struct alignment

Swift structs passed to Metal must match byte layout exactly. Existing structs use explicit padding fields (e.g. `_pad0`, `_pad1`) for SIMD alignment. When adding new uniforms, pad to 16-byte boundaries for `float4`/`SIMD4` fields. See `GPUStrokeUniforms` for reference.

## Important constraints

- **iPad only** -- no iPhone layout. Landscape and portrait both work.
- **120fps target** -- avoid per-frame allocations in the render loop. Use pre-allocated buffers where possible.
- **No network calls** -- the app is fully offline. No analytics, no telemetry, no data collection.
- **Stroke texture is persistent** -- strokes accumulate on a retained texture. Any change to how strokes look (glow intensity, background color) requires `reRenderAllStrokes()`.
- **`[[color(0)]]` programmable blending** -- the brightness cap shader reads the framebuffer in-place. This is supported on all iOS GPUs but the pipeline must not have blending enabled.

## Docs in the repo

- `SLEEPSCAPE_SPEC.md` -- full product/technical specification
- `SLEEPSCAPE_TECHNICAL_SPEC.md` -- detailed technical spec
- `HANDOFF.md` -- developer handoff document
- `SOUND_DESIGN_BRIEF.md` -- audio design collaboration brief
