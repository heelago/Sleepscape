# Sleepscape -- Technical Specification

### Current state as implemented -- March 2026

---

## Overview

Sleepscape is a meditative mandala drawing and ambient sound app for iPad. Users draw symmetrical patterns while generative binaural audio and breathing guidance create a calming pre-sleep experience. The app uses Metal for 120fps GPU-accelerated rendering and AudioKit for real-time audio synthesis with no bundled audio files.

---

## Project Configuration

- **Bundle ID:** com.h2eapps.sleepscape
- **Minimum deployment:** iOS 18.0
- **Devices:** iPad only
- **Orientation:** Landscape only (left + right)
- **Color scheme:** Dark only (`preferredColorScheme(.dark)`)
- **Background modes:** Audio, AirPlay, and Picture in Picture
- **Info.plist:** NSMicrophoneUsageDescription (placeholder required by AudioKit)

---

## Dependencies

| Package | Repository | Version |
|---------|-----------|---------|
| AudioKit | https://github.com/AudioKit/AudioKit | 5.6.4 |
| SoundpipeAudioKit | https://github.com/AudioKit/SoundpipeAudioKit | 5.6.4 |
| AudioKitEX | (transitive via SoundpipeAudioKit) | -- |

Note: The Inferno shader package was in the original spec but was removed due to Metal Toolchain download failures. All visual effects use custom shaders.

---

## Architecture

### Pattern: MVVM with @Observable

Swift 5.9 `@Observable` macro throughout. No `ObservableObject`, no `@Published`.

```
Views (SwiftUI)
  +-- ViewModels (@Observable classes)
        +-- Services (DrawingEngine, SleepscapeAudioEngine)
```

### File Structure

```
Sleepscape/
  App/
    SleepscapeApp.swift          -- @main, AVAudioSession setup
    ContentView.swift            -- root view, composes canvas + UI overlay

  Drawing/
    MetalCanvasView.swift        -- MTKView wrapper (UIViewRepresentable) + Coordinator (owns Metal pipeline)
    MetalCanvasViewModel.swift   -- @Observable bridge to DrawingEngine
    DrawingEngine.swift          -- touch -> stroke -> manages strokes, ripples, blooms, sparkles, undo/redo
    Shaders.metal                -- all vertex + fragment shaders
    SymmetryTransform.swift      -- pure math: rotation + mirror affine matrices
    Stroke.swift                 -- Codable struct: points, pressure, color, mode, lineStyle

  Audio/
    AudioEngine.swift            -- AudioKit node graph, preset-driven, binaural + bells + wanderer + noise
    AudioViewModel.swift         -- @Observable, exposes play/pause, volume, isPlaying

  Session/
    SessionManager.swift         -- @Observable, tracks session phases
    BreathGuide.swift            -- SwiftUI Canvas + TimelineView, 9-second breathing animation

  UI/
    TopBar.swift                 -- two-row transparent overlay: palette chips, ink dots, brush picker, undo/redo
    GripStrip.swift              -- bottom bar: play/pause, volume, clear, sleep timer, settings
    SettingsSheet.swift          -- slide-up sheet with 5 cards: canvas, stroke, effects, breathing, audio
    SleepOverlay.swift           -- full-screen black fade
    BottomSheet.swift            -- LEGACY (replaced by GripStrip + SettingsSheet, not referenced)
    AutoColorRow.swift           -- LEGACY row file (not referenced by current UI)
    BloomsRow.swift              -- LEGACY row file
    BrushRow.swift               -- LEGACY row file
    InkRow.swift                 -- LEGACY row file
    LineStyleRow.swift           -- LEGACY row file
    ModeRow.swift                -- LEGACY row file
    PaletteRow.swift             -- LEGACY row file
    SymmetryRow.swift            -- LEGACY row file

  Models/
    AppState.swift               -- @Observable, single source of truth for all UI + drawing state
    AudioPreset.swift            -- 3 frequency presets (delta, theta, 528Hz)
    DrawMode.swift               -- enum: free, mandala, ellipse
    LineStyle.swift              -- enum: neon, softGlow, dashed, dotted, sketch
    Palette.swift                -- 6 palette definitions with hex colors

  Resources/
    Fonts/
      CormorantGaramond-LightItalic.ttf
      CrimsonPro-Light.ttf
      CrimsonPro-ExtraLight.ttf

  Info.plist
  PrivacyInfo.xcprivacy
```

