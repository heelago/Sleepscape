import SwiftUI

/// Half-screen settings drawer with 2×2 card grid.
/// Slides up from bottom. Closes on tap outside, drag down, or 10s idle.
struct SettingsSheet: View {
    var appState: AppState
    @Binding var isPresented: Bool
    @State private var autoCloseTask: Task<Void, Never>?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim — tap to dismiss
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Sheet
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                // 2×2 grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    canvasCard
                    strokeCard
                    effectsCard
                    breathingCard
                    audioCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "#0c0b14").opacity(0.95))
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear { resetAutoClose() }
    }

    // MARK: - Canvas Card

    private var canvasCard: some View {
        settingsCard(title: "CANVAS") {
            VStack(alignment: .leading, spacing: 10) {
                // Mode
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("mode")
                    HStack(spacing: 6) {
                        ForEach(DrawMode.allCases) { mode in
                            pill(mode.displayName, isSelected: appState.drawMode == mode) {
                                appState.drawMode = mode
                                resetAutoClose()
                            }
                        }
                    }
                }

                // Fold (mandala only)
                if appState.drawMode == .mandala {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("fold")
                        HStack(spacing: 6) {
                            ForEach([4, 6, 8, 12, 16], id: \.self) { n in
                                pill("\(n)", isSelected: appState.symmetry == n) {
                                    appState.symmetry = n
                                    resetAutoClose()
                                }
                            }
                        }
                    }

                    // Mandala size — removed (full canvas always)
                }
            }
        }
    }

    // MARK: - Stroke Card

    private var strokeCard: some View {
        settingsCard(title: "STROKE") {
            VStack(alignment: .leading, spacing: 10) {
                // Line style
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("style")
                    HStack(spacing: 5) {
                        ForEach(LineStyle.allCases) { style in
                            pill(shortName(style), isSelected: appState.lineStyle == style) {
                                appState.lineStyle = style
                                resetAutoClose()
                            }
                        }
                    }
                }

                // Auto color
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        sectionLabel("auto color")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.autoColorEnabled },
                            set: {
                                appState.autoColorEnabled = $0
                                resetAutoClose()
                            }
                        ))
                        .labelsHidden()
                        .tint(.white.opacity(0.3))
                        .scaleEffect(0.75)
                    }

                    if appState.autoColorEnabled {
                        HStack {
                            sectionLabel("interval · \(Int(4 + appState.autoColorSpeed * 26))s")
                            Spacer()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(appState.autoColorSpeed) },
                                set: {
                                    appState.autoColorSpeed = Float($0)
                                    resetAutoClose()
                                }
                            ),
                            in: 0...1
                        )
                        .tint(.white.opacity(0.3))
                    }
                }

                // Path smoothing toggle
                HStack {
                    sectionLabel("path smoothing")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.pathSmoothingEnabled },
                        set: {
                            appState.pathSmoothingEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

                // Slow ink toggle
                HStack {
                    sectionLabel("slow ink")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.slowInkEnabled },
                        set: {
                            appState.slowInkEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

                // Pace slider
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("pace")
                    HStack(spacing: 6) {
                        Text("free")
                            .font(.custom("CrimsonPro-ExtraLight", size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                        Slider(
                            value: Binding(
                                get: { Double(appState.paceThrottle) },
                                set: {
                                    appState.paceThrottle = Float($0)
                                    resetAutoClose()
                                }
                            ),
                            in: 0...120
                        )
                        .tint(.white.opacity(0.3))
                        Text("slow")
                            .font(.custom("CrimsonPro-ExtraLight", size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Effects Card

    private var effectsCard: some View {
        settingsCard(title: "EFFECTS") {
            VStack(alignment: .leading, spacing: 10) {
                // Ambient blooms
                HStack {
                    sectionLabel("ambient blooms")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.bloomsEnabled },
                        set: {
                            appState.bloomsEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

                if appState.bloomsEnabled {
                    Slider(
                        value: Binding(
                            get: { Double(appState.bloomIntensity) },
                            set: {
                                appState.bloomIntensity = Float($0)
                                resetAutoClose()
                            }
                        ),
                        in: 0.1...1.0
                    )
                    .tint(.white.opacity(0.3))
                }

                // Sparkles toggle
                HStack {
                    sectionLabel("sparkles")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.sparklesEnabled },
                        set: {
                            appState.sparklesEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

                // Ripples toggle
                HStack {
                    sectionLabel("ripples")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.ripplesEnabled },
                        set: {
                            appState.ripplesEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

            }
        }
    }

    // MARK: - Breathing Card

    private var breathingCard: some View {
        settingsCard(title: "BREATHING") {
            VStack(alignment: .leading, spacing: 10) {
                // Enable toggle
                HStack {
                    sectionLabel("breath pulse")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.breathPulseEnabled },
                        set: {
                            appState.breathPulseEnabled = $0
                            resetAutoClose()
                        }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.75)
                }

                if appState.breathPulseEnabled {
                    // Preset pills
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("pattern")
                        // Two rows of pills
                        HStack(spacing: 5) {
                            ForEach([BreathingPreset.fourSevenEight, .box, .cardiac], id: \.id) { preset in
                                pill(preset.rawValue, isSelected: appState.breathingPreset == preset) {
                                    appState.breathingPreset = preset
                                    resetAutoClose()
                                }
                            }
                        }
                        HStack(spacing: 5) {
                            ForEach([BreathingPreset.resonance, .gentle, .custom], id: \.id) { preset in
                                pill(preset.rawValue, isSelected: appState.breathingPreset == preset) {
                                    appState.breathingPreset = preset
                                    resetAutoClose()
                                }
                            }
                        }
                    }

                    // Description — more prominent
                    Text(appState.breathingPreset.subtitle)
                        .font(.custom("CrimsonPro-Light", size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 2)

                    // How it works explanation
                    let p = appState.breathPhases
                    VStack(alignment: .leading, spacing: 3) {
                        breathPhaseLabel("inhale", seconds: p.inhale, note: "ring expands")
                        if p.hold > 0 {
                            breathPhaseLabel("hold", seconds: p.hold, note: "ring flashes softly")
                        }
                        breathPhaseLabel("exhale", seconds: p.exhale, note: "ring contracts")
                        if p.hold2 > 0 {
                            breathPhaseLabel("hold", seconds: p.hold2, note: "ring flashes softly")
                        }
                    }
                    .padding(.vertical, 2)

                    // Custom sliders
                    if appState.breathingPreset == .custom {
                        VStack(spacing: 6) {
                            breathSlider("inhale", value: Binding(
                                get: { appState.customInhale }, set: { appState.customInhale = $0 }
                            ), range: 1...12)
                            breathSlider("hold", value: Binding(
                                get: { appState.customHold }, set: { appState.customHold = $0 }
                            ), range: 0...12)
                            breathSlider("exhale", value: Binding(
                                get: { appState.customExhale }, set: { appState.customExhale = $0 }
                            ), range: 1...12)
                            breathSlider("hold₂", value: Binding(
                                get: { appState.customHold2 }, set: { appState.customHold2 = $0 }
                            ), range: 0...12)
                        }
                    }
                }
            }
        }
    }

    private func breathPhaseLabel(_ phase: String, seconds: Float, note: String) -> some View {
        HStack(spacing: 6) {
            Text(phase)
                .font(.custom("CrimsonPro-Light", size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 44, alignment: .leading)
            Text("\(Int(seconds))s")
                .font(.custom("CrimsonPro-Light", size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .monospacedDigit()
                .frame(width: 22)
            Text("· \(note)")
                .font(.custom("CrimsonPro-ExtraLight", size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func breathSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.custom("CrimsonPro-ExtraLight", size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 40, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: {
                        value.wrappedValue = Float($0)
                        resetAutoClose()
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(.white.opacity(0.3))
            Text("\(Int(value.wrappedValue))s")
                .font(.custom("CrimsonPro-Light", size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .monospacedDigit()
                .frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: - Audio Card

    private var audioCard: some View {
        settingsCard(title: "AUDIO") {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("frequency")

                ForEach(AudioPreset.all) { preset in
                    Button(action: {
                        appState.currentPreset = preset
                        resetAutoClose()
                    }) {
                        HStack {
                            Text(preset.name)
                                .font(.custom("CrimsonPro-Light", size: 14))
                                .foregroundStyle(.white.opacity(
                                    appState.currentPreset.id == preset.id ? 0.9 : 0.45))
                            Spacer()
                            Text(preset.description)
                                .font(.custom("CrimsonPro-ExtraLight", size: 11))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white.opacity(
                                    appState.currentPreset.id == preset.id ? 0.08 : 0.02))
                                .strokeBorder(.white.opacity(
                                    appState.currentPreset.id == preset.id ? 0.15 : 0.05),
                                              lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("CrimsonPro-Light", size: 11))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func pill(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.custom("CrimsonPro-Light", size: 12))
                .foregroundStyle(.white.opacity(isSelected ? 0.9 : 0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(isSelected ? 0.10 : 0.03))
                        .strokeBorder(.white.opacity(isSelected ? 0.18 : 0), lineWidth: 0.5)
                )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("CrimsonPro-ExtraLight", size: 12))
            .foregroundStyle(.white.opacity(0.45))
    }

    private func shortName(_ style: LineStyle) -> String {
        switch style {
        case .neon: return "neon"
        case .softGlow: return "soft"
        case .dashed: return "dash"
        case .dotted: return "dot"
        case .sketch: return "sketch"
        }
    }

    private func dismiss() {
        autoCloseTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset = 0
            isPresented = false
        }
    }

    private func resetAutoClose() {
        autoCloseTask?.cancel()
        autoCloseTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }
}
