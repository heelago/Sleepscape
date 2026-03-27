import SwiftUI

/// Collapsible bottom sheet with grip strip and control rows.
struct BottomSheet: View {
    var appState: AppState
    @State private var isExpanded = false
    @State private var autoCollapseTask: Task<Void, Never>?

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                // Grip strip — always visible (48pt)
                gripStrip

                // Expanded panel
                if isExpanded {
                    expandedPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea()
    }

    private var gripStrip: some View {
        HStack(spacing: 16) {
            // Play/pause
            Button(action: { appState.isPlaying.toggle() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Track name
            Text("dusk pavilion")
                .font(.custom("CrimsonPro-Light", size: 13))
                .foregroundStyle(.white.opacity(0.5))

            // Volume slider
            Slider(value: Binding(
                get: { Double(appState.volume) },
                set: { appState.volume = Float($0) }
            ), in: 0...1)
            .tint(.white.opacity(0.3))
            .frame(maxWidth: 120)

            Spacer()

            // Undo / Redo — always visible in grip strip
            Button(action: { appState.undoRequested = true }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(appState.canUndo ? 0.7 : 0.2))
            }
            .disabled(!appState.canUndo)

            Button(action: { appState.redoRequested = true }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(appState.canRedo ? 0.7 : 0.2))
            }
            .disabled(!appState.canRedo)

            // Sleep button
            Button(action: { appState.showSleepOverlay = true }) {
                Text("☾")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Chevron toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
                resetAutoCollapse()
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var expandedPanel: some View {
        VStack(spacing: 12) {
            ModeRow(appState: appState)
            if appState.drawMode == .mandala {
                SymmetryRow(appState: appState)
            }
            Divider().background(.white.opacity(0.15))
            PaletteRow(appState: appState)
            InkRow(appState: appState)
            AutoColorRow(appState: appState)
            Divider().background(.white.opacity(0.15))
            LineStyleRow(appState: appState)
            BrushRow(appState: appState)
            Divider().background(.white.opacity(0.15))
            BloomsRow(appState: appState)
            Divider().background(.white.opacity(0.15))
            presetRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var presetRow: some View {
        HStack(spacing: 12) {
            Text("frequency")
                .font(.custom("CrimsonPro-ExtraLight", size: 12))
                .foregroundStyle(.white.opacity(0.4))
            ForEach(AudioPreset.all) { preset in
                Button(action: {
                    appState.currentPreset = preset
                    resetAutoCollapse()
                }) {
                    VStack(spacing: 2) {
                        Text(preset.name)
                            .font(.custom("CrimsonPro-Light", size: 13))
                        Text(preset.description)
                            .font(.custom("CrimsonPro-ExtraLight", size: 9))
                    }
                    .foregroundStyle(.white.opacity(appState.currentPreset.id == preset.id ? 0.9 : 0.45))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(appState.currentPreset.id == preset.id ? 0.12 : 0))
                    )
                }
            }
        }
    }

    private func resetAutoCollapse() {
        autoCollapseTask?.cancel()
        autoCollapseTask = Task {
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded = false
                }
            }
        }
    }
}