---

## Drawing Engine

### Metal Pipeline

`MTKView` with `preferredFramesPerSecond = 120`, `isPaused = false`, `enableSetNeedsDisplay = false`. Pixel format: `.bgra8Unorm`. The Coordinator acts as `MTKViewDelegate` and owns the entire GPU pipeline.

**Textures (4):**
- `strokeTexture` -- persistent, accumulates strokes. Only cleared on user "clear" or re-rendered on undo / background change.
- `bloomSourceTexture` -- receives the composited scene for bloom extraction.
- `bloomBlurTexture` -- receives the Gaussian-blurred bloom.
- `rippleTexture` -- cleared every frame, ripple/bloom/sparkle particles rendered fresh.

**Each frame composites:** background color fill -> strokeTexture (new strokes rendered) -> rippleTexture (particles) -> bloom pass -> center glow -> breath pulse -> vignette -> display.

**Pipeline states (14):**

| Pipeline | Vertex Shader | Fragment Shader | Blend Mode |
|----------|--------------|----------------|------------|
| Dot | symmetryDotVertex | dotFragmentShader | Alpha |
| Segment | symmetrySegmentVertex | segmentFragmentShader | Alpha |
| Composite | quadVertexShader | textureFragmentShader | None |
| Alpha composite | quadVertexShader | textureFragmentShader | Alpha |
| Bloom extract | quadVertexShader | brightPassFragment | None |
| Additive composite | quadVertexShader | textureFragmentShader | Additive |
| Ripple | rippleVertex | rippleFragment | Alpha |
| Ellipse | ellipseVertex | ellipseFragment | Alpha |
| Ambient bloom | ambientBloomVertex | ambientBloomFragment | Additive |
| Sparkle | sparkleVertex | sparkleFragment | Additive |
| Center glow | quadVertexShader | centerGlowFragment | Additive |
| Mandala border | quadVertexShader | mandalaBorderFragment | Additive |
| Breath pulse | quadVertexShader | breathPulseFragment | Additive |
| Vignette | quadVertexShader | radialVignetteFragment | Alpha |

**Bloom pass:**
1. Extract bright pixels using `brightPassFragment` -- subtracts canvas background color, applies `smoothstep(0.03, 0.20, deviation)` threshold
2. Gaussian blur via `MPSImageGaussianBlur` (sigma 12.0)
3. Additive blend back onto composited image

### Shaders (Shaders.metal)

All shaders are in a single Metal file. Key shaders:

- **quadVertexShader / textureFragmentShader:** full-screen quad for texture compositing
- **brightPassFragment:** background-aware bloom extraction (subtracts bg color to avoid light-bg washout)
- **centerGlowFragment:** radial center glow + subtle vignette
- **symmetrySegmentVertex / segmentFragmentShader:** line segment rendering with instanced symmetry transforms, per-style fragment behavior (neon/soft/dashed/dotted/sketch)
- **symmetryDotVertex / dotFragmentShader:** point rendering for stroke joints with per-style shaping
- **rippleVertex / rippleFragment:** instanced quad ripple rings with glow + ring accent
- **ambientBloomVertex / ambientBloomFragment:** instanced quad soft gaussian glow particles
- **sparkleVertex / sparkleFragment:** instanced quad sharp-center sparkle particles
- **ellipseVertex / ellipseFragment:** instanced quad ellipse with ring + soft fill
- **mandalaBorderFragment:** whisper-thin gaussian ring guide
- **breathPulseFragment:** 4-phase dotted ring with sine-eased expand/contract and hold flash
- **radialVignetteFragment:** edge darkening (12% max)

### GPU Structs

Matched between Swift and Metal:

- `GPUStrokePoint` (24 bytes): position, pressure, altitude, cumulDist, padding
- `GPUStrokeUniforms` (48 bytes): canvasSize, color, brushSize, alpha, glowRadius, lineStyle
- `GPURippleData`: center, radius, alpha, color, rings
- `GPUAmbientBloomData`: center, radius, alpha, color
- `GPUSparkleData`: position, alpha, size, color
- `GPUEllipseUniforms`: canvasSize, color, center, radii, rotation, lineWidth, alpha

