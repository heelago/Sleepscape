import SwiftUI
import UIKit

// MARK: - Canvas Backgrounds

enum CanvasBackground: String, CaseIterable, Identifiable {
    case midnight = "Midnight"
    case deepNavy = "Deep Navy"
    case charcoal = "Charcoal"
    case warmBlack = "Warm Black"
    case softCream = "Soft Cream"
    case parchment = "Parchment"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .midnight:   return Color(hex: "#04030a")
        case .deepNavy:   return Color(hex: "#0a0e1a")
        case .charcoal:   return Color(hex: "#1a1a1e")
        case .warmBlack:  return Color(hex: "#0f0c08")
        case .softCream:  return Color(hex: "#c8b99a")
        case .parchment:  return Color(hex: "#a89880")
        }
    }

    var isDark: Bool {
        switch self {
        case .softCream, .parchment: return false
        default: return true
        }
    }
}

// MARK: - Breathing Presets

enum BreathingPreset: String, CaseIterable, Identifiable {
    case fourSevenEight = "4-7-8"
    case box = "Box"
    case cardiac = "Cardiac"
    case resonance = "Resonance"
    case gentle = "Gentle"
    case custom = "Custom"

    var id: String { rawValue }

    var phases: (inhale: Float, hold: Float, exhale: Float, hold2: Float) {
        switch self {
        case .fourSevenEight: return (4, 7, 8, 0)
        case .box:            return (4, 4, 4, 4)
        case .cardiac:        return (4, 0, 6, 0)
        case .resonance:      return (6, 0, 6, 0)
        case .gentle:         return (2, 1, 4, 1)
        case .custom:         return (4, 2, 6, 0)
        }
    }

    var subtitle: String {
        switch self {
        case .fourSevenEight: return "for sleep onset"
        case .box:            return "grounding"
        case .cardiac:        return "for anxiety"
        case .resonance:      return "natural rhythm"
        case .gentle:         return "beginner"
        case .custom:         return "user-set"
        }
    }
}

@Observable
class AppState {
    // Drawing
    var drawMode: DrawMode = .mandala
    var symmetry: Int = 8
    var brushSize: Float = 0.5
    var currentPalette: Palette = Palette.all[0]
    var currentInkIndex: Int = 0
    var lineStyle: LineStyle = .neon

    // Effects
    var sparklesEnabled: Bool = true
    var ripplesEnabled: Bool = true

    // Ambient blooms
    var bloomsEnabled: Bool = true
    var bloomSpawnRate: Float = 0.5
    var bloomIntensity: Float = 0.6

    // Glow & brightness (persisted via UserDefaults)
    var glowIntensity: Float {
        get {
            let v = UserDefaults.standard.object(forKey: "glowIntensity") as? Float
            return v ?? 0.65
        }
        set { UserDefaults.standard.set(newValue, forKey: "glowIntensity") }
    }
    var brightnessCap: Float {
        get {
            let v = UserDefaults.standard.object(forKey: "brightnessCap") as? Float
            return v ?? 0.70
        }
        set { UserDefaults.standard.set(newValue, forKey: "brightnessCap") }
    }

    // Breath pulse + breathing pattern
    var breathPulseEnabled: Bool = false
    var breathingPreset: BreathingPreset = .resonance
    var customInhale: Float = 4
    var customHold: Float = 2
    var customExhale: Float = 6
    var customHold2: Float = 0

    // Stroke behaviour (persisted via UserDefaults)
    var pathSmoothingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pathSmoothing") }
        set { UserDefaults.standard.set(newValue, forKey: "pathSmoothing") }
    }
    var slowInkEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "slowInk") }
        set { UserDefaults.standard.set(newValue, forKey: "slowInk") }
    }
    var paceThrottle: Float {
        get { UserDefaults.standard.float(forKey: "paceThrottle") }
        set { UserDefaults.standard.set(newValue, forKey: "paceThrottle") }
    }

    // Auto color cycling
    var autoColorEnabled: Bool = true
    var autoColorSpeed: Float = 0.077    // maps to ~6s interval (4 + 0.077*26 ≈ 6)

    // Audio
    var isPlaying: Bool = false
    var volume: Float = 0.7
    var currentPreset: AudioPreset = .delta

    // Canvas background
    var canvasBackground: CanvasBackground = .midnight
    var showBackgroundPicker: Bool = false
    var showBrushPicker: Bool = false

    // Sleep timer
    var showSleepMenu: Bool = false
    var sleepTimerMinutes: Int? = nil  // nil = no timer, 15/30/60
    var sleepTimerStarted: Date? = nil

    // Session
    var showBreathGuide: Bool = false
    var showSleepOverlay: Bool = false
    var showSettings: Bool = false
    var showHeadphoneWarning: Bool = false
    var clearRequested: Bool = false
    var undoRequested: Bool = false
    var redoRequested: Bool = false
    var canUndo: Bool = false
    var canRedo: Bool = false

    // MARK: - Computed

    var breathPhases: (inhale: Float, hold: Float, exhale: Float, hold2: Float) {
        if breathingPreset == .custom {
            return (customInhale, customHold, customExhale, customHold2)
        }
        return breathingPreset.phases
    }

    var breathCycleDuration: Float {
        let p = breathPhases
        return p.inhale + p.hold + p.exhale + p.hold2
    }

    var currentInk: Color {
        currentPalette.inks[currentInkIndex]
    }

    var currentInkSIMD: SIMD4<Float> {
        let color = UIColor(currentInk)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    var backgroundColor: Color {
        canvasBackground.color
    }

    func nextSymmetry() {
        let options = [4, 6, 8, 12, 16]
        guard let idx = options.firstIndex(of: symmetry) else {
            symmetry = 8
            return
        }
        symmetry = options[(idx + 1) % options.count]
    }

    func nextPalette() {
        guard let idx = Palette.all.firstIndex(where: { $0.id == currentPalette.id }) else { return }
        currentPalette = Palette.all[(idx + 1) % Palette.all.count]
        currentInkIndex = min(currentInkIndex, currentPalette.inks.count - 1)
    }
}
