import Foundation
import simd

struct StrokePoint: Codable {
    var x: Float
    var y: Float
    var pressure: Float
    var altitude: Float
    var cumulDist: Float = 0  // cumulative distance along stroke (for dashed/dotted)
}

struct Stroke: Codable, Identifiable {
    let id: UUID
    var points: [StrokePoint]
    var colorR: Float
    var colorG: Float
    var colorB: Float
    var colorA: Float
    var brushSize: Float
    var mode: String // "free", "mandala", "ellipse"
    var lineStyle: String // "neon", "softGlow", "dashed", "dotted", "sketch"

    init(colorR: Float, colorG: Float, colorB: Float, colorA: Float,
         brushSize: Float, mode: DrawMode, lineStyle: LineStyle = .neon) {
        self.id = UUID()
        self.points = []
        self.colorR = colorR
        self.colorG = colorG
        self.colorB = colorB
        self.colorA = colorA
        self.brushSize = brushSize
        self.mode = mode.rawValue
        self.lineStyle = lineStyle.rawValue
    }

    /// GPU line style index matching LineStyle.gpuIndex
    var gpuLineStyle: UInt32 {
        (LineStyle(rawValue: lineStyle) ?? .neon).gpuIndex
    }
}