### Touch Handling

Touch events are captured in `TouchCaptureMTKView` (custom MTKView subclass):

- `touchesBegan`: begins stroke with color, brush size, mode, line style
- `touchesMoved`: processes coalesced touches at 240Hz (Apple Pencil), applies EMA smoothing, tracks cumulative distance, spawns sparkles along pencil strokes, spawns ripples at all symmetry-mirrored positions
- `touchesEnded`: finalizes stroke (optional Chaikin smoothing), updates undo/redo state
- Predicted touches used for near-zero perceived latency
- Pace throttle: configurable 0-120ms minimum interval between accepted touch points

All touch coordinates are in pixel space (multiplied by `contentScaleFactor`).

**Pressure mapping:**
```
lineWidth = baseBrushSize * pow(pressure, 0.6)
alpha = 0.3 + (0.7 * pow(pressure, 0.5))
```

**Smoothing factors:**
- Finger: 0.08 (heavy smoothing)
- Apple Pencil: 0.35 (light easing)
- Slow ink mode: 0.06 (very heavy)

### Stroke Rendering (3-pass neon glow)

For line style "neon" (default), each stroke is rendered 3 times:
1. Halo: brushSize * 3.2, alpha 0.03
2. Mid glow: brushSize * 1.5, alpha 0.18
3. Core: brushSize * 0.5, alpha 0.90

Each pass renders both segments (quads between consecutive points) and dots (at each point). The segment vertex shader expands line segments into screen-aligned quads using the normal vector, with pressure-interpolated width.

### Line Styles

5 styles, selected by `lineStyle` uniform passed to GPU:
- **Neon (0):** default 3-pass glow, smooth edge falloff via `smoothstep(0.6, 1.0, dist)`
- **Soft glow (1):** wider diffuse glow, `exp(-2.0 * dist * dist)` falloff
- **Dashed (2):** 20px on / 14px off pattern using `fmod(cumulDist, 34.0)`, hard edge via `smoothstep(0.5, 1.0, dist)`
- **Dotted (3):** segments discarded entirely, dots rendered at 12px spacing (3px visible per cycle)
- **Sketch (4):** noise-displaced normals, rough edge noise, occasional gaps (8% chance)

### Symmetry Transforms

`SymmetryTransform.swift` generates an array of 3x3 affine matrices:
- Free mode: 1 transform (identity)
- Mandala mode: N rotations * 2 (with Y-axis mirror) = 2N transforms
- Transforms passed to vertex shader as buffer, applied via `instanceID`

Fold options: 4, 6, 8 (default), 12, 16.

### Path Smoothing (Chaikin)

Optional post-stroke smoothing using Chaikin's corner-cutting algorithm:
- 5 iterations of subdivision
- Keeps first and last points
- Recalculates cumulative distance after smoothing
- Output capped at 500 points (uniform stride downsample if exceeded)

### Undo / Redo

- Undo pops last stroke from `strokes` array, pushes to `undoneStrokes`
- Redo restores from `undoneStrokes`
- New stroke clears redo stack
- Undo/redo triggers full re-render of `strokeTexture` from remaining strokes

### Ripple Particles

- Spawn at all symmetry-mirrored positions of touch point
- Throttled: 1 spawn per 400ms
- Each ripple: expanding radius, quadratic decay, 3 concentric rings
- Rendered as instanced quads (avoids 511px iOS point-size limit)
- Fragment: soft filled glow center + ring accent at edge

### Ambient Blooms

- Soft firefly-like glow particles scattered across canvas
- Lifecycle: fadeIn -> hold -> fadeOut (with slow radial expansion)
- Max 8 simultaneous blooms
- Spawn rate and intensity configurable via settings
- Rendered as instanced quads with gaussian glow fragment

### Sparkle Particles

- Spawn along Apple Pencil strokes (1-3 per point, random offset +/-8px)
- Max 200 simultaneous sparkles
- Fade alpha (0.95x per frame) and shrink (0.98x per frame) over 20-50 frame lifetime
- Rendered as instanced quads with sharp-center exponential glow

