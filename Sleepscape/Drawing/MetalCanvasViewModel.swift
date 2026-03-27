import Foundation

/// ViewModel bridging AppState to the DrawingEngine.
/// Full implementation in Phase 1–4.
@Observable
class MetalCanvasViewModel {
    let drawingEngine = DrawingEngine()

    func clearCanvas() {
        drawingEngine.clearAll()
    }
}
