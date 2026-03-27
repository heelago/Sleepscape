import Foundation

/// ViewModel exposing audio controls to UI.
@Observable
class AudioViewModel {
    let engine = SleepscapeAudioEngine()

    var isPlaying: Bool = false
    var volume: Float = 0.7

    func togglePlayback() {
        if isPlaying {
            engine.stop()
        } else {
            engine.start()
        }
        isPlaying.toggle()
    }

    func setVolume(_ value: Float) {
        volume = value
        engine.setMasterVolume(value)
    }
}