---

## Audio Engine

### Architecture

`SleepscapeAudioEngine` is an `@Observable` class that owns the AudioKit `AudioEngine` and all audio nodes. Preset-driven: switching presets tears down and rebuilds the node graph with a crossfade.

### Signal Chain

```
[N x BreathingNote pairs (binaural, panned L/R)]
[Wanderer oscillator]
[WhiteNoise -> BandPassButterworthFilter]
        |
    [Mixer (preMixer)]
        |
    [LowPassFilter (preset cutoff)]
        |
    [Fader (dry, 0.06)] ---------> [Mixer (master)]
    [Fader (wet, 0.94)] -> [CostelloReverb] -> [Mixer (master)]
                                                      |
[Mixer (bells, bypass reverb)] ---------> [Mixer (master)]
        |
    [Fader (masterFader)]
        |
    [engine.output]
```

### Audio Presets

**Delta (default):**
- Note frequencies: 55, 110, 164.81, 220, 246.94, 329.63, 440 Hz (A pentatonic)
- Binaural detune: +/- 4.0 cents (~2Hz beat at 220Hz)
- Lowpass cutoff: 1400 Hz
- Reverb feedback: 0.95
- Volume scale: 1.0

**Theta:**
- Same note frequencies as delta
- Binaural detune: +/- 16.0 cents (~4-8Hz beat)
- Lowpass cutoff: 1800 Hz
- Reverb feedback: 0.93
- Volume scale: 0.9

**528 Hz (Solfeggio):**
- Note frequencies: 132, 264, 396, 528, 594, 792 Hz
- Binaural detune: +/- 2.0 cents (very gentle)
- Lowpass cutoff: 2200 Hz
- Reverb feedback: 0.92
- Volume scale: 0.8

### Binaural Breathing Notes

Each note frequency creates two oscillators (sine):
- Left: `frequency * pow(2, -detuneCents/1200)`, panned hard left
- Right: `frequency * pow(2, +detuneCents/1200)`, panned hard right

Each note breathes independently with randomized timing:
- Fade in: 5-11 seconds to volume 0.02-0.06 (1.2x boost for frequencies under 120Hz)
- Hold: 8-22 seconds
- Fade out: 6-14 seconds
- Rest: 8-22 seconds
- Initial start staggered by 0-12 seconds

### Piano Bell Tones

Bell frequencies (constant across all presets): 110, 164.81, 220, 246.94, 329.63, 440, 493.88 Hz.

Scheduled every 4-11 seconds. Each bell creates 3 sine oscillators:
- Fundamental: volume 0.07
- Octave (2x): volume 0.035
- 2 octaves (4x): volume 0.012

Attack: 60ms ramp to volume. Decay: 8-second ramp to silence. Oscillators stopped and removed after 8.5 seconds. Bells feed directly into the master mixer, bypassing reverb.

### Wandering Melody

Single sine oscillator gliding between preset note frequencies:
- Glide duration: 4-9 seconds
- Volume: 0.02-0.06
- Active duration: 12-32 seconds per phrase
- Rest between phrases: 4-14 seconds

### Noise Layer

WhiteNoise -> BandPassButterworthFilter (center 800Hz, bandwidth 400Hz) -> Fader (gain 0.004). Barely audible presence layer.

### Background Audio

```swift
AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
```

### Sleep Timer

Three options: 15, 30, 60 minutes. Timer ticks every 10 seconds and linearly reduces volume from user-set level to zero over the selected duration. When complete, audio stops and playback state resets.

Note: linear fade; exponential would feel more natural (planned improvement).

---

## Breathing Guide

### Breath Pulse (Metal shader)

GPU-rendered dotted ring centered on canvas. Controlled by `BreathPulseUniforms`:

**Ring behavior:**
- Contracted position: 8px radius (tiny dot at center)
- Expanded position: `maxRadius` (configurable)
- 60 dots around circumference
- Razor-thin gaussian ring: sigma 1.2px
- When contracted below 20px, switches from dotted to solid (too small for dots)

