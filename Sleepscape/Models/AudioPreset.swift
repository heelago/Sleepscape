import Foundation

struct AudioPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String

    /// Base frequencies for the binaural drone layer
    let noteFrequencies: [Float]

    /// Binaural detune in cents (applied ± to L/R channels)
    let detuneCents: Float

    /// Lowpass cutoff before reverb (warmer = lower)
    let lowpassCutoff: Float

    /// Reverb feedback (0.0–1.0, higher = longer tail)
    let reverbFeedback: Float

    /// Volume scaling (some presets need to be quieter)
    let volumeScale: Float

    // Bell frequencies are constant across ALL presets
    static let bellFrequencies: [Float] = [110, 164.81, 220, 246.94, 329.63, 440, 493.88]

    static let all: [AudioPreset] = [delta, theta, solfeggio528]

    // ── Delta: sleep-focused, gentle ~2Hz binaural beat ──
    static let delta = AudioPreset(
        id: "delta",
        name: "delta",
        description: "deep sleep · 2 Hz",
        noteFrequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440],
        detuneCents: 4.0,       // ~2Hz beat at 220Hz
        lowpassCutoff: 1400,
        reverbFeedback: 0.95,
        volumeScale: 1.0
    )

    // ── Theta: meditation-focused, ~6Hz binaural beat ──
    static let theta = AudioPreset(
        id: "theta",
        name: "theta",
        description: "meditation · 6 Hz",
        noteFrequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440],
        detuneCents: 16.0,      // ~4-8Hz beat depending on base freq
        lowpassCutoff: 1800,
        reverbFeedback: 0.93,
        volumeScale: 0.9
    )

    // ── 528Hz: solfeggio love frequency, warm and clear, minimal drone ──
    static let solfeggio528 = AudioPreset(
        id: "528hz",
        name: "528 hz",
        description: "solfeggio · warm",
        noteFrequencies: [132, 264, 396, 528, 594, 792],
        detuneCents: 2.0,       // very gentle beating
        lowpassCutoff: 2200,    // brighter, clearer
        reverbFeedback: 0.92,
        volumeScale: 0.8
    )
}
