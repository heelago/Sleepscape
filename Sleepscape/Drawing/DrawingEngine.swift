import Foundation
import Metal
import simd

/// Core drawing engine: manages strokes, ripples, ambient blooms,
/// sparkle particles, and undo/redo history.
class DrawingEngine {
    private(set) var strokes: [Stroke] = []
    private(set) var currentStroke: Stroke?
    private(set) var predictedPoints: [CGPoint] = []

    // Undo/Redo stack
    private var undoneStrokes: [Stroke] = []
    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !undoneStrokes.isEmpty }

    // Smoothing state (exponential moving average — more fluid)
    private var sx: Float = 0
    private var sy: Float = 0
    private var isFirstPoint = true
    private let smoothFactor: Float = 0.08       // finger: lower = smoother, more meditative
    private let pencilSmoothFactor: Float = 0.35  // pencil: light easing, preserves accuracy
    private let slowInkFactor: Float = 0.06       // slow ink: very heavy smoothing
    var slowInkEnabled: Bool = false

    // Cumulative distance tracking
    private var lastX: Float = 0
    private var lastY: Float = 0
    private var cumulativeDistance: Float = 0

    // MARK: - Ripple state

    struct Ripple {
        var center: SIMD2<Float>
        var radius: Float
        var maxRadius: Float
        var alpha: Float
        var speed: Float
        var color: SIMD4<Float>
        var rings: Int
    }
    private(set) var ripples: [Ripple] = []
    private var lastRippleTime: CFTimeInterval = 0

    // MARK: - Ambient Bloom state

    struct AmbientBloom {
        var center: SIMD2<Float>
        var radius: Float
        var maxRadius: Float
        var alpha: Float
        var targetAlpha: Float
        var color: SIMD4<Float>
        var phase: BloomPhase
        var phaseTimer: Float  // frames remaining in current phase
    }
    enum BloomPhase { case fadeIn, hold, expand, fadeOut }

    private(set) var ambientBlooms: [AmbientBloom] = []
    private var lastBloomSpawnTime: CFTimeInterval = 0
    var bloomsEnabled: Bool = true
    var bloomSpawnRate: Float = 0.5   // 0→1
    var bloomIntensity: Float = 0.6   // 0→1

    // MARK: - Sparkle particle state

    struct Sparkle {
        var position: SIMD2<Float>
        var alpha: Float
        var size: Float
        var color: SIMD4<Float>
        var life: Float   // frames remaining
    }
    private(set) var sparkles: [Sparkle] = []

    // MARK: - Touch handling

    func beginStroke(at point: CGPoint, pressure: Float, altitude: Float,
                     color: SIMD4<Float>, brushSize: Float, mode: DrawMode,
                     lineStyle: LineStyle = .neon) {
        isFirstPoint = true
        sx = Float(point.x)
        sy = Float(point.y)
        lastX = sx
        lastY = sy
        cumulativeDistance = 0

        var stroke = Stroke(
            colorR: color.x, colorG: color.y, colorB: color.z, colorA: color.w,
            brushSize: brushSize, mode: mode, lineStyle: lineStyle
        )
        stroke.points.append(StrokePoint(
            x: Float(point.x), y: Float(point.y),
            pressure: pressure, altitude: altitude, cumulDist: 0
        ))
        currentStroke = stroke

        // Clear redo stack on new stroke
        undoneStrokes.removeAll()
    }

    func addPoint(_ point: CGPoint, pressure: Float, altitude: Float,
                  isPencil: Bool, canvasSize: CGSize? = nil) {
        guard currentStroke != nil else { return }

        var px = Float(point.x)
        var py = Float(point.y)

        // Apply smoothing: slow ink overrides, otherwise finger/pencil defaults
        let factor = slowInkEnabled ? slowInkFactor : (isPencil ? pencilSmoothFactor : smoothFactor)
        if isFirstPoint {
            sx = px
            sy = py
            isFirstPoint = false
        } else {
            sx += (px - sx) * factor
            sy += (py - sy) * factor
            px = sx
            py = sy
        }

        // Update cumulative distance
        let dx = px - lastX
        let dy = py - lastY
        let segLen = sqrt(dx * dx + dy * dy)
        cumulativeDistance += segLen
        lastX = px
        lastY = py

        currentStroke?.points.append(StrokePoint(
            x: px, y: py,
            pressure: pressure, altitude: altitude,
            cumulDist: cumulativeDistance
        ))

        // Spawn sparkle particles along pencil strokes
        if isPencil && segLen > 2.0 && sparklesEnabled {
            spawnSparkle(at: SIMD2<Float>(px, py),
                        color: SIMD4<Float>(currentStroke!.colorR,
                                            currentStroke!.colorG,
                                            currentStroke!.colorB, 1.0))
        }
    }

    func setPredicted(_ points: [CGPoint]) {
        predictedPoints = points
    }

    var pathSmoothingEnabled: Bool = false
    var sparklesEnabled: Bool = true

    func endStroke() {
        if var stroke = currentStroke, !stroke.points.isEmpty {
            if pathSmoothingEnabled && stroke.points.count >= 3 {
                stroke.points = chaikinSmooth(stroke.points, iterations: 5)
                // Cap at 500 points to prevent memory issues on long strokes
                if stroke.points.count > 500 {
                    stroke.points = downsample(stroke.points, to: 500)
                }
            }
            strokes.append(stroke)
        }
        currentStroke = nil
        predictedPoints = []
    }

    /// Uniform stride downsample — keeps first and last, evenly samples the rest.
    private func downsample(_ points: [StrokePoint], to count: Int) -> [StrokePoint] {
        guard points.count > count, count >= 2 else { return points }
        var result = [StrokePoint]()
        let stride = Float(points.count - 1) / Float(count - 1)
        for i in 0..<count {
            let idx = min(Int(Float(i) * stride), points.count - 1)
            result.append(points[idx])
        }
        return result
    }

    // MARK: - Chaikin curve refinement

    /// Runs Chaikin's corner-cutting algorithm to produce smooth bezier-like curves.
    private func chaikinSmooth(_ points: [StrokePoint], iterations: Int) -> [StrokePoint] {
        var pts = points
        for _ in 0..<iterations {
            guard pts.count >= 2 else { return pts }
            var newPts = [StrokePoint]()
            newPts.append(pts[0])  // keep first point
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                // Q = 75% A + 25% B
                let q = StrokePoint(
                    x: a.x * 0.75 + b.x * 0.25,
                    y: a.y * 0.75 + b.y * 0.25,
                    pressure: a.pressure * 0.75 + b.pressure * 0.25,
                    altitude: a.altitude * 0.75 + b.altitude * 0.25,
                    cumulDist: 0
                )
                // R = 25% A + 75% B
                let r = StrokePoint(
                    x: a.x * 0.25 + b.x * 0.75,
                    y: a.y * 0.25 + b.y * 0.75,
                    pressure: a.pressure * 0.25 + b.pressure * 0.75,
                    altitude: a.altitude * 0.25 + b.altitude * 0.75,
                    cumulDist: 0
                )
                newPts.append(q)
                newPts.append(r)
            }
            newPts.append(pts.last!)  // keep last point
            pts = newPts
        }
        // Recalculate cumulative distance
        var dist: Float = 0
        pts[0].cumulDist = 0
        for i in 1..<pts.count {
            let dx = pts[i].x - pts[i - 1].x
            let dy = pts[i].y - pts[i - 1].y
            dist += sqrt(dx * dx + dy * dy)
            pts[i].cumulDist = dist
        }
        return pts
    }

    // MARK: - Undo / Redo

    func undo() -> Bool {
        guard let last = strokes.popLast() else { return false }
        undoneStrokes.append(last)
        return true
    }

    func redo() -> Bool {
        guard let restored = undoneStrokes.popLast() else { return false }
        strokes.append(restored)
        return true
    }

    // MARK: - Ripples

    func spawnRipples(at centers: [SIMD2<Float>], color: SIMD4<Float>, time: CFTimeInterval, reach: Float = 0.5) {
        guard time - lastRippleTime >= 0.700 else { return }
        lastRippleTime = time

        let speed: Float = 0.30 + Float.random(in: 0...0.12)
        let baseMax: Float = 120 + reach * 280  // reach 0→120, reach 1→400
        let maxR: Float = baseMax + Float.random(in: 0...30)

        for center in centers {
            let ripple = Ripple(
                center: center,
                radius: 30,
                maxRadius: maxR,
                alpha: 0.85,
                speed: speed,
                color: color,
                rings: 3
            )
            ripples.append(ripple)
        }
    }

    func updateRipples() {
        for i in ripples.indices.reversed() {
            ripples[i].radius += ripples[i].speed
            let progress = ripples[i].radius / ripples[i].maxRadius
            let decay: Float = 1.0 - (0.002 + 0.025 * progress * progress)
            ripples[i].alpha *= decay
            if ripples[i].alpha < 0.01 || ripples[i].radius > ripples[i].maxRadius {
                ripples.remove(at: i)
            }
        }
    }

    // MARK: - Ambient Blooms

    func updateAmbientBlooms(canvasSize: CGSize, inkColor: SIMD4<Float>, time: CFTimeInterval) {
        guard bloomsEnabled else {
            ambientBlooms.removeAll()
            return
        }

        // Spawn new blooms at random intervals — small, scattered, delicate
        let spawnInterval = Double(3.0 - bloomSpawnRate * 2.5)
        if time - lastBloomSpawnTime >= spawnInterval && ambientBlooms.count < 8 {
            lastBloomSpawnTime = time

            // Scatter across full canvas
            let cx = Float.random(in: 80...Float(canvasSize.width) - 80)
            let cy = Float.random(in: 80...Float(canvasSize.height) - 80)
            let maxR = Float.random(in: 60...180)  // generous expansion range

            ambientBlooms.append(AmbientBloom(
                center: SIMD2<Float>(cx, cy),
                radius: 3,
                maxRadius: maxR,
                alpha: 0,
                targetAlpha: bloomIntensity * Float.random(in: 0.20...0.40),
                color: inkColor,
                phase: .fadeIn,
                phaseTimer: Float.random(in: 80...140)  // slow fade-in (~1s)
            ))
        }

        // Update: slow firework — fade in briefly, then continuously expand + dissolve
        for i in ambientBlooms.indices.reversed() {
            ambientBlooms[i].phaseTimer -= 1

            let progress = ambientBlooms[i].radius / ambientBlooms[i].maxRadius

            // Very slow expansion — decelerates as it grows (like real dissipation)
            let expandSpeed: Float = 0.08 + (1.0 - progress) * 0.12
            ambientBlooms[i].radius += expandSpeed

            switch ambientBlooms[i].phase {
            case .fadeIn:
                // Fade-in over ~0.5 second
                let fadeRate = ambientBlooms[i].targetAlpha / 60.0
                ambientBlooms[i].alpha = min(ambientBlooms[i].alpha + fadeRate, ambientBlooms[i].targetAlpha)
                if ambientBlooms[i].phaseTimer <= 0 {
                    // Skip hold — go straight to dissolve
                    ambientBlooms[i].phase = .fadeOut
                    ambientBlooms[i].phaseTimer = 999
                }

            case .hold:
                ambientBlooms[i].phase = .fadeOut

            case .expand:
                ambientBlooms[i].phase = .fadeOut

            case .fadeOut:
                // Very gradual continuous fade — slower at start, faster as it expands
                // Like a firework ember slowly losing its glow
                let fadeFactor: Float = 1.0 - (0.002 + 0.008 * progress * progress)
                ambientBlooms[i].alpha *= fadeFactor
            }

            if ambientBlooms[i].alpha < 0.002 || ambientBlooms[i].radius > ambientBlooms[i].maxRadius {
                ambientBlooms.remove(at: i)
            }
        }
    }

    // MARK: - Sparkle particles

    private func spawnSparkle(at position: SIMD2<Float>, color: SIMD4<Float>) {
        guard sparkles.count < 200 else { return }

        // Spawn 1-3 sparkles near the point
        let count = Int.random(in: 1...3)
        for _ in 0..<count {
            let offset = SIMD2<Float>(Float.random(in: -8...8), Float.random(in: -8...8))
            sparkles.append(Sparkle(
                position: position + offset,
                alpha: Float.random(in: 0.4...0.9),
                size: Float.random(in: 2...5),
                color: color,
                life: Float.random(in: 20...50) // frames
            ))
        }
    }

    func updateSparkles() {
        for i in sparkles.indices.reversed() {
            sparkles[i].life -= 1
            sparkles[i].alpha *= 0.95  // gentle fade
            sparkles[i].size *= 0.98   // shrink slightly
            if sparkles[i].life <= 0 || sparkles[i].alpha < 0.01 {
                sparkles.remove(at: i)
            }
        }
    }

    // MARK: - Clear

    func clearAll() {
        strokes.removeAll()
        undoneStrokes.removeAll()
        currentStroke = nil
        predictedPoints = []
        ripples.removeAll()
        ambientBlooms.removeAll()
        sparkles.removeAll()
    }
}
