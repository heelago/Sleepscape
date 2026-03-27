import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit

// ═══════════════════════════════════════════
//  Generative ambient audio engine — preset-driven
//  Signal: binaural → lowpass → dry/wet → reverb → master
//  Bells bypass reverb → master directly
// ═══════════════════════════════════════════

@Observable
class SleepscapeAudioEngine {
    private(set) var isRunning = false
    private var currentPreset: AudioPreset = .delta

    private let engine = AudioEngine()
    private var masterFader: Fader!

    // Binaural
    private var leftBusNotes: [BreathingNote] = []
    private var rightBusNotes: [BreathingNote] = []
    private var leftBusMixer: Mixer!
    private var rightBusMixer: Mixer!
    private var stereoMerger: Mixer!

    // Wanderer
    private var wanderer: Oscillator?
    private var wandererGain: Fader?

    // Noise
    private var noiseSource: WhiteNoise?
    private var noiseGain: Fader?

    // Signal chain
    private var preMixer: Mixer!
    private var lowpass: LowPassFilter?
    private var dryFader: Fader?
    private var wetFader: Fader?
    private var reverb: CostelloReverb?
    private var masterMixer: Mixer!

    // Bells (bypass reverb)
    private var bellMixer: Mixer!
    private var bellOscillators: [(osc: Oscillator, gain: Fader)] = []

    // Timers
    private var breatheTimers: [Timer] = []
    private var wanderTimer: Timer?
    private var bellTimer: Timer?

    // MARK: - Helpers

    private func rampFader(_ fader: Fader, to value: AUValue, duration: Float) {
        fader.$leftGain.ramp(to: value, duration: duration)
        fader.$rightGain.ramp(to: value, duration: duration)
    }

    // MARK: - Build graph from preset

    private func buildGraph() {
        let preset = currentPreset

        // ── Binaural pairs from preset ──
        leftBusNotes = preset.noteFrequencies.map { BreathingNote(frequency: $0, detuneCents: -preset.detuneCents) }
        rightBusNotes = preset.noteFrequencies.map { BreathingNote(frequency: $0, detuneCents: +preset.detuneCents) }

        leftBusMixer = Mixer(leftBusNotes.map { $0.gainNode as Node })
        rightBusMixer = Mixer(rightBusNotes.map { $0.gainNode as Node })

        let leftPanner = Panner(leftBusMixer, pan: -1.0)
        let rightPanner = Panner(rightBusMixer, pan: 1.0)
        stereoMerger = Mixer([leftPanner, rightPanner])

        // ── Wanderer ──
        let wOsc = Oscillator(waveform: Table(.sine))
        wOsc.frequency = preset.noteFrequencies.count > 3 ? preset.noteFrequencies[3] : 220
        wOsc.amplitude = 1.0
        wanderer = wOsc
        let wGain = Fader(wOsc, gain: 0.001)
        wandererGain = wGain

        // ── Noise — barely there ──
        let noise = WhiteNoise(amplitude: 1.0)
        noiseSource = noise
        let nFilter = BandPassButterworthFilter(noise, centerFrequency: 800, bandwidth: 400)
        let nGain = Fader(nFilter, gain: 0.004)
        noiseGain = nGain

        // ── Pre-mixer ──
        preMixer = Mixer([stereoMerger, wGain, nGain])

        // ── Lowpass from preset ──
        let lp = LowPassFilter(preMixer)
        lp.cutoffFrequency = preset.lowpassCutoff
        lp.resonance = 0.15
        lowpass = lp

        // ── Dry/Wet — mostly reverb for spaciousness ──
        let dry = Fader(lp, gain: 0.06)
        dryFader = dry
        let wet = Fader(lp, gain: 0.94)
        wetFader = wet

        let rev = CostelloReverb(wet)
        rev.feedback = preset.reverbFeedback
        rev.cutoffFrequency = 6000
        reverb = rev

        // ── Bells (bypass reverb) ──
        bellMixer = Mixer()

        // ── Master ──
        masterMixer = Mixer([dry, rev, bellMixer])
        masterFader = Fader(masterMixer, gain: 0.001)
        engine.output = masterFader
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        buildGraph()

        do {
            try engine.start()
            isRunning = true

            for note in leftBusNotes + rightBusNotes { note.osc.start() }
            wanderer?.start()
            noiseSource?.start()

            rampFader(masterFader, to: 0.75 * 0.7 * currentPreset.volumeScale, duration: 0.8)

            // Staggered breathing
            for i in 0..<currentPreset.noteFrequencies.count {
                let delay1 = Double.random(in: 0...12)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay1) { [weak self] in
                    guard let self = self, self.isRunning, i < self.leftBusNotes.count else { return }
                    self.scheduleBreathe(for: self.leftBusNotes[i])
                }
                let delay2 = Double.random(in: 0...12)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay2) { [weak self] in
                    guard let self = self, self.isRunning, i < self.rightBusNotes.count else { return }
                    self.scheduleBreathe(for: self.rightBusNotes[i])
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.scheduleWander()
            }
            scheduleBell()

        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        rampFader(masterFader, to: 0.001, duration: 1.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.killTimers()
            self?.engine.stop()
            self?.isRunning = false
        }
    }

