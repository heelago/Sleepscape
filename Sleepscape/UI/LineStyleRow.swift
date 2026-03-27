import SwiftUI

/// Segmented line style picker — sits near the ink dots.
struct LineStyleRow: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Text("line")
                .font(.custom("CrimsonPro-ExtraLight", size: 12))
                .foregroundStyle(.white.opacity(0.4))

            ForEach(LineStyle.allCases) { style in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.lineStyle = style
                    }
                }) {
                    Text(style.displayName)
                        .font(.custom("CrimsonPro-Light", size: 12))
                        .foregroundStyle(.white.opacity(appState.lineStyle == style ? 0.9 : 0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.white.opacity(appState.lineStyle == style ? 0.12 : 0))
                        )
                }
            }

            Spacer()
        }
    }
}
