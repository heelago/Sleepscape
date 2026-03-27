import Foundation

/// Line rendering style — controls how strokes appear on the Metal canvas.
enum LineStyle: String, CaseIterable, Identifiable, Codable {
    case neon       // Default: 3-pass glow, smooth bright core
    case softGlow   // Wider diffuse glow, gentler alpha
    case dashed     // Spaced dashes along the stroke
    case dotted     // Isolated dots along the stroke path
    case sketch     // Textured, slightly rough edges

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neon:     return "neon"
        case .softGlow: return "soft glow"
        case .dashed:   return "dashed"
        case .dotted:   return "dotted"
        case .sketch:   return "sketch"
        }
    }

    /// GPU identifier: passed to shaders as uint
    var gpuIndex: UInt32 {
        switch self {
        case .neon:     return 0
        case .softGlow: return 1
        case .dashed:   return 2
        case .dotted:   return 3
        case .sketch:   return 4
        }
    }
}