**4-phase animation with sine easing:**
- Inhale: ring expands 0->1 with `0.5 - 0.5 * cos(p * pi)`, glow brightens
- Hold: ring stays expanded, soft 1Hz flash (`0.7 + 0.3 * sin(t * 2pi)`)
- Exhale: ring contracts 1->0 with `0.5 + 0.5 * cos(p * pi)`, glow dims
- Hold2: ring stays contracted, dimmer pulse (`0.2 + 0.15 * sin(t * 2pi)`)

### Breathing Presets

| Preset | Inhale | Hold | Exhale | Hold2 | Total Cycle | Description |
|--------|--------|------|--------|-------|-------------|-------------|
| 4-7-8 | 4s | 7s | 8s | 0s | 19s | For sleep onset |
| Box | 4s | 4s | 4s | 4s | 16s | Grounding |
| Cardiac | 4s | 0s | 6s | 0s | 10s | For anxiety |
| Resonance | 6s | 0s | 6s | 0s | 12s | Natural rhythm |
| Gentle | 2s | 1s | 4s | 1s | 8s | Beginner |
| Custom | 4s* | 2s* | 6s* | 0s* | varies | User-adjustable (1-12s each) |

*Custom defaults shown; user can adjust all four phases.

### BreathGuide (SwiftUI)

Separate SwiftUI `Canvas` + `TimelineView` animation that appears after 5 seconds of touch inactivity. 9-second cycle with rotating arc and "breathe" text. Disappears on touch. This is independent of the Metal breath pulse ring.

---

## Palettes

6 palettes, each with 8 ink colors:

