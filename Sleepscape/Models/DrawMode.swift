import Foundation

enum DrawMode: String, CaseIterable, Identifiable {
    case free
    case mandala
    case ellipse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "free"
        case .mandala: return "❋ mandala"
        case .ellipse: return "◯ ellipse"
        }
    }
}
