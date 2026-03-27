import SwiftUI

/// Full-screen black fade overlay. Tap to dismiss.
struct SleepOverlay: View {
    var appState: AppState
    @State private var opacity: Double = 0

    var body: some View {
        Rectangle()
            .fill(.black)
            .opacity(opacity)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    appState.showSleepOverlay = false
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 4.0)) {
                    opacity = 1
                }
            }
    }
}
