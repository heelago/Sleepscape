import SwiftUI

struct PaletteRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Palette.all) { palette in
                Button(action: {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        appState.currentPalette = palette
                        appState.currentInkIndex = 0
                    }
                }) {
                    Text(palette.name)
                        .font(.custom("CrimsonPro-Light", size: 13))
                        .foregroundStyle(
                            appState.currentPalette.id == palette.id
                                ? .white
                                : .white.opacity(0.4)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            appState.currentPalette.id == palette.id
                                ? .white.opacity(0.12)
                                : .clear
                        )
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
    }
}
