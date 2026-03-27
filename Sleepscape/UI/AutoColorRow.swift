import SwiftUI

/// Toggle for auto-cycling through ink colors in the current palette.
struct AutoColorRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.autoColorEnabled.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.autoColorEnabled ? "arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("auto color")
                        .font(.custom("CrimsonPro-Light", size: 12))
                }
                .foregroundStyle(.white.opacity(appState.autoColorEnabled ? 0.9 : 0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.white.opacity(appState.autoColorEnabled ? 0.12 : 0))
                )
            }

            if appState.autoColorEnabled {
                Text("speed")
                    .font(.custom("CrimsonPro-ExtraLight", size: 10))
                    .foregroundStyle(.white.opacity(0.35))

                Slider(value: Binding(
                    get: { Double(appState.autoColorSpeed) },
                    set: { appState.autoColorSpeed = Float($0) }
                ), in: 0.0...1.0)
                .tint(.white.opacity(0.3))
                .frame(maxWidth: 140)

                // Preview: show all palette colors as tiny dots
                HStack(spacing: 3) {
                    ForEach(Array(appState.currentPalette.inks.enumerated()), id: \.offset) { idx, ink in
                        Circle()
                            .fill(ink)
                            .frame(width: appState.currentInkIndex == idx ? 8 : 5,
                                   height: appState.currentInkIndex == idx ? 8 : 5)
                            .opacity(appState.currentInkIndex == idx ? 1.0 : 0.5)
                    }
                }
            }

            Spacer()
        }
    }
}
