# Sleepscape — Technical Specification
### Version 1.0 · March 27, 2026
### Built by Heela Goren with Claude Code

---

## Table of Contents
1. [Overview](#1-overview)
2. [Technical Stack](#2-technical-stack)
3. [Project Structure](#3-project-structure)
4. [Feature Timeline](#4-feature-timeline)
5. [Drawing Engine](#5-drawing-engine)
6. [Metal Rendering Pipeline](#6-metal-rendering-pipeline)
7. [Symmetry System](#7-symmetry-system)
8. [Visual Effects](#8-visual-effects)
9. [Audio Engine — For Sound Engineer](#9-audio-engine--for-sound-engineer)
10. [UI Architecture](#10-ui-architecture)
11. [Problems Encountered & Solutions](#11-problems-encountered--solutions)
12. [Current Limitations & Future Work](#12-current-limitations--future-work)

---

## 1. Overview

Sleepscape is an iPad meditation app that combines real-time mandala drawing with ambient binaural audio. The user draws with Apple Pencil or finger; strokes are mirrored in n-fold rotational symmetry to create mandalas. The drawing is accompanied by synthesized ambient soundscapes with binaural beating tuned to brainwave frequencies (delta, theta, 528 Hz solfeggio).

The app is designed to feel like a premium, meditative experience — slow-ink feel, soft glow effects, breathing center pulse, and sparse ambient blooms that ripple outward and dissolve.

**Target device**: iPad Pro (M-series), optimized for 120 Hz ProMotion display.
**Deployment**: iOS 18+, built with Xcode 16.3.

---

## 2. Technical Stack

| Layer | Technology |
|-------|-----------|
| **UI Framework** | SwiftUI (declarative overlays) + UIKit (MTKView touch handling) |
| **Rendering** | Metal (custom vertex/fragment shaders, instanced rendering) |
| **Image Processing** | MetalPerformanceShaders (Gaussian blur for bloom) |
| **Audio Synthesis** | AudioKit 5.6.1 + SoundpipeAudioKit 5.6.1 (oscillators, reverb, filters) |
| **Project Generation** | XcodeGen (project.yml → .xcodeproj) |
| **Package Manager** | Swift Package Manager (SPM) |
| **Build Target** | iOS 18.0, iPad only |
| **Frame Rate** | 120 fps (MTKView.preferredFramesPerSecond = 120) |

### SPM Dependencies
- `AudioKit` 5.6.1 — Core audio engine, oscillators, mixers, faders
- `SoundpipeAudioKit` 5.6.1 — CostelloReverb, filters, DSP
- `AudioKitEX` 5.6.2 — Extended utilities (auto-resolved)
- `KissFFT` 1.0.0 — FFT library (AudioKit dependency)

### Fonts
- `CormorantGaramond-LightItalic` — Wordmark
- `CrimsonPro-Light`, `CrimsonPro-ExtraLight` — All UI labels

---

## 3. Project Structure

```
Sleepscape/
├── App/
│   ├── SleepscapeApp.swift          # @main entry point
│   └── ContentView.swift            # Root ZStack: canvas + top bar + grip strip + settings
├── Drawing/
│   ├── MetalCanvasView.swift        # MTKView + Coordinator (all Metal setup, draw loop, touch handling)
│   ├── DrawingEngine.swift          # Stroke management, ripples, blooms, sparkles, undo/redo
│   ├── Shaders.metal                # All GPU shaders (~600 lines)
│   ├── Stroke.swift                 # Stroke + StrokePoint data structures
│   └── SymmetryTransform.swift      # N-fold rotational + mirror affine matrix generation
├── Audio/
│   ├── AudioEngine.swift            # SleepscapeAudioEngine — full AVAudioEngine graph
│   └── AudioViewModel.swift         # Observable bridge (currently unused, engine called directly)
├── Models/
│   ├── AppState.swift               # @Observable shared state for all UI + drawing
│   ├── Palette.swift                # 6 color palettes with 8 inks each
│   ├── DrawMode.swift               # Enum: free, mandala, ellipse
│   ├── LineStyle.swift              # Enum: neon, softGlow, dashed, dotted, sketch
│   └── AudioPreset.swift            # Struct: delta, theta, 528hz presets
├── UI/
│   ├── TopBar.swift                 # Two-row top overlay (palette chips, ink dots, brush, undo/redo)
│   ├── GripStrip.swift              # Bottom bar (play/pause, volume, save, clear, sleep, settings)
│   ├── SettingsSheet.swift          # Half-screen 2×2 card drawer (canvas, stroke, effects, audio)
│   ├── BreathGuide.swift            # "your hand is already here →" idle prompt
│   ├── SleepOverlay.swift           # Dimmed sleep mode overlay
│   └── [Legacy row files]          # ModeRow, SymmetryRow, PaletteRow, etc. (from old BottomSheet)
├── Resources/
│   └── Fonts/                       # .ttf font files
└── project.yml                      # XcodeGen project definition
```

---

## 4. Feature Timeline (Build Order)

### Phase 1: Project Setup & Metal Foundation
- Created Xcode project via XcodeGen
- Set up MTKView with UIViewRepresentable wrapper
- Implemented persistent stroke texture (strokes accumulate on GPU texture)
- Basic touch → pixel coordinate → GPU rendering pipeline
- Solid background color from palette

### Phase 2: Symmetry + Multi-Pass Stroke Rendering
- Implemented n-fold rotational symmetry with mirror transforms (3×3 affine matrices)
- Added 3-pass stroke rendering: halo glow → mid glow → sharp core
- Segment rendering (line strips between consecutive points)
- Dot rendering at each stroke point
- Pressure-sensitive brush width via Apple Pencil (`pow(pressure, 0.6)` curve)

### Phase 3: Visual Effects Layer
- **Bloom/glow**: Bright-pass extraction + MPS Gaussian blur (sigma 12) + additive composite
- **Ripple rings**: Concentric circles expanding from touch points, mirrored across symmetry axes
- **Ambient blooms**: Random glowing circles that seed, expand outward, and dissolve
- **Sparkle particles**: Tiny glowing dots along Apple Pencil strokes
- **Center glow**: Soft radial glow at canvas center (always on)

### Phase 4: Audio Engine
- Built binaural drone layer with 7-note detuned oscillator pairs
- Added piano bell triggers every 4–11 seconds with harmonic decay
- Implemented breathing volume modulation per note
- Added 3 frequency presets (delta, theta, 528 Hz)
- Signal chain: lowpass → dry/wet split → CostelloReverb → master fader

### Phase 5: Line Styles + Color System
- Added 5 line styles with different glow pass parameters
- 6 color palettes × 8 inks each
- Auto color cycling toggle with speed slider
- Cumulative distance tracking for dashed/dotted styles (shader-based)

### Phase 6: Undo/Redo + Save
- Stroke-level undo/redo (full re-render from history on undo)
- PNG export to Photos at full resolution

### Phase 7: Mandala Containment Circle
- Mandala size slider (30%–100% of canvas)
- Touch clipping: drawing ignored outside mandala boundary
- Soft glowing border ring at mandala edge
- Blooms constrained to spawn inside mandala circle (polar sampling)

### Phase 8: Relaxation Polish
- Center breathing pulse (8-second sine wave, visible only when idle)
- Radial vignette (edges darken 12%)
- Pencil smoothing (light EMA, factor 0.35)
- Finger smoothing tightened (factor 0.08)
- Brush size default changed to 0.5 with exponential slider mapping

### Phase 9: UI Redesign
- Replaced collapsible bottom sheet with three-layer layout:
  - **Top bar**: palette chips, ink dots, brush controls, undo/redo
  - **Grip strip**: play/pause, volume, save, clear, sleep, settings gear
  - **Settings sheet**: 2×2 card grid (canvas, stroke, effects, audio)

---

## 5. Drawing Engine

### Stroke Data Model
```swift
struct StrokePoint {
    x, y: Float          // pixel coordinates
    pressure: Float       // 0–1 (Apple Pencil force / max force)
    altitude: Float       // pencil tilt angle (radians)
    cumulDist: Float      // cumulative distance along stroke (for dash/dot patterns)
}

struct Stroke {
    points: [StrokePoint]
    colorR/G/B/A: Float
    brushSize: Float      // in pixels (already scaled by contentScaleFactor)
    mode: DrawMode
    lineStyle: LineStyle
}
```

### Smoothing
All touch input goes through exponential moving average:
- **Finger**: factor 0.08 (very smooth, slow-ink feel)
- **Pencil**: factor 0.35 (light, removes jitter while preserving accuracy)

```
smoothed = smoothed + (raw - smoothed) * factor
```

### Undo/Redo
- `strokes: [Stroke]` — committed strokes
- `undoneStrokes: [Stroke]` — redo stack
- On undo: pop last stroke → push to undone → re-render ALL remaining strokes to fresh texture
- On new stroke: clear redo stack

---

## 6. Metal Rendering Pipeline

### GPU Data Structures (Swift ↔ Metal alignment)
```
GPUStrokePoint    (24 bytes): float2 position, float pressure, float altitude, float cumulDist, float _pad
GPUStrokeUniforms (48 bytes): float2 canvasSize, float4 color, float brushSize, float alpha, float glowRadius, uint lineStyle
GPURippleData     (32 bytes): float2 center, float radius, float alpha, float4 color, int32 rings
GPUAmbientBloomData (32 bytes): float2 center, float radius, float alpha, float4 color
GPUSparkleData    (32 bytes): float2 position, float alpha, float size, float4 color
```

### Texture Resources
| Texture | Purpose | Cleared |
|---------|---------|---------|
| `strokeTexture` | Persistent — all committed strokes + current stroke | Only on clear/undo |
| `bloomSourceTexture` | Bright-pass extraction (temporary) | Every frame |
| `bloomBlurTexture` | Gaussian-blurred bloom (temporary) | Every frame |
| `rippleTexture` | Ephemeral ripple rings | Every frame |

### Render Pass Sequence (per frame)

1. **Update particles**: ripples (expand + fade), sparkles (shrink + fade), ambient blooms (expand + dissolve)
2. **Compute mandala radius** in pixels from slider value
3. **Render new strokes** to `strokeTexture` (load existing, alpha-blend new strokes on top)
4. **Render ripples** to `rippleTexture` (cleared, fresh each frame)
5. **Bloom pass**: bright-pass extract from strokeTexture → Gaussian blur → bloomBlurTexture
6. **Final composite** to drawable (9 layers):
   - Blit strokeTexture (no blend, overwrites background)
   - Mandala border glow ring (additive)
   - Center glow (additive)
   - Breathing pulse (additive, only when idle)
   - Bloom blur (additive)
   - Ambient blooms (additive)
   - Sparkles (additive)
   - Ripples (alpha blend)
   - Vignette (alpha blend, darkens edges)

### 3-Pass Stroke Rendering
Each stroke is rendered 3 times with different width multipliers and alpha:

| Style | Pass 1 (Halo) | Pass 2 (Mid) | Pass 3 (Core) |
|-------|---------------|--------------|----------------|
| Neon | 3.2× width, α=0.03 | 1.5×, α=0.18 | 0.5×, α=0.90 |
| Soft Glow | 4.0×, α=0.04 | 2.0×, α=0.12 | 0.8×, α=0.60 |
| Dashed | 2.0×, α=0.05 | 1.0×, α=0.20 | 0.4×, α=0.85 |
| Dotted | 2.5×, α=0.06 | 1.2×, α=0.15 | 0.5×, α=0.90 |
| Sketch | 2.0×, α=0.02 | 1.0×, α=0.10 | 0.5×, α=0.80 |

### Instanced Rendering
Ripples, ambient blooms, and sparkles use **instanced quad rendering** (2 triangles = 6 vertices per instance). This avoids Metal's 511px point-size limit that caused square artifacts with large ripples.

---

## 7. Symmetry System

Transforms are generated as 3×3 affine matrices:

```
For n-fold mandala:
  2n transforms total (n rotations × 2 for mirror)

  For i in 0..<n:
    rotation_angle = i × (2π / n)
    transform[2i]   = toCenter × rotate(angle) × toOrigin
    transform[2i+1] = toCenter × rotate(angle) × flipY × toOrigin
```

Where:
- `toOrigin` = translate(-canvasCenter)
- `rotate` = 2D rotation matrix
- `flipY` = mirror across Y axis: (x,y) → (-x,y)
- `toCenter` = translate(+canvasCenter)

All transforms applied on GPU via instanced rendering. Each stroke primitive is drawn `2n` times with different transform matrices.

---

## 8. Visual Effects

### Ripples
- **Trigger**: Every 400ms during touch, at all symmetry-mirrored positions
- **Starting radius**: 30px, expanding at 0.35–0.50 px/frame
- **Max radius**: 250–300px
- **Fade**: Accelerating decay: `alpha *= (1.0 - 0.002 - 0.025 × progress²)`
- **Visual**: Soft filled glow + ring accent at 0.7–0.9 of radius
- **Rendering**: Instanced quads, 3 concentric rings per ripple

### Ambient Blooms
- **Spawn**: Inside mandala circle only, polar-sampled, every 0.5–3s
- **Lifecycle**: Tiny seed (6px) → expand outward (accelerating) → dissolve as alpha fades
- **Peak alpha**: 0.08–0.20 (never opaque)
- **Max radius**: 80–220px
- **Fade**: `alpha *= (1.0 - 0.006 - 0.025 × progress²)` during fadeOut phase

### Sparkles
- **Trigger**: Along Apple Pencil strokes when segment length > 2px
- **Count**: 1–3 per trigger, randomly offset ±8px
- **Fade**: `alpha *= 0.95`, `size *= 0.98` per frame
- **Lifetime**: 20–50 frames

### Center Breathing Pulse
- **Period**: ~8 seconds (`sin(time × 0.785)`)
- **Sigma**: 15% of mandala radius
- **Alpha**: max 0.05 (ultra-subtle)
- **Condition**: Only visible when NOT drawing, fades in 2s after last stroke ends

### Radial Vignette
- **Effect**: Edges darken by up to 12%
- **Falloff**: `smoothstep(0.4, 1.4, distance_from_center)`

---

## 9. Audio Engine — For Sound Engineer

### Overview
The audio engine synthesizes ambient soundscapes in real-time using AudioKit 5.6.1. There are no audio samples — everything is generated from sine oscillators, white noise, and algorithmic envelopes. The goal is a warm, non-threatening ambient pad with gentle binaural beating and occasional soft bell tones.

### Signal Flow Diagram
```
BINAURAL DRONE LAYER (per-note × 7 notes):
  Base frequency → split into:
    LEFT:  f × 2^(-detuneCents/1200)  → Oscillator(sine) → Fader (breathing envelope) → Left Bus Mixer → Panner(-1.0)
    RIGHT: f × 2^(+detuneCents/1200)  → Oscillator(sine) → Fader (breathing envelope) → Right Bus Mixer → Panner(+1.0)
  Left Panner + Right Panner → Stereo Merger

WANDERING MELODY:
  Random note from preset frequencies → Oscillator(sine, frequency ramped over 4-9s)
    → Fader (volume envelope) → wandererGain

NOISE FLOOR:
  WhiteNoise → BandPassButterworthFilter(center: 800Hz, bandwidth: 400Hz)
    → Fader(gain: 0.004) → noiseGain

PRE-MIX:
  Stereo Merger + wandererGain + noiseGain → preMixer

PROCESSING:
  preMixer → LowPassFilter(cutoff: preset-specific, resonance: 0.15)
    → SPLIT:
      6% → Dry Fader (bypasses reverb)
      94% → Wet Fader → CostelloReverb(feedback: preset-specific, cutoff: 6000Hz)

PIANO BELLS (bypass reverb entirely):
  Random bell frequency → 3 harmonic oscillators:
    1× fundamental (amplitude 0.07)
    2× fundamental (amplitude 0.035)
    4× fundamental (amplitude 0.012)
  Each with: 0.06s attack → 8.0s decay → stop
  All → bellMixer

MASTER:
  Dry + Reverb + bellMixer → masterMixer → masterFader → output
```

### Binaural Beat Generation
Binaural beats are created by detuning left and right channel oscillators by equal and opposite amounts in cents. The brain perceives the frequency difference as a phantom beat.

**Detuning formula**:
- Left channel: `f × 2^(-cents/1200)`
- Right channel: `f × 2^(+cents/1200)`
- Perceived beat frequency ≈ `f × cents/600` Hz (for small cent values)

**Example (Delta preset, 220 Hz base, ±4 cents)**:
- Left: 220 × 2^(-4/1200) = 219.49 Hz
- Right: 220 × 2^(+4/1200) = 220.51 Hz
- Beat: ~1.02 Hz (within delta brainwave range 0.5–4 Hz)

**Important**: Binaural beats only work with headphones. Each ear must receive a different frequency.

### Breathing Envelope (Per Note)
Each of the 7 drone notes has an independent breathing cycle with randomized timing:

| Phase | Duration | Volume |
|-------|----------|--------|
| Fade-in (attack) | 5–11s | 0 → 0.02–0.06 |
| Hold (sustain) | 8–22s | steady at peak |
| Fade-out (release) | 6–14s | peak → 0.001 |
| Rest (silence) | 8–22s | 0.001 |

Notes are staggered: each starts with a random 0–12s delay. The result is an organic, slowly shifting pad where individual notes breathe in and out independently — no two cycles align.

Low frequencies (< 120 Hz) get a 1.2× volume boost for bass presence.

### Piano Bell Implementation
Bells trigger every 4–11 seconds (randomized). Each bell is:
- A random frequency from: `[110, 164.81, 220, 246.94, 329.63, 440, 493.88]` Hz
- Rendered as 3 sine harmonics: fundamental (0.07), octave (0.035), double-octave (0.012)
- Fast attack (0.06s), long decay (8.0s), then oscillator is destroyed
- **Bypass reverb** — goes directly to master mixer (keeps bells crisp)

### Wandering Melody
A single sine oscillator that slowly glides between random frequencies from the current preset:
- Glide time: 4–9 seconds (portamento)
- Hold time: 12–32 seconds
- Volume: 0.02–0.06 (barely perceptible, adds subconscious movement)
- Begins 2 seconds after engine start

### Noise Floor
- White noise → bandpass filter (center 800 Hz, bandwidth 400 Hz = 400–1200 Hz band)
- Fixed gain: 0.004 (barely audible, adds air/texture)

### Filter & Reverb Settings

| Parameter | Delta | Theta | 528 Hz |
|-----------|-------|-------|--------|
| Lowpass cutoff | 1400 Hz | 1800 Hz | 2200 Hz |
| Lowpass resonance | 0.15 | 0.15 | 0.15 |
| Reverb feedback | 0.95 | 0.93 | 0.92 |
| Reverb cutoff | 6000 Hz | 6000 Hz | 6000 Hz |
| Dry/wet split | 6%/94% | 6%/94% | 6%/94% |
| Volume scale | 1.0 | 0.9 | 0.8 |

### Preset Specifications

**Delta (Deep Sleep)**
- Frequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440] Hz (7 notes)
- Detune: ±4 cents → ~2 Hz binaural beat
- Character: Warmest, deepest, most reverb. Targets 0.5–4 Hz delta brainwaves.

**Theta (Meditation)**
- Frequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440] Hz (same 7 notes)
- Detune: ±16 cents → ~4–8 Hz binaural beat
- Character: Slightly brighter, more active beating. Targets 4–8 Hz theta brainwaves.

**528 Hz Solfeggio (Warm/Healing)**
- Frequencies: [132, 264, 396, 528, 594, 792] Hz (6 notes, all 528-aligned)
- Detune: ±2 cents → ~1–2 Hz gentle beat
- Character: Brightest filter, warmest tone. Based on solfeggio "love frequency."
- Bell frequencies remain the same standard set across all presets.

### Crossfade Preset Switching
When the user changes presets while audio is playing:
1. Fade out master over 0.8s
2. Wait 0.9s (let fade complete)
3. Kill all timers (breathing, bells, wanderer)
4. Stop engine
5. Rebuild entire audio graph with new preset values
6. Start engine + fade in over 0.8s

### Known Audio Limitations / Areas for Improvement
- All oscillators are pure sine waves — no wavetable or sample-based synthesis
- Bells are simple additive harmonics (fundamental + octave + double-octave) — could benefit from more complex timbres, inharmonic partials, or sample-based bells
- Reverb is CostelloReverb only — could layer a convolution reverb for more spatial depth
- No stereo width processing beyond hard L/R panning for binaural
- Noise floor is very simple (bandpass white noise) — could use more sophisticated ambience
- No sidechain or ducking between layers
- Volume envelope is linear ramp — could use exponential or custom curves for more natural breathing
- Bell timing is purely random — could use musical interval awareness
- No EQ or multiband compression on master bus
- Binaural effectiveness depends on headphone use — no headphone detection implemented
- Drone volume range is narrow (0.02–0.06) — could be more dynamic
- The wandering melody is a single sine — could be a more complex tone

### AudioKit Nodes Used
| Node | Purpose |
|------|---------|
| `Oscillator(waveform: Table(.sine))` | All tone generation (drone, bells, wanderer) |
| `Mixer` | Combining signals (left bus, right bus, stereo merge, pre-mix, bell, master) |
| `Fader` | Gain control with `.ramp()` for envelopes |
| `Panner` | Stereo positioning (hard L/R for binaural) |
| `LowPassFilter` | Warmth control (preset-specific cutoff) |
| `CostelloReverb` | Spatial depth (preset-specific feedback) |
| `WhiteNoise` | Ambient texture source |
| `BandPassButterworthFilter` | Noise shaping (800 Hz center) |

---

## 10. UI Architecture

### Layout (3 layers overlaying full-bleed canvas)

**Top Bar** (2 rows, gradient overlay top → transparent):
- Row 1: Wordmark (`sleepscape`, ghost opacity) · Palette chips (3 dot preview + name) · Day/night icons
- Row 2: 8 ink color dots · Brush size (−/dot/+) · Undo/redo buttons

**Grip Strip** (bottom, gradient overlay transparent → dark):
- Play/pause · Volume slider · Save · Clear · Sleep · Settings ⚙

**Settings Sheet** (half-screen drawer from ⚙, dark scrim behind):
- Drag handle, dismiss on: tap outside / drag down / 10s idle
- 2×2 card grid: Canvas · Stroke · Effects · Audio

### State Management
Single `@Observable AppState` class shared across all views:
- Drawing state: drawMode, symmetry, brushSize, mandalaRadius, palette, inkIndex, lineStyle
- Effects: bloomsEnabled, bloomSpawnRate, bloomIntensity
- Audio: isPlaying, volume, currentPreset
- Actions: clearRequested, undoRequested, redoRequested, saveRequested

ContentView uses `.onChange()` modifiers to bridge AppState changes to the audio engine.

---

## 11. Problems Encountered & Solutions

### DNS / Network Issues
- **Problem**: GitHub completely unreachable from user's network. `ping github.com` → 100% packet loss. `curl` → "Could not resolve host."
- **Diagnosis**: IPv6-only DNS servers (`2a06:c701:ffff::*`) were failing to resolve GitHub's addresses.
- **Fix**: Switched to Google DNS (`8.8.8.8`, `8.8.4.4`) via `networksetup -setdnsservers`. GitHub resolved but the IP returned (20.217.135.5) was still unreachable. Added manual `/etc/hosts` entry pointing `github.com` to alternate IP `140.82.121.3`.

### Xcode Installation
- **Problem**: `xcodes install 16.3` failed with 403 Unauthorized.
- **Cause**: Apple Developer Terms and Conditions not accepted, plus corrupted initial download.
- **Fix**: Installed Xcode 16.3 from Mac App Store instead (different auth path).

### Metal Toolchain Missing
- **Problem**: Build failed with "cannot execute tool 'metal' due to missing Metal Toolchain."
- **Cause**: Xcode 16.3 from App Store didn't include the Metal toolchain as a bundled component; `xcodebuild -downloadComponent MetalToolchain` failed because Apple's asset servers were unreachable from user's network.
- **Fix**: Removed the `Inferno` package dependency (third-party Metal shader library by @twostraws) which was the only thing requiring the Metal toolchain for its `.metal` shader files. Our own shaders compiled fine because they're part of the app target, not a package.

### SoundpipeAudioKit Version Mismatch
- **Problem**: SPM couldn't resolve dependencies — no version `5.6.4` of SoundpipeAudioKit exists.
- **Fix**: Pinned to `5.6.1` (latest available) with matching AudioKit `5.6.1`.

### Square Ripples / Blooms
- **Problem**: Large ripples (radius > 250px) appeared as squares instead of circles.
- **Cause**: Metal point primitives have a max `[[point_size]]` of 511 on iOS. Ripples with radius 300 = pointSize 600, exceeding the limit. Metal silently clamps, creating squares.
- **Fix**: Rewrote ripples, ambient blooms, and sparkles to use **instanced quad rendering** (2 triangles = 6 vertices per instance with UV-based distance calculation in fragment shader). No size limit.

### Ripples Not Visible
- **Problem**: Multiple iterations where ripples weren't showing. Causes included:
  1. Composite pipeline had no blending — transparent ripple texture overwrote everything
  2. Ripples started at radius 0 and grew at 0.15px/frame — invisible for first 2 seconds because ring was sub-pixel thin
  3. Fragment shader ring band too narrow at small sizes
- **Fixes**: Added alpha-blended composite pipeline; started ripples at radius 30; widened ring band in shader; added filled glow + ring accent.

### Bloom Abrupt Appearance/Disappearance
- **Problem**: Ambient blooms appeared as opaque circles that grew then vanished suddenly.
- **Fix**: Redesigned bloom lifecycle as continuous expansion from tiny seed (6px) → outward ripple → dissolve with accelerating fade tied to expansion progress. Never opaque (peak alpha 0.08–0.20).

### Code Signing After XcodeGen
- **Problem**: Every `xcodegen generate` call reset code signing settings, breaking the build.
- **Fix**: Added signing configuration to `project.yml` under target settings, or re-applied after each generation.

### Audio Too Ominous
- **Problem**: Initial audio implementation sounded dark and eerie — heavy drone, scary binaural beating.
- **Fixes**:
  1. Reduced drone volume range (0.02–0.06, was higher)
  2. Added piano bells every 4–11s for brightness
  3. Created 3 distinct presets with different characters
  4. Added lowpass filtering per preset (warmer = less harsh harmonics)
  5. Bells bypass reverb (stay crisp, don't add to drone muddiness)

---

## 12. Current Limitations & Future Work

### Drawing
- No layer system — all strokes on one texture
- No stroke editing after completion (only full undo)
- No export as SVG/vector — PNG only
- Ellipse mode is basic (no aspect ratio control)

### Audio
- See "Known Audio Limitations" in Section 9 for detailed list
- No headphone detection (binaural requires headphones)
- No background audio session configuration
- Volume only, no per-layer mixing controls exposed to user

### Visual
- Day/night toggle buttons in top bar are placeholder (not functional)
- Sparkles and ripples toggles in settings are placeholder (always on)
- No animation on palette/ink transitions
- Vignette is static (could pulse subtly)

### Performance
- Undo triggers full re-render of all strokes (can stutter with many strokes)
- No texture atlas or LOD for particle effects
- Audio engine rebuilds entire graph on preset switch (brief gap)

### Platform
- iPad only — no iPhone adaptation
- No iCloud sync or project saving/loading
- No Apple Pencil hover support (iPadOS 16.1+ feature)
