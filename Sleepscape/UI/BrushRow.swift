import SwiftUI

struct BrushRow: View {
    var appState: AppState

    // Exponential mapping: slider 0...1 → brush 0.5...8.0
    // Lower half (0–0.5) covers 0.5–2.0, upper half covers 2.0–8.0
    private var sliderValue: Double {
        // Inverse: t = log(brushSize / 0.5) / log(16)
        Double(log(appState.brushSize / 0.5) / log(16.0))
    }

    private func brushFromSlider(_ t: Double) -> Float {
        // 0.5 * 16^t  →  t=0 → 0.5, t=0.5 → 2.0, t=1.0 → 8.0
        0.5 * pow(16.0, Float(t))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("brush")
                .font(.custom("CrimsonPro-ExtraLight", size: 12))
                .foregroundStyle(.white.opacity(0.4))

            // Minus button
            Button(action: {
                appState.brushSize = max(0.5, appState.brushSize - 0.25)
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // Exponential size slider
            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { appState.brushSize = brushFromSlider($0) }
                ),
                in: 0...1
            )
            .tint(.white.opacity(0.3))
            .frame(maxWidth: 200)

            // Plus button
            Button(action: {
                appState.brushSize = min(8.0, appState.brushSize + 0.25)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // Size preview dot
            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: max(2, CGFloat(appState.brushSize)),
                       height: max(2, CGFloat(appState.brushSize)))

            Spacer()
        }
    }
}
