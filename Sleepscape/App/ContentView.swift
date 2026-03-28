import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var audioEngine = SleepscapeAudioEngine()
    @State private var showSettings = false

    // Sleep timer: gradually fade audio volume
    @State private var sleepTimer: Timer? = nil

    var body: some View {
        ZStack {
            // Full-bleed canvas
            MetalCanvasView(appState: appState)
                .ignoresSafeArea()

            // Top bar overlay (transparent gradient)
            VStack {
                TopBar(appState: appState)
                    .padding(.top, 4)
                Spacer()
            }
            .ignoresSafeArea(edges: .horizontal)

            // Breath guide — always visible while enabled
            if appState.breathPulseEnabled {
                BreathGuide(
                    phases: appState.breathPhases,
                    showPhaseText: appState.breathPhaseText,
                    opacity: appState.breathPulseOpacity
                )
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            // Bottom grip strip
            VStack {
                Spacer()
                GripStrip(appState: appState, showSettings: $showSettings)
            }
            .ignoresSafeArea(edges: .horizontal)

            // Settings sheet (slides up from bottom)
            if showSettings {
                SettingsSheet(appState: appState, isPresented: $showSettings)
                    .transition(.opacity)
            }

            // Sleep overlay
            if appState.showSleepOverlay {
                SleepOverlay(appState: appState)
            }
        }
        .statusBarHidden()
        .onChange(of: appState.isPlaying) { _, isPlaying in
            if isPlaying {
                audioEngine.start()
            } else {
                audioEngine.stop()
            }
        }
        .onChange(of: appState.volume) { _, volume in
            // Only apply manual volume if no sleep timer is fading
            if appState.sleepTimerMinutes == nil {
                audioEngine.setMasterVolume(volume)
            }
        }
        .onChange(of: appState.currentPreset) { _, preset in
            audioEngine.applyPreset(preset)
        }
        .onChange(of: appState.sleepTimerMinutes) { _, mins in
            // Start or cancel sleep timer
            sleepTimer?.invalidate()
            sleepTimer = nil

            guard let mins = mins, let _ = appState.sleepTimerStarted else {
                // Timer cancelled — restore user volume
                audioEngine.setMasterVolume(appState.volume)
                return
            }

            // Tick every 10 seconds, gradually reduce volume
            let totalSeconds = Double(mins * 60)
            sleepTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
                guard let started = appState.sleepTimerStarted else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(started)
                let progress = min(elapsed / totalSeconds, 1.0)
                let fadeVolume = appState.volume * Float(1.0 - progress)
                audioEngine.setMasterVolume(fadeVolume)

                if progress >= 1.0 {
                    // Timer complete — stop audio
                    timer.invalidate()
                    audioEngine.stop()
                    appState.isPlaying = false
                    appState.sleepTimerMinutes = nil
                    appState.sleepTimerStarted = nil
                }
            }
        }
    }
}