    private func killTimers() {
        breatheTimers.forEach { $0.invalidate() }
        breatheTimers.removeAll()
        wanderTimer?.invalidate()
        bellTimer?.invalidate()
    }

    func setMasterVolume(_ volume: Float) {
        masterFader?.gain = volume * 0.75 * currentPreset.volumeScale
    }

    // MARK: - Apply preset (crossfade)

    func applyPreset(_ preset: AudioPreset) {
        let wasRunning = isRunning
        currentPreset = preset
        guard wasRunning else { return }

        // Fade out → rebuild → fade in
        rampFader(masterFader, to: 0.001, duration: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self = self else { return }
            self.killTimers()
            self.engine.stop()
            self.isRunning = false
            self.bellOscillators.removeAll()
            self.start()
        }
    }

    func fadeOut(duration: TimeInterval) {
        guard isRunning else { return }
        let steps = 60
        let interval = duration / Double(steps)
        let startGain = masterFader?.gain ?? 0.5
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                let progress = Float(i) / Float(steps)
                self?.masterFader?.gain = startGain * (1.0 - progress)
                if i == steps { self?.stop() }
            }
        }
    }

    // MARK: - Binaural breathing — pulled back, spacious

    private func scheduleBreathe(for note: BreathingNote) {
        guard isRunning else { return }

        // Low volumes — distant presence
        let vol = (0.02 + Float.random(in: 0...0.04)) * (note.frequency < 120 ? 1.2 : 1.0)
        let fadeIn = 5.0 + Double.random(in: 0...6)
        let hold = 8.0 + Double.random(in: 0...14)
        let fadeOut = 6.0 + Double.random(in: 0...8)
        let rest = 8.0 + Double.random(in: 0...14)

        rampFader(note.gainNode, to: vol, duration: Float(fadeIn))

        let t1 = Timer.scheduledTimer(withTimeInterval: fadeIn + hold, repeats: false) { [weak self] _ in
            self?.rampFader(note.gainNode, to: 0.001, duration: Float(fadeOut))
        }
        breatheTimers.append(t1)

        let t2 = Timer.scheduledTimer(withTimeInterval: fadeIn + hold + fadeOut + rest, repeats: false) { [weak self] _ in
            self?.scheduleBreathe(for: note)
        }
        breatheTimers.append(t2)
    }

    // MARK: - Wandering melody — barely perceptible

    private func scheduleWander() {
        guard isRunning else { return }

        let freqs = currentPreset.noteFrequencies
        let targetFreq = freqs.randomElement() ?? 220
        let glide = 4.0 + Double.random(in: 0...5)
        let vol: Float = 0.02 + Float.random(in: 0...0.04)
        let dur = 12.0 + Double.random(in: 0...20)

        wanderer?.$frequency.ramp(to: targetFreq, duration: Float(glide))
        if let wg = wandererGain { rampFader(wg, to: vol, duration: Float(glide)) }

        let t1 = Timer.scheduledTimer(withTimeInterval: dur, repeats: false) { [weak self] _ in
            if let wg = self?.wandererGain { self?.rampFader(wg, to: 0.001, duration: Float(glide)) }
        }
        breatheTimers.append(t1)

        let totalInterval = dur + glide * 2.0 + Double.random(in: 4...14)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: totalInterval, repeats: false) { [weak self] _ in
            self?.scheduleWander()
        }
    }

    // MARK: - Piano bells — consistent across all presets

    private func scheduleBell() {
        guard isRunning else { return }
        let interval = 4.0 + Double.random(in: 0...7)
        bellTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.playBell()
            self.scheduleBell()
        }
    }

    private func playBell() {
        let fundamental = AudioPreset.bellFrequencies.randomElement() ?? 220
        let harmonics: [(freq: Float, vol: Float)] = [
            (fundamental, 0.07), (fundamental * 2, 0.035), (fundamental * 4, 0.012)
        ]

        for h in harmonics {
            let osc = Oscillator(waveform: Table(.sine))
            osc.frequency = h.freq
            osc.amplitude = 1.0

            let gain = Fader(osc, gain: 0.001)
            bellMixer.addInput(gain)
            osc.start()
            bellOscillators.append((osc: osc, gain: gain))

            rampFader(gain, to: h.vol, duration: 0.06)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                self?.rampFader(gain, to: 0.0001, duration: 8.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) { [weak self] in
                osc.stop()
                self?.bellOscillators.removeAll { $0.osc === osc }
            }
        }
    }
}

// ═══════════════════════════════════════════
//  Single breathing note
// ═══════════════════════════════════════════

class BreathingNote {
    let frequency: Float
    let osc: Oscillator
    let gainNode: Fader

    init(frequency: Float, detuneCents: Float) {
        self.frequency = frequency
        osc = Oscillator(waveform: Table(.sine))
        osc.frequency = frequency * pow(2, detuneCents / 1200)
        osc.amplitude = 1.0
        gainNode = Fader(osc, gain: 0)
    }
}