**Moonlit** (background #04030a):
#c4b8e8, #5fcfcf, #a8c8f0, #d9768a, #6ecba8, #d4a96a, #e8d5b0, #ffffff

**Aurora** (background #040210):
#7fffd4, #40e0d0, #9370db, #da70d6, #87ceeb, #b0e0e6, #dda0dd, #ffffff

**Ocean** (background #010810):
#caf0f8, #90e0ef, #48cae4, #ade8f4, #0096c7, #e0fbfc, #98c1d9, #ffffff

**Ember** (background #0a0300):
#ffcba4, #ff9f6b, #ffb347, #ffd93d, #ff6b9d, #f72585, #ff4757, #ffffff

**Sakura** (background #08040a):
#ffb7c5, #ff8fab, #ffc8dd, #ffafcc, #bde0fe, #a2d2ff, #e2b4bd, #ffffff

**Forest** (background #010803):
#74c69d, #52b788, #95d5b2, #a9def9, #d8f3dc, #e4c1f9, #b7e4c7, #ffffff

Note: palette backgrounds are associated with the palette but the canvas background is independently selectable.

---

## Canvas Backgrounds

6 backgrounds, independently selectable from palettes:

| Name | Hex | Dark? |
|------|-----|-------|
| Midnight | #04030a | Yes |
| Deep Navy | #0a0e1a | Yes |
| Charcoal | #1a1a1e | Yes |
| Warm Black | #0f0c08 | Yes |
| Soft Cream | #c8b99a | No |
| Parchment | #a89880 | No |

Background transitions use a dissolve (not snap). Light backgrounds use background-aware bloom extraction to prevent wash-out.

---

## UI Layout

The canvas is full bleed -- covers the entire screen edge to edge including safe areas. All UI overlays use transparent gradient backgrounds so the canvas shows through.

### TopBar (top of screen)

Two rows with gradient scrim (black 50% -> 30% -> clear):

**Row 1:**
- Wordmark: "sleepscape" in Cormorant Garamond Light Italic, 18pt, white at 22% opacity
- Vertical divider
- Palette chips: scrollable row, each chip shows 3 preview dots + name, selected state highlighted
- Day/night toggle: moon.fill or sun.max.fill icon, opens canvas background picker popover

**Row 2:**
- Ink dots: 8 colored circles per palette, selected state shows white border
- Vertical divider
- Brush size dropdown: preview line at current weight, chevron, opens dropdown with 7 presets (hairline 0.5pt, fine 1.0pt, light 1.5pt, medium 2.5pt, broad 4.0pt, heavy 6.0pt, marker 8.0pt)
- Undo / redo buttons (arrow.uturn.backward / forward)

### GripStrip (bottom of screen)

Single row, 52pt height, with gradient scrim (clear -> 30% -> 50% black):
- Play/pause button (circle)
- Speaker icon + volume slider (0-1, max width 140pt)
- Clear button ("clear" text in coral/pink)
- Sleep timer button (crescent moon + label), popover with 15/30/60 minute options + cancel
- Settings gear button

### SettingsSheet

Slides up from bottom with drag handle. Dismisses on: tap scrim, drag down >100pt, or 10 seconds of no interaction.

**5 cards in a LazyVGrid (2 columns):**

1. **Canvas card:** mode picker (free / mandala / ellipse), fold picker (4/6/8/12/16, shown only in mandala mode)

2. **Stroke card:** line style pills (neon/soft/dash/dot/sketch), auto color toggle + interval slider (4-30s), path smoothing toggle, slow ink toggle, pace slider (free to slow, 0-120ms)

3. **Effects card:** ambient blooms toggle + intensity slider (0.1-1.0), sparkles toggle, ripples toggle

4. **Breathing card:** breath pulse toggle, pattern pills in 2 rows (4-7-8 / Box / Cardiac, Resonance / Gentle / Custom), preset subtitle, phase breakdown with timing and ring behavior notes, custom sliders (inhale/hold/exhale/hold2, 1-12s each, shown when Custom selected)

5. **Audio card:** frequency preset list (delta / theta / 528 Hz) with name and description

### Sleep Overlay

Full-screen black rectangle, fades in on sleep. Tap anywhere to dismiss.

---

## Typography

Three font files bundled, registered in Info.plist `UIAppFonts`:
- `CormorantGaramond-LightItalic.ttf` -- wordmark
- `CrimsonPro-Light.ttf` -- UI labels, buttons, section headers
- `CrimsonPro-ExtraLight.ttf` -- secondary text, descriptions, slider labels

Both typefaces are open source (SIL Open Font License), sourced from Google Fonts.

---

## Drawing Modes

- **Free:** no symmetry, 1 transform (identity). Smooth strokes only.
- **Mandala:** N-fold rotational symmetry + Y-axis mirror per fold. Default N=8. Fold picker visible in settings. 2N total transforms.
- **Ellipse:** drag defines bounding box. Ellipse center, radii, rotation from drag vector. Symmetry transforms applied to ellipse center. Shaders exist but full touch interaction may need additional wiring.

---

## Brush

Default size: 0.5pt (hairline). Range via dropdown: 0.5pt to 8.0pt.

7 named presets: hairline (0.5), fine (1.0), light (1.5), medium (2.5), broad (4.0), heavy (6.0), marker (8.0).

Stroke rendering uses 3 passes for neon style (see Stroke Rendering section). Other styles use single-pass with style-specific fragment behavior.

---

## State Management

`AppState` is a single `@Observable` class holding all UI state:
- Drawing: mode, symmetry, brush size, palette, ink index, line style
- Effects: sparkles, ripples, blooms (enabled + spawn rate + intensity)
- Breathing: preset, custom timings, pulse enabled
- Audio: playing state, volume, preset
- Canvas: background, picker states
- Session: breath guide, sleep overlay, settings visibility
- Stroke controls: path smoothing, slow ink, pace throttle (persisted via UserDefaults)

---

## Privacy

- No data collection
- No analytics
- No network requests
- No tracking or third-party SDKs (AudioKit is local audio only)
- `PrivacyInfo.xcprivacy` included declaring no data collection

---

## Planned Improvements

### Sound design (see sound_design_brief.md)

- Replace CostelloReverb with ConvolutionReverb using real impulse responses for warmer, more realistic reverb
- Improve bell partials with inharmonic ratios and per-partial envelope shaping
- Add macro dynamics (coordinated multi-minute swells across all notes)
- Consider gentle compression on master bus for consistent sleep-safe volume levels

### Other

- Exponential sleep timer fade (currently linear)
- Drawing persistence (strokes are Codable but not saved to disk)
- Ink contrast improvement on light backgrounds (auto-darken or alternate ink sets)
- Clean up legacy UI files (BottomSheet.swift and old row files)
- Complete ellipse mode touch interaction wiring
