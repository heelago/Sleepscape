# Sleepscape -- Developer Handoff

This document captures the current state of the project, architecture decisions, known issues, and context for the next development session.

---

## Current State

The app is fully functional and builds and runs on iPad. All core features are implemented: Metal rendering at 120fps, 3 drawing modes with 5 symmetry folds, 5 line styles, 6 palettes, generative audio with 3 presets, breathing guide with 6 presets, and the full UI (TopBar + GripStrip + SettingsSheet). Audio plays in the background via AVAudioSession `.playback` category.

---

## Architecture Decisions

### Metal over SpriteKit

SpriteKit was considered but rejected. The app needs to render strokes with 3-pass glow, bloom extraction, Gaussian blur, ripple particles, ambient blooms, sparkles, vignette, and breath pulse -- all at 120fps. Metal provides direct control over the GPU pipeline, custom shaders, and efficient instanced rendering. SpriteKit's abstraction layer would have introduced unnecessary overhead and limited shader customization.

### @Observable over @Published

The project uses Swift 5.9's `@Observable` macro exclusively. No `ObservableObject` or `@Published` anywhere. This was chosen because iOS 17+ is the minimum target, and `@Observable` is simpler -- no need for `@StateObject` vs `@ObservedObject` distinctions, and SwiftUI automatically tracks property access for fine-grained view updates.

### Persistent stroke texture

Strokes accumulate into a persistent `strokeTexture` that is never cleared except on user "clear" or undo. Each frame only renders *new* strokes since the last frame onto this texture, then composites the full texture to the display. On undo, the texture is fully re-rendered from the remaining stroke array. This avoids re-rendering all strokes every frame while keeping undo working correctly.

### 3-pass stroke rendering (neon glow)

Each stroke is rendered in three passes with different widths and alpha values:
1. Wide halo: `brushSize * 3.2`, alpha 0.03
2. Mid glow: `brushSize * 1.5`, alpha 0.18
3. Bright core: `brushSize * 0.5`, alpha 0.90

This layered approach reproduces the neon glow effect from the HTML prototype. All three passes use the same segment/dot vertex shaders but with different uniform values. The other line styles (soft glow, dashed, dotted, sketch) are handled by branching in the fragment shader based on a `lineStyle` uniform.

### Background-aware bloom extraction

The bloom bright-pass shader (`brightPassFragment`) subtracts the current canvas background color from each pixel before determining brightness. This means only stroke pixels (which deviate from the background) contribute to the bloom. Without this, light canvas backgrounds (Soft Cream, Parchment) would cause the entire screen to bloom, washing everything out.

### UserDefaults for stroke controls

Path smoothing, slow ink, and pace throttle are persisted via UserDefaults with computed properties in AppState. These are the only settings that persist across sessions. The choice was deliberate -- these are "tool preferences" that users set once and expect to stick, unlike palette/mode which are more session-specific.

### Flag-based background re-render

When the canvas background changes (palette switch or background picker), the stroke texture needs to be re-rendered against the new background. This is triggered by a flag (`needsBackgroundReRender`) checked in the Metal draw loop, not in `updateUIView`. Doing it in `updateUIView` caused timing issues because the SwiftUI update cycle and Metal render loop are not synchronized. The draw loop checks the flag, re-renders all accumulated strokes onto a fresh texture with the new background, and clears the flag.

---

## Known Issues and Things to Watch

### Light backgrounds and ink contrast

The bloom extraction now works correctly on light backgrounds (Soft Cream, Parchment) thanks to background-subtracted bright-pass. However, some ink colors (especially lighter ones like white or pale blues) have reduced contrast against light backgrounds. A future improvement could auto-darken inks when a light background is selected, or provide a separate set of ink colors tuned for light backgrounds.

### Sleep timer uses linear fade

The sleep timer fades audio volume linearly over the selected duration (15/30/60 minutes). An exponential curve might feel more natural -- humans perceive volume logarithmically, so a linear fade can feel like it drops off quickly at the end. Consider `pow(1.0 - progress, 2.0)` or similar.

### Legacy files still present

- `BottomSheet.swift` is the original bottom sheet UI from the spec. It has been fully replaced by `GripStrip.swift` + `SettingsSheet.swift` but the file still exists in `Sleepscape/UI/`.
- Several UI row files from the old bottom sheet remain: `AutoColorRow.swift`, `BloomsRow.swift`, `BrushRow.swift`, `InkRow.swift`, `LineStyleRow.swift`, `ModeRow.swift`, `PaletteRow.swift`, `SymmetryRow.swift`. These are not referenced by the current UI but have not been deleted.
- `MandalaRadiusRow.swift` was deleted (the mandala radius clipping circle was removed) but the other row files remain.

### Ambient bloom dissipation (in progress)

The ambient bloom shader uses a 3-phase firework effect: gaussian glow -> Voronoi heat-shimmer breakup -> 18 scattered ember pseudo-particles. The shader is implemented (`ambientBloomFragment` in Shaders.metal) using hash-based noise and per-ember random birth/death timings. Current status: the math works but the visual tuning needs more iteration -- the bloom alpha, expansion speed, and ember visibility need adjustment to hit the sweet spot between "invisible" and "opaque circle." The DrawingEngine bloom lifecycle (fadeIn -> fadeOut with continuous expansion) and the GPU data struct (now includes `progress` field) are ready. This is the main visual effect still being refined.

### No drawing persistence

