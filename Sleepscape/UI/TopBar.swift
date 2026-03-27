import SwiftUI

/// Two-row top bar overlaying the canvas with transparency.
/// Row 1: wordmark · palette chips · day/night toggle
/// Row 2: ink dots · brush size · undo/redo
struct TopBar: View {
    var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // ── Row 1: Wordmark · Palette chips · Day/Night ──
            HStack(spacing: 12) {
                // Wordmark
                Text("sleepscape")
                    .font(.custom("CormorantGaramond-LightItalic", size: 18))
                    .foregroundStyle(.white.opacity(0.22))
                    .allowsHitTesting(false)

                // Divider
                verticalDivider

                // Palette chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Palette.all) { palette in
                            paletteChip(palette)
                        }
                    }
                }

                Spacer()

                // Canvas background picker
                ZStack(alignment: .topTrailing) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.showBackgroundPicker.toggle()
                        }
                    }) {
                        Image(systemName: appState.canvasBackground.isDark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 36, height: 36)
                    }

                    if appState.showBackgroundPicker {
                        backgroundPickerPopover
                            .offset(y: 40)
                    }
                }
                .zIndex(100)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)

            // ── Row 2: Ink dots · Brush size · Undo/Redo ──
            HStack(spacing: 10) {
                // Ink color dots
                HStack(spacing: 6) {
                    ForEach(0..<appState.currentPalette.inks.count, id: \.self) { i in
                        Button(action: { appState.currentInkIndex = i }) {
                            Circle()
                                .fill(appState.currentPalette.inks[i])
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(appState.currentInkIndex == i ? 0.8 : 0),
                                                      lineWidth: 1.5)
                                )
                        }
                    }
                }

                verticalDivider

                // Brush size dropdown (like Word line-width picker)
                ZStack(alignment: .top) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.showBrushPicker.toggle()
                        }
                    }) {
                        HStack(spacing: 5) {
                            // Preview line at current weight
                            RoundedRectangle(cornerRadius: CGFloat(appState.brushSize * 0.5))
                                .fill(.white.opacity(0.6))
                                .frame(width: 22, height: max(1.5, CGFloat(appState.brushSize * 1.2)))

                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.white.opacity(appState.showBrushPicker ? 0.1 : 0.04))
                        )
                    }

                    if appState.showBrushPicker {
                        brushPickerDropdown
                            .offset(y: 34)
                    }
                }
                .zIndex(99)

                Spacer()

                // Undo / Redo
                HStack(spacing: 12) {
                    Button(action: { appState.undoRequested = true }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(appState.canUndo ? 0.6 : 0.15))
                    }
                    .disabled(!appState.canUndo)

                    Button(action: { appState.redoRequested = true }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(appState.canRedo ? 0.6 : 0.15))
                    }
                    .disabled(!appState.canRedo)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.3), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Palette chip

    private func paletteChip(_ palette: Palette) -> some View {
        let isSelected = appState.currentPalette.id == palette.id

        return Button(action: {
            appState.currentPalette = palette
            appState.currentInkIndex = min(appState.currentInkIndex, palette.inks.count - 1)
        }) {
            HStack(spacing: 4) {
                // 3 preview dots
                ForEach(0..<min(3, palette.inks.count), id: \.self) { i in
                    Circle()
                        .fill(palette.inks[i])
                        .frame(width: 6, height: 6)
                }
                Text(palette.name)
                    .font(.custom("CrimsonPro-Light", size: 11))
                    .foregroundStyle(.white.opacity(isSelected ? 0.9 : 0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.12 : 0.04))
                    .strokeBorder(.white.opacity(isSelected ? 0.2 : 0), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Brush size dropdown

    private var brushPickerDropdown: some View {
        VStack(spacing: 2) {
            ForEach(brushPresets, id: \.size) { preset in
                Button(action: {
                    appState.brushSize = preset.size
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.showBrushPicker = false
                    }
                }) {
                    HStack(spacing: 10) {
                        // Line preview at this weight
                        RoundedRectangle(cornerRadius: CGFloat(preset.size * 0.5))
                            .fill(.white.opacity(appState.brushSize == preset.size ? 0.8 : 0.5))
                            .frame(width: 30, height: max(1, CGFloat(preset.size * 1.2)))

                        Text(preset.label)
                            .font(.custom("CrimsonPro-ExtraLight", size: 11))
                            .foregroundStyle(.white.opacity(appState.brushSize == preset.size ? 0.8 : 0.4))

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.white.opacity(appState.brushSize == preset.size ? 0.08 : 0))
                    )
                }
            }
        }
        .padding(6)
        .frame(width: 130)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#0c0b14").opacity(0.95))
                .shadow(color: .black.opacity(0.4), radius: 12)
        )
    }

    private var brushPresets: [(size: Float, label: String)] {
        [
            (0.5,  "hairline"),
            (1.0,  "fine"),
            (1.5,  "light"),
            (2.5,  "medium"),
            (4.0,  "broad"),
            (6.0,  "heavy"),
            (8.0,  "marker"),
        ]
    }

    // MARK: - Background picker popover

    private var backgroundPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CANVAS")
                .font(.custom("CrimsonPro-Light", size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                ForEach(CanvasBackground.allCases) { bg in
                    Button(action: {
                        appState.canvasBackground = bg
                        appState.showBackgroundPicker = false
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(bg.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            appState.canvasBackground == bg
                                                ? .white.opacity(0.7)
                                                : .white.opacity(0.15),
                                            lineWidth: appState.canvasBackground == bg ? 2 : 0.5
                                        )
                                )
                            Text(bg.rawValue)
                                .font(.custom("CrimsonPro-ExtraLight", size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 220)
        .background(Color(hex: "#0c0b14").opacity(0.95))
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Divider

    private var verticalDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 20)
    }
}
