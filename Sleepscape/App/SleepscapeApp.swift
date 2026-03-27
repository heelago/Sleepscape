import SwiftUI
import AVFoundation

@main
struct SleepscapeApp: App {
    init() {
        setupAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                // Audio interrupted — handled by AudioEngine
                break
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        try? AVAudioSession.sharedInstance().setActive(true)
                    }
                }
            @unknown default:
                break
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            let hasSpeakerOnly = currentRoute.outputs.allSatisfy { $0.portType == .builtInSpeaker }
            if hasSpeakerOnly {
                // Post notification for UI to show headphone toast
                NotificationCenter.default.post(name: .headphoneWarning, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let headphoneWarning = Notification.Name("headphoneWarning")
}
