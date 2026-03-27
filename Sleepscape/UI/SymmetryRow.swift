import SwiftUI

struct SymmetryRow: View {
    var appState: AppState
    private let folds = [4, 6, 8, 12, 16]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(folds, id: \.self) { fold in
                Button(action: { appState.symmetry = fold }) {
                    Text("\(fold)")
                        .font(.custom("CrimsonPro-Light", size: 13))
                        .foregroundStyle(appState.symmetry == fold ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            appState.symmetry == fold
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
