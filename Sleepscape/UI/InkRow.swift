import SwiftUI

struct InkRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(appState.currentPalette.inks.enumerated()), id: \.offset) { index, ink in
                Button(action: { appState.currentInkIndex = index }) {
                    Circle()
                        .fill(ink)
                        .frame(width: appState.currentInkIndex == index ? 22 : 16,
                               height: appState.currentInkIndex == index ? 22 : 16)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(appState.currentInkIndex == index ? 0.6 : 0), lineWidth: 1.5)
                        )
                }
            }

            Spacer()

            // Clear button
            Button(action: {
                appState.clearRequested = true
            }) {
                Text("clear")
                    .font(.custom("CrimsonPro-Light", size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
    }
}
