import SwiftUI

/// Always-visible bottom grip strip: play/pause · volume · save · clear · sleep · settings.
struct GripStrip: View {
    var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Play / Pause
            Button(action: { appState.isPlaying.toggle() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // Volume icon
            Image(systemName: "speaker.wave.1.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))

            // Volume slider
            Slider(value: Binding(
                get: { Double(appState.volume) },
                set: { appState.volume = Float($0) }
            ), in: 0...1)
            .tint(.white.opacity(0.3))
            .frame(maxWidth: 140)

            Spacer()

            // Clear
            Button(action: { appState.clearRequested = true }) {
                Text("clear")
                    .font(.custom("CrimsonPro-Light", size: 13))
                    .foregroundStyle(Color(hex: "#d9768a").opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(hex: "#d9768a").opacity(0.25), lineWidth: 0.5)
                    )
            }

            // Sleep timer
            Button(action: {
                appState.showSleepMenu.toggle()
            }) {
                HStack(spacing: 4) {
                    Text("☾")
                        .font(.system(size: 14))
                    Text(sleepLabel)
                        .font(.custom("CrimsonPro-Light", size: 13))
                }
                .foregroundStyle(.white.opacity(appState.sleepTimerMinutes != nil ? 0.7 : 0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(appState.sleepTimerMinutes != nil ? 0.3 : 0.15), lineWidth: 0.5)
                )
            }
            .popover(isPresented: Binding(
                get: { appState.showSleepMenu },
                set: { appState.showSleepMenu = $0 }
            )) {
                sleepTimerPopover
            }

            // Settings gear
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(showSettings ? 0.9 : 0.5))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(showSettings ? 0.12 : 0.06))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.3), .black.opacity(0.5)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Sleep timer

    private var sleepLabel: String {
        if let mins = appState.sleepTimerMinutes {
            return "\(mins)m"
        }
        return "sleep"
    }

    private var sleepTimerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SLEEP TIMER")
                .font(.custom("CrimsonPro-Light", size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)

            Text("Sound fades to silence")
                .font(.custom("CrimsonPro-ExtraLight", size: 12))
                .foregroundStyle(.white.opacity(0.35))

            ForEach([15, 30, 60], id: \.self) { mins in
                Button(action: {
                    if appState.sleepTimerMinutes == mins {
                        // Cancel timer
                        appState.sleepTimerMinutes = nil
                        appState.sleepTimerStarted = nil
                    } else {
                        appState.sleepTimerMinutes = mins
                        appState.sleepTimerStarted = Date()
                    }
                    appState.showSleepMenu = false
                }) {
                    HStack {
                        Text("\(mins) minutes")
                            .font(.custom("CrimsonPro-Light", size: 14))
                            .foregroundStyle(.white.opacity(
                                appState.sleepTimerMinutes == mins ? 0.9 : 0.5
                            ))
                        Spacer()
                        if appState.sleepTimerMinutes == mins {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(appState.sleepTimerMinutes == mins ? 0.08 : 0.03))
                    )
                }
            }

            if appState.sleepTimerMinutes != nil {
                Button(action: {
                    appState.sleepTimerMinutes = nil
                    appState.sleepTimerStarted = nil
                    appState.showSleepMenu = false
                }) {
                    Text("cancel timer")
                        .font(.custom("CrimsonPro-ExtraLight", size: 12))
                        .foregroundStyle(Color(hex: "#d9768a").opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(Color(hex: "#0c0b14").opacity(0.95))
        .presentationCompactAdaptation(.popover)
    }
}
