import SwiftUI

/// Breathing guide overlay — shows phase text (inhale/hold/exhale) centered on screen.
/// Always visible while breath pulse is enabled. The WebGL/Metal ring handles the
/// visual animation; this view only renders the text label.
struct BreathGuide: View {
    let phases: (inhale: Float, hold: Float, exhale: Float, hold2: Float)
    let showPhaseText: Bool
    let opacity: Float

    @State private var currentLabel: String = "breathe"
    @State private var timer: Timer?

    var body: some View {
        Text(currentLabel)
            .font(.custom("CrimsonPro-ExtraLight", size: 14))
            .foregroundColor(.white.opacity(Double(0.3 + opacity * 0.5)))
            .tracking(3)
            .allowsHitTesting(false)
            .onAppear { startUpdating() }
            .onDisappear { timer?.invalidate() }
            .onChange(of: showPhaseText) { startUpdating() }
    }

    private func startUpdating() {
        timer?.invalidate()
        if !showPhaseText {
            currentLabel = "breathe"
            return
        }
        let cycle = TimeInterval(phases.inhale + phases.hold + phases.exhale + phases.hold2)
        guard cycle > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let t = Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            let inhEnd = TimeInterval(phases.inhale)
            let holdEnd = inhEnd + TimeInterval(phases.hold)
            let exhEnd = holdEnd + TimeInterval(phases.exhale)

            if t < inhEnd {
                currentLabel = "inhale"
            } else if t < holdEnd {
                currentLabel = "hold"
            } else if t < exhEnd {
                currentLabel = "exhale"
            } else {
                currentLabel = "hold"
            }
        }
    }
}
