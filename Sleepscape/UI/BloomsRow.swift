import SwiftUI

/// Toggle for ambient blooms + intensity slider.
struct BloomsRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.bloomsEnabled.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.bloomsEnabled ? "sparkles" : "sparkle")
                        .font(.system(size: 11))
                    Text("blooms")
                        .font(.custom("CrimsonPro-Light", size: 12))
                }
                .foregroundStyle(.white.opacity(appState.bloomsEnabled ? 0.9 : 0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.white.opacity(appState.bloomsEnabled ? 0.12 : 0))
                )
            }

            // Intensity slider (only visible when enabled)
            if appState.bloomsEnabled {
                Text("intensity")
                    .font(.custom("CrimsonPro-ExtraLight", size: 10))
                    .foregroundStyle(.white.opacity(0.35))

                Slider(value: Binding(
                    get: { Double(appState.bloomIntensity) },
                    set: { appState.bloomIntensity = Float($0) }
                ), in: 0.1...1.0)
                .tint(.white.opacity(0.3))
                .frame(maxWidth: 120)

                Text("rate")
                    .font(.custom("CrimsonPro-ExtraLight", size: 10))
                    .foregroundStyle(.white.opacity(0.35))

                Slider(value: Binding(
                    get: { Double(appState.bloomSpawnRate) },
                    set: { appState.bloomSpawnRate = Float($0) }
                ), in: 0.1...1.0)
                .tint(.white.opacity(0.3))
                .frame(maxWidth: 100)
            }

            Spacer()
        }
    }
}