Drawing state (strokes) is not persisted. When the app is killed or backgrounded for too long, all strokes are lost. The `Stroke` struct is `Codable`, so serialization to disk would be straightforward but has not been implemented.

### Ellipse mode

Ellipse mode exists and has Metal shaders (`ellipseVertex` / `ellipseFragment`) and GPU uniform structs, but the full touch interaction (drag-to-define bounding box, live preview, commit on touch end) may not be completely wired up. The shaders handle symmetry transforms on the ellipse center and render a ring with soft fill. Needs testing and potentially more work on the touch handling side.

---

## Sound Design -- Next Pass

The audio engine works and sounds decent, but a significant improvement pass is planned. Heela's brother is a sound engineer and a brief has been prepared (see `sound_design_brief.md` if it exists). Key improvements to explore:

- **Replace CostelloReverb with ConvolutionReverb + real impulse responses:** CostelloReverb is algorithmic and can sound metallic. ConvolutionReverb with a carefully chosen IR (cathedral, chamber, or custom) would add significantly more realism and warmth.
- **Improve bell partials:** Current bells use 3 sine partials (fundamental + octave + 2 octaves). Real piano/bell tones have inharmonic partials, slight detuning, and more complex spectral envelopes. Consider adding more partials with inharmonic ratios and per-partial envelope shaping.
- **Add macro dynamics:** The current breathing pattern for binaural notes operates independently per note. Adding coordinated macro dynamics (e.g., all notes swell together over 2-3 minute arcs) would create a more organic, evolving soundscape.
- **Consider compression:** A gentle compressor or limiter on the master bus could smooth out volume spikes from bell attacks and provide a more consistent listening level, especially important for sleep use.

---

## What Was Tried But Did Not Work

### Inferno shader package

The Inferno package (by Paul Hudson / twostraws) was included in the original spec as an SPM dependency for Metal shader effects. It was removed because resolving the package triggered a Metal Toolchain download from Apple's servers that consistently failed. Rather than debug the toolchain issue, all visual effects were implemented with custom Metal shaders in `Shaders.metal`.

### Mandala radius clipping circle

An adjustable mandala radius was implemented early on, with a slider to control how large the mandala drawing area was. Strokes outside the radius were clipped. In practice this was frustrating -- it felt arbitrary and limiting, especially on a large iPad screen. The clipping was removed entirely. The canvas is now always fully usable edge to edge regardless of mode. `MandalaRadiusRow.swift` was deleted as part of this removal.

### Static center glow + breath pulse as center blob

Early iterations had a static glowing blob at the canvas center that pulsed with the breathing pattern. This looked like a distracting orb floating over the drawing. It was replaced with the current focus-peaking dotted ring, which is razor-thin (1.2px sigma), barely visible, and uses dots rather than a solid ring. The ring expands on inhale, flashes softly on hold, and contracts on exhale. Much more subtle and meditative.

### Point primitives for ripples and blooms

Initially, ripple rings and ambient blooms were rendered as point primitives (`MTLPrimitiveType.point`). iOS imposes a hard 511px limit on point size, which meant large ripples were visually clipped at a fixed diameter. The solution was to switch to instanced quads -- 6 vertices per instance forming a screen-aligned quad -- with the fragment shader handling the circular shape. This removes any size limit.

### DNS issues blocking GitHub and Apple servers

During development, SPM package resolution and Metal Toolchain downloads were failing silently. The root cause was DNS resolution failures for GitHub and Apple CDN servers. This was fixed by configuring Google DNS (8.8.8.8) as the primary resolver and adding specific entries to `/etc/hosts` for the affected domains.

---

## Feature Build Timeline

The app was built roughly in this order:

1. **Project setup:** Xcode project, SPM dependencies (AudioKit + SoundpipeAudioKit), folder structure, fonts (Cormorant Garamond, Crimson Pro), Info.plist configuration
2. **Basic Metal canvas:** MTKView rendering a solid background, touch draws dots, no symmetry
3. **Stroke rendering:** 3-pass neon glow, exponential moving average smoothing, brush size control
4. **Symmetry:** mandala mode with N-fold rotation + Y-axis mirror, instanced rendering via transform array in vertex buffer
5. **Drawing modes:** free mode, ellipse mode shaders, mode/fold selectors
6. **Palettes:** all 6 palettes, ink dot row, background dissolve transitions
7. **Audio engine:** binaural breathing notes, wandering melody, piano bells, white noise, background audio session
8. **UI overhaul:** replaced BottomSheet with TopBar + GripStrip + SettingsSheet card grid. Volume control, play/pause, sleep timer
9. **Apple Pencil:** pressure mapping, tilt/altitude, coalesced touches, predicted touches
10. **Visual effects:** ripple particles (switched to instanced quads), ambient blooms, sparkle particles, bloom extraction with background subtraction
11. **Breathing guide:** breath pulse dotted ring shader, 6 presets with phase timing, custom sliders, settings card
12. **Canvas backgrounds:** 6 backgrounds (4 dark, 2 light), background-aware bloom, day/night toggle
13. **Line styles:** 5 styles (neon, soft glow, dashed, dotted, sketch) implemented in vertex/fragment shaders
14. **Stroke controls:** path smoothing (Chaikin), slow ink, pace throttle, UserDefaults persistence
15. **Polish:** auto color cycling, undo/redo, radial vignette, center glow, sleep timer gradual fade, settings sheet auto-close
