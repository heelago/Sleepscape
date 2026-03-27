import SwiftUI

struct ModeRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ForEach(DrawMode.allCases) { mode in
                Button(action: { appState.drawMode = mode }) {
                    Text(mode.displayName)
                        .font(.custom("CrimsonPro-Light", size: 13))
                        .foregroundStyle(appState.drawMode == mode ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            appState.drawMode == mode
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
