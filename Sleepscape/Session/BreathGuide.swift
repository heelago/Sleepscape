import SwiftUI

/// Breathing guide animation — appears after 5s of inactivity.
/// Animates on a 9-second cycle matching 6 breaths/minute.
/// Full animation implementation in Phase 10.
struct BreathGuide: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius: CGFloat = 60
                let time = timeline.date.timeIntervalSinceReferenceDate
                let cycle = time.truncatingRemainder(dividingBy: 9.0) / 9.0

                // Breathing circle — scale oscillates
                let scale = 0.6 + 0.4 * sin(cycle * .pi * 2)
                let r = radius * scale

                // Draw arc
                var path = Path()
                path.addArc(center: center, radius: r,
                           startAngle: .radians(cycle * .pi * 2),
                           endAngle: .radians(cycle * .pi * 2 + .pi * 1.5),
                           clockwise: false)

                context.opacity = 0.3
                context.stroke(path, with: .color(.white), lineWidth: 1.5)

                // "breathe" text
                context.opacity = 0.25
                context.draw(
                    Text("breathe")
                        .font(.custom("CrimsonPro-ExtraLight", size: 14))
                        .foregroundColor(.white),
                    at: CGPoint(x: center.x, y: center.y + radius + 20)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
