import Foundation

/// Manages session phases and wind-down automation.
/// Full implementation in Phase 9.
@Observable
class SessionManager {
    enum Phase {
        case idle
        case drawing
        case windDown
        case sleeping
    }

    var phase: Phase = .idle
    var sessionDuration: TimeInterval = 0
    var windDownDuration: TimeInterval = 300 // 5 min default
    var showBreathGuide: Bool = false

    private var sessionTimer: Timer?
    private var inactivityTimer: Timer?

    func onUserInteraction() {
        resetInactivityTimer()
        if phase == .idle {
            beginSession()
        }
    }

    private func beginSession() {
        phase = .drawing
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.sessionDuration += 1
        }
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        showBreathGuide = false
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.showBreathGuide = true
        }
    }

    func beginWindDown() {
        phase = .windDown
        // Phase 9: Gradual reduction of brightness, volume, glow, ripple speed
    }

    func endSession() {
        phase = .sleeping
        sessionTimer?.invalidate()
        inactivityTimer?.invalidate()
    }
}
