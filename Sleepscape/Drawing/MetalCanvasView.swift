import SwiftUI
import MetalKit
import MetalPerformanceShaders
import simd

// ═══════════════════════════════════════════
//  GPU-side structs matching Shaders.metal
// ═══════════════════════════════════════════

struct GPUStrokePoint {
    var position: SIMD2<Float>
    var pressure: Float
    var altitude: Float
    var cumulDist: Float
    var _pad: Float = 0   // align to 24 bytes
}

struct GPUStrokeUniforms {
    var canvasSize: SIMD2<Float>     // offset 0  (8 bytes)
    var _pad0: SIMD2<Float> = .zero  // offset 8  (8 bytes)
    var color: SIMD4<Float>          // offset 16 (16 bytes)
    var brushSize: Float             // offset 32
    var alpha: Float                 // offset 36
    var glowRadius: Float            // offset 40
    var lineStyle: UInt32            // offset 44
    // Total: 48 bytes
}

struct GPURippleData {
    var center: SIMD2<Float>
    var radius: Float
    var alpha: Float
    var color: SIMD4<Float>
    var rings: Int32
    var _pad0: Int32 = 0
    var _pad1: SIMD2<Float> = .zero
}

struct GPUAmbientBloomData {
    var center: SIMD2<Float>
    var radius: Float
    var alpha: Float
    var color: SIMD4<Float>
    var progress: Float
    var _pad: SIMD3<Float> = .zero  // align to 48 bytes
}

struct GPUSparkleData {
    var position: SIMD2<Float>
    var alpha: Float
    var size: Float
    var color: SIMD4<Float>
}

struct GPUEllipseUniforms {
    var canvasSize: SIMD2<Float>
    var _pad0: SIMD2<Float> = .zero
    var color: SIMD4<Float>
    var center: SIMD2<Float>
    var radii: SIMD2<Float>
    var rotation: Float
    var lineWidth: Float
    var alpha: Float
    var _pad1: Float = 0
}

// ═══════════════════════════════════════════
//  Custom MTKView subclass for touch capture
// ═══════════════════════════════════════════

class TouchCaptureMTKView: MTKView {
    weak var coordinator: MetalCanvasView.Coordinator?

    private func pixelLocation(for touch: UITouch) -> CGPoint {
        let pt = touch.preciseLocation(in: self)
        let scale = self.contentScaleFactor
        return CGPoint(x: pt.x * scale, y: pt.y * scale)
    }

    /// Canvas is always fully usable — no clipping.
    private func isInsideMandala(_ point: CGPoint) -> Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let coord = coordinator else { return }

        let point = pixelLocation(for: touch)

        // Clip to mandala circle
        guard isInsideMandala(point) else { return }

        let pressure: Float = touch.type == .pencil ? Float(touch.force / touch.maximumPossibleForce) : 0.5
        let altitude: Float = touch.type == .pencil ? Float(touch.altitudeAngle) : (.pi / 2)

        let color = coord.appState.currentInkSIMD
        coord.drawingEngine.beginStroke(
            at: point, pressure: pressure, altitude: altitude,
            color: color, brushSize: coord.appState.brushSize * Float(self.contentScaleFactor),
            mode: coord.appState.drawMode,
            lineStyle: coord.appState.lineStyle
        )
        coord.appState.showBreathGuide = false
    }

    private var lastAcceptedPointTime: CFTimeInterval = 0

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let coord = coordinator,
              let coalesced = event?.coalescedTouches(for: touch) else { return }

        let isPencil = touch.type == .pencil
        let scale = self.contentScaleFactor
        let throttleMs = coord.appState.paceThrottle  // 0–120ms
        let now = CACurrentMediaTime()

        for t in coalesced {
            let pt = t.preciseLocation(in: self)
            let point = CGPoint(x: pt.x * scale, y: pt.y * scale)

            guard isInsideMandala(point) else { continue }

            // Pace throttle: skip if too soon since last accepted point
            if throttleMs > 0 {
                let elapsed = (now - lastAcceptedPointTime) * 1000  // ms
                if elapsed < Double(throttleMs) { continue }
            }
            lastAcceptedPointTime = now

            let pressure: Float = isPencil ? Float(t.force / t.maximumPossibleForce) : 0.5
            let altitude: Float = isPencil ? Float(t.altitudeAngle) : (.pi / 2)
            coord.drawingEngine.addPoint(point, pressure: pressure, altitude: altitude,
                                         isPencil: isPencil, canvasSize: self.drawableSize)
        }

        if let predicted = event?.predictedTouches(for: touch) {
            coord.drawingEngine.setPredicted(predicted.compactMap {
                let pt = $0.preciseLocation(in: self)
                let point = CGPoint(x: pt.x * scale, y: pt.y * scale)
                return isInsideMandala(point) ? point : nil
            })
        }

        // Spawn ripples at all symmetry-mirrored touch positions (inside mandala only)
        let loc = pixelLocation(for: touch)
        guard isInsideMandala(loc) else { return }

        let rippleTime = CACurrentMediaTime()
        let inkColor = coord.appState.currentInkSIMD

        let transforms = SymmetryTransform.transforms(
            for: coord.appState.drawMode,
            symmetry: coord.appState.symmetry,
            canvasSize: self.drawableSize
        )
        let centers = transforms.map { tx -> SIMD2<Float> in
            let t = tx * SIMD3<Float>(Float(loc.x), Float(loc.y), 1)
            return SIMD2<Float>(t.x, t.y)
        }
        if coord.appState.ripplesEnabled {
            coord.drawingEngine.spawnRipples(at: centers, color: inkColor, time: rippleTime)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.drawingEngine.endStroke()
        coordinator?.updateUndoRedoState()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.drawingEngine.endStroke()
        coordinator?.updateUndoRedoState()
    }
}

// ═══════════════════════════════════════════
//  UIViewRepresentable wrapper
// ═══════════════════════════════════════════

struct MetalCanvasView: UIViewRepresentable {
    var appState: AppState

    func makeUIView(context: Context) -> TouchCaptureMTKView {
        let mtkView = TouchCaptureMTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.preferredFramesPerSecond = 120
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isMultipleTouchEnabled = false
        mtkView.isOpaque = true

        let coord = context.coordinator
        coord.setup(for: mtkView)
        mtkView.delegate = coord
        mtkView.coordinator = coord

        return mtkView
    }

    func updateUIView(_ uiView: TouchCaptureMTKView, context: Context) {
        let coord = context.coordinator
        let oldPalette = coord.appState.currentPalette.id
        let oldBg = coord.appState.canvasBackground
        let oldGlow = coord.appState.glowIntensity
        coord.appState = appState

        if oldPalette != appState.currentPalette.id || oldBg != appState.canvasBackground {
            coord.startBackgroundTransition()
        }

        // Re-render strokes when glow intensity changes (affects cached stroke texture)
        if oldGlow != appState.glowIntensity {
            coord.requestStrokeReRender()
        }

        // Sync bloom settings
        coord.drawingEngine.bloomsEnabled = appState.bloomsEnabled
        coord.drawingEngine.bloomSpawnRate = appState.bloomSpawnRate
        coord.drawingEngine.bloomIntensity = appState.bloomIntensity

        // Sync stroke behaviour settings
        coord.drawingEngine.pathSmoothingEnabled = appState.pathSmoothingEnabled
        coord.drawingEngine.slowInkEnabled = appState.slowInkEnabled
        coord.drawingEngine.sparklesEnabled = appState.sparklesEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    // ═══════════════════════════════════════════
    //  Coordinator — owns Metal pipeline + rendering
    // ═══════════════════════════════════════════

    class Coordinator: NSObject, MTKViewDelegate {
        var appState: AppState
        let drawingEngine = DrawingEngine()

        private var device: MTLDevice!
        private var commandQueue: MTLCommandQueue!
        private var library: MTLLibrary!

        // Pipeline states
        private var dotPipelineState: MTLRenderPipelineState!
        private var segmentPipelineState: MTLRenderPipelineState!
        private var compositePipelineState: MTLRenderPipelineState!
        private var alphaCompositePipelineState: MTLRenderPipelineState!
        private var bloomExtractPipelineState: MTLRenderPipelineState!
        private var additiveCompositePipelineState: MTLRenderPipelineState!
        private var ripplePipelineState: MTLRenderPipelineState!
        private var ellipsePipelineState: MTLRenderPipelineState!
        private var ambientBloomPipelineState: MTLRenderPipelineState!
        private var sparklePipelineState: MTLRenderPipelineState!
        private var centerGlowPipelineState: MTLRenderPipelineState!
        private var mandalaBorderPipelineState: MTLRenderPipelineState!
        private var breathPulsePipelineState: MTLRenderPipelineState!
        private var vignettePipelineState: MTLRenderPipelineState!
        private var brightnessCapPipelineState: MTLRenderPipelineState!

        // Drawing state for breath pulse
        private var isDrawing: Bool = false
        private var drawEndTime: CFTimeInterval = 0
        private var hasEverDrawn: Bool = false

        // Textures
        private var strokeTexture: MTLTexture?
        private var bloomSourceTexture: MTLTexture?
        private var bloomBlurTexture: MTLTexture?
        private var rippleTexture: MTLTexture?
        private var canvasSize: CGSize = .zero

        // Bloom
        private var gaussianBlur: MPSImageGaussianBlur?

        // Track rendered strokes
        private var renderedStrokeCount: Int = 0

        // Background dissolve
        private var bgTransitionProgress: Float = 1.0
        private var bgTransitionOldColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Auto color cycling
        private var lastAutoColorTime: CFTimeInterval = 0

        // Save state
        private weak var currentView: MTKView?

        init(appState: AppState) {
            self.appState = appState
            super.init()
        }

        func setup(for view: MTKView) {
            guard let device = view.device else { return }
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            self.library = device.makeDefaultLibrary()
            self.currentView = view

            gaussianBlur = MPSImageGaussianBlur(device: device, sigma: 12.0)

            // Alpha blend helper
            func alphaBlendAttachment(_ desc: MTLRenderPipelineDescriptor) {
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                desc.colorAttachments[0].isBlendingEnabled = true
                desc.colorAttachments[0].rgbBlendOperation = .add
                desc.colorAttachments[0].alphaBlendOperation = .add
                desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                desc.colorAttachments[0].sourceAlphaBlendFactor = .one
                desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }

            func additiveBlendAttachment(_ desc: MTLRenderPipelineDescriptor) {
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                desc.colorAttachments[0].isBlendingEnabled = true
                desc.colorAttachments[0].rgbBlendOperation = .add
                desc.colorAttachments[0].alphaBlendOperation = .add
                desc.colorAttachments[0].sourceRGBBlendFactor = .one
                desc.colorAttachments[0].destinationRGBBlendFactor = .one
                desc.colorAttachments[0].sourceAlphaBlendFactor = .one
                desc.colorAttachments[0].destinationAlphaBlendFactor = .one
            }

            // Dot pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "symmetryDotVertex")
                desc.fragmentFunction = library.makeFunction(name: "dotFragmentShader")
                alphaBlendAttachment(desc)
                dotPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Dot pipeline error: \(error)") }

            // Segment pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "symmetrySegmentVertex")
                desc.fragmentFunction = library.makeFunction(name: "segmentFragmentShader")
                alphaBlendAttachment(desc)
                segmentPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Segment pipeline error: \(error)") }

            // Composite — no blend
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "textureFragmentShader")
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                compositePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Composite pipeline error: \(error)") }

            // Alpha composite
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "textureFragmentShader")
                alphaBlendAttachment(desc)
                alphaCompositePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Alpha composite pipeline error: \(error)") }

            // Bloom extract
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "brightPassFragment")
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                bloomExtractPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Bloom extract pipeline error: \(error)") }

            // Additive composite (bloom glow)
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "textureFragmentShader")
                additiveBlendAttachment(desc)
                additiveCompositePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Additive composite pipeline error: \(error)") }

            // Ripple pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "rippleVertex")
                desc.fragmentFunction = library.makeFunction(name: "rippleFragment")
                alphaBlendAttachment(desc)
                ripplePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Ripple pipeline error: \(error)") }

            // Ellipse pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "ellipseVertex")
                desc.fragmentFunction = library.makeFunction(name: "ellipseFragment")
                alphaBlendAttachment(desc)
                ellipsePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Ellipse pipeline error: \(error)") }

            // Ambient bloom pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "ambientBloomVertex")
                desc.fragmentFunction = library.makeFunction(name: "ambientBloomFragment")
                additiveBlendAttachment(desc)  // additive for glow effect
                ambientBloomPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Ambient bloom pipeline error: \(error)") }

            // Sparkle pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "sparkleVertex")
                desc.fragmentFunction = library.makeFunction(name: "sparkleFragment")
                additiveBlendAttachment(desc)  // additive for bright twinkle
                sparklePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Sparkle pipeline error: \(error)") }

            // Center glow pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "centerGlowFragment")
                additiveBlendAttachment(desc)
                centerGlowPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Center glow pipeline error: \(error)") }

            // Mandala border glow pipeline (additive)
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "mandalaBorderFragment")
                additiveBlendAttachment(desc)
                mandalaBorderPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Mandala border pipeline error: \(error)") }

            // Breath pulse pipeline (additive)
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "breathPulseFragment")
                additiveBlendAttachment(desc)
                breathPulsePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Breath pulse pipeline error: \(error)") }

            // Vignette pipeline (normal alpha blend — darkens edges)
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "radialVignetteFragment")
                alphaBlendAttachment(desc)
                vignettePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Vignette pipeline error: \(error)") }

            // Brightness cap pipeline (no blend — replaces pixel, uses [[color(0)]])
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = library.makeFunction(name: "quadVertexShader")
                desc.fragmentFunction = library.makeFunction(name: "brightnessCapFragment")
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                brightnessCapPipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch { print("Brightness cap pipeline error: \(error)") }
        }

        // MARK: - Undo/Redo state sync

        func updateUndoRedoState() {
            appState.canUndo = drawingEngine.canUndo
            appState.canRedo = drawingEngine.canRedo
        }

        // MARK: - Background transition

        private var needsBackgroundReRender = false

        func startBackgroundTransition() {
            bgTransitionOldColor = currentBGClearColor()
            bgTransitionProgress = 0
            // Flag for re-render in next draw loop (safer than calling from updateUIView)
            needsBackgroundReRender = true
        }

        func requestStrokeReRender() {
            needsBackgroundReRender = true
        }

        // MARK: - Texture management

        private func ensureTextures(size: CGSize) {
            let w = Int(size.width)
            let h = Int(size.height)
            guard w > 0, h > 0 else { return }

            if let tex = strokeTexture, tex.width == w, tex.height == h {
                return
            }

            func makeTexture() -> MTLTexture? {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false
                )
                desc.usage = [.renderTarget, .shaderRead, .shaderWrite]
                desc.storageMode = .private
                return device.makeTexture(descriptor: desc)
            }

            strokeTexture = makeTexture()
            bloomSourceTexture = makeTexture()
            bloomBlurTexture = makeTexture()
            rippleTexture = makeTexture()

            clearStrokeTexture()
            renderedStrokeCount = 0
        }

        private func clearStrokeTexture() {
            guard let texture = strokeTexture,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let bg = currentBGClearColor()
            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = texture
            desc.colorAttachments[0].loadAction = .clear
            desc.colorAttachments[0].storeAction = .store
            desc.colorAttachments[0].clearColor = bg

            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) {
                encoder.endEncoding()
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        private func currentBGClearColor() -> MTLClearColor {
            let color = UIColor(appState.backgroundColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return MTLClearColor(red: Double(r), green: Double(g), blue: Double(b), alpha: 1.0)
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            canvasSize = size
            ensureTextures(size: size)
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let drawableSize = view.drawableSize
            if canvasSize != drawableSize {
                canvasSize = drawableSize
                ensureTextures(size: drawableSize)
            }
            ensureTextures(size: drawableSize)

            guard let strokeTex = strokeTexture,
                  let bloomSrcTex = bloomSourceTexture,
                  let bloomBlurTex = bloomBlurTexture,
                  let rippleTex = rippleTexture else { return }

            // Handle clear
            if appState.clearRequested {
                appState.clearRequested = false
                clearCanvas()
            }

            // Handle undo
            if appState.undoRequested {
                appState.undoRequested = false
                if drawingEngine.undo() {
                    reRenderAllStrokes()
                }
                updateUndoRedoState()
            }

            // Handle redo
            if appState.redoRequested {
                appState.redoRequested = false
                if drawingEngine.redo() {
                    reRenderAllStrokes()
                }
                updateUndoRedoState()
            }

            // Re-render strokes when background changed (flag set by startBackgroundTransition)
            if needsBackgroundReRender {
                needsBackgroundReRender = false
                reRenderAllStrokes()
            }

            // Background dissolve
            if bgTransitionProgress < 1.0 {
                bgTransitionProgress = min(bgTransitionProgress + 0.008, 1.0)
            }

            // Auto color cycling
            if appState.autoColorEnabled {
                let now = CACurrentMediaTime()
                // Slider 0.0 → 4s (fast), 1.0 → 30s (slow) — right = longer
                let interval = Double(4.0 + appState.autoColorSpeed * 26.0)
                if now - lastAutoColorTime >= interval {
                    lastAutoColorTime = now
                    let inkCount = appState.currentPalette.inks.count
                    if inkCount > 0 {
                        appState.currentInkIndex = (appState.currentInkIndex + 1) % inkCount
                    }
                }
            }

            // Track drawing state for breath pulse
            let currentlyDrawing = drawingEngine.currentStroke != nil
            if currentlyDrawing {
                isDrawing = true
                hasEverDrawn = true
                drawEndTime = CACurrentMediaTime()
            } else if isDrawing {
                isDrawing = false
                drawEndTime = CACurrentMediaTime()
            }

            // Update particles
            drawingEngine.updateRipples()
            drawingEngine.updateSparkles()
            drawingEngine.updateAmbientBlooms(
                canvasSize: drawableSize,
                inkColor: appState.currentInkSIMD,
                time: CACurrentMediaTime()
            )

            // Get symmetry transforms
            let transforms = SymmetryTransform.transforms(
                for: appState.drawMode,
                symmetry: appState.symmetry,
                canvasSize: drawableSize
            )
            let transformBuffer = device.makeBuffer(
                bytes: transforms,
                length: MemoryLayout<simd_float3x3>.stride * transforms.count,
                options: .storageModeShared
            )

            // ── Step 1: Render new strokes onto persistent stroke texture ──
            renderNewStrokes(to: strokeTex, commandBuffer: commandBuffer,
                           canvasSize: drawableSize, transforms: transforms,
                           transformBuffer: transformBuffer)

            // ── Step 2: Render ripples to ripple texture (cleared each frame) ──
            renderRipples(to: rippleTex, commandBuffer: commandBuffer, canvasSize: drawableSize)

            // ── Step 3: Bloom pass (background-aware) ──
            let bgClear = currentBGClearColor()
            let bloomPassDesc = MTLRenderPassDescriptor()
            bloomPassDesc.colorAttachments[0].texture = bloomSrcTex
            bloomPassDesc.colorAttachments[0].loadAction = .clear
            bloomPassDesc.colorAttachments[0].storeAction = .store
            bloomPassDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: bloomPassDesc) {
                encoder.setRenderPipelineState(bloomExtractPipelineState)
                encoder.setFragmentTexture(strokeTex, index: 0)
                // Pass background color so bloom only extracts strokes, not the bg itself
                var bgSIMD = SIMD4<Float>(Float(bgClear.red), Float(bgClear.green), Float(bgClear.blue), 1.0)
                encoder.setFragmentBytes(&bgSIMD, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()
            }

            gaussianBlur?.encode(commandBuffer: commandBuffer,
                                sourceTexture: bloomSrcTex,
                                destinationTexture: bloomBlurTex)

            // ── Step 4: Final composite to drawable ──
            let passDesc = view.currentRenderPassDescriptor!
            passDesc.colorAttachments[0].loadAction = .clear
            passDesc.colorAttachments[0].clearColor = bgClear

            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) {
                // 1) Blit stroke texture (no blend — overwrites cleared bg)
                encoder.setRenderPipelineState(compositePipelineState)
                encoder.setFragmentTexture(strokeTex, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

                // 2) Breath pulse — independent layer, canvas-based radius
                if appState.breathPulseEnabled {
                    let breathRadius = min(Float(drawableSize.width), Float(drawableSize.height)) / 2 * 0.70
                    // On idle (3s+), dim mandala and make pulse more prominent
                    let idleTime = CACurrentMediaTime() - drawEndTime
                    let idleFade: Float = hasEverDrawn && !isDrawing && idleTime > 3.0
                        ? Float(min(2.5, 1.0 + (idleTime - 3.0) * 0.3))
                        : 1.0
                    renderBreathPulse(encoder: encoder, canvasSize: drawableSize,
                                     radiusPx: breathRadius, fadeIn: idleFade)
                }

                // 5) Additive bloom glow
                encoder.setRenderPipelineState(additiveCompositePipelineState)
                encoder.setFragmentTexture(bloomBlurTex, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

                // 6) Ambient blooms (additive glow circles)
                renderAmbientBlooms(encoder: encoder, canvasSize: drawableSize)

                // 7) Sparkle particles (additive bright dots)
                if appState.sparklesEnabled {
                    renderSparkles(encoder: encoder, canvasSize: drawableSize)
                }

                // 8) Alpha-blend ripples on top
                encoder.setRenderPipelineState(alphaCompositePipelineState)
                encoder.setFragmentTexture(rippleTex, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

                // 9) Brightness cap — clamp luminance post-bloom (uses [[color(0)]])
                let cap = appState.brightnessCap
                if cap < 1.0, let capPipeline = brightnessCapPipelineState {
                    encoder.setRenderPipelineState(capPipeline)
                    var capVal = cap
                    encoder.setFragmentBytes(&capVal, length: MemoryLayout<Float>.stride, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }

                // 10) Radial vignette (darkens edges — very last)
                renderVignette(encoder: encoder, canvasSize: drawableSize)

                encoder.endEncoding()
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        // MARK: - Stroke rendering (3-pass glow + symmetry + line styles)

        private func renderNewStrokes(to texture: MTLTexture, commandBuffer: MTLCommandBuffer,
                                       canvasSize: CGSize, transforms: [simd_float3x3],
                                       transformBuffer: MTLBuffer?) {
            let completedStrokes = drawingEngine.strokes
            let currentStroke = drawingEngine.currentStroke

            let hasNewCompleted = completedStrokes.count > renderedStrokeCount
            let hasCurrentPoints = (currentStroke?.points.count ?? 0) > 0

            if !hasNewCompleted && !hasCurrentPoints { return }

            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = texture
            desc.colorAttachments[0].loadAction = .load
            desc.colorAttachments[0].storeAction = .store

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc),
                  let txBuf = transformBuffer else { return }

            let size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
            let txCount = transforms.count

            let glow = appState.glowIntensity

            if hasNewCompleted {
                for i in renderedStrokeCount..<completedStrokes.count {
                    renderStroke3Pass(completedStrokes[i], encoder: encoder,
                                    canvasSize: size, transformBuffer: txBuf,
                                    transformCount: txCount, glowIntensity: glow)
                }
                renderedStrokeCount = completedStrokes.count
            }

            if let stroke = currentStroke, !stroke.points.isEmpty {
                renderStroke3Pass(stroke, encoder: encoder,
                                canvasSize: size, transformBuffer: txBuf,
                                transformCount: txCount, glowIntensity: glow)
            }

            encoder.endEncoding()
        }

        /// 3-layer glow with line style support
        /// glowIntensity scales the halo (pass 0) and mid-glow (pass 1) alphas; core (pass 2) is unchanged.
        private func renderStroke3Pass(_ stroke: Stroke, encoder: MTLRenderCommandEncoder,
                                        canvasSize: SIMD2<Float>, transformBuffer: MTLBuffer,
                                        transformCount: Int, glowIntensity: Float = 1.0) {
            let points = stroke.points
            guard !points.isEmpty else { return }

            let color = SIMD4<Float>(stroke.colorR, stroke.colorG, stroke.colorB, stroke.colorA)
            let style = stroke.gpuLineStyle
            let gpuPoints = points.map { GPUStrokePoint(
                position: SIMD2<Float>($0.x, $0.y),
                pressure: $0.pressure,
                altitude: $0.altitude,
                cumulDist: $0.cumulDist
            )}

            guard let pointBuffer = device.makeBuffer(
                bytes: gpuPoints,
                length: MemoryLayout<GPUStrokePoint>.stride * gpuPoints.count,
                options: .storageModeShared
            ) else { return }

            // Glow passes vary by style
            let passes: [(widthMul: Float, alpha: Float)]
            switch LineStyle(rawValue: stroke.lineStyle) ?? .neon {
            case .neon:
                passes = [(3.2, 0.03), (1.5, 0.18), (0.5, 0.90)]
            case .softGlow:
                passes = [(4.0, 0.04), (2.0, 0.12), (0.8, 0.60)]  // wider, softer
            case .dashed:
                passes = [(2.0, 0.05), (1.0, 0.20), (0.4, 0.85)]
            case .dotted:
                passes = [(2.5, 0.06), (1.2, 0.15), (0.5, 0.90)]
            case .sketch:
                passes = [(2.0, 0.02), (1.0, 0.10), (0.5, 0.80)]  // less glow, more core
            }

            for (passIndex, pass) in passes.enumerated() {
                let effectiveBrushSize = stroke.brushSize * pass.widthMul
                // Scale halo (pass 0) and mid-glow (pass 1) by glowIntensity; core (pass 2) untouched
                let effectiveAlpha = passIndex < 2 ? pass.alpha * glowIntensity : pass.alpha

                var uniforms = GPUStrokeUniforms(
                    canvasSize: canvasSize,
                    color: color,
                    brushSize: effectiveBrushSize,
                    alpha: effectiveAlpha,
                    glowRadius: 0,
                    lineStyle: style
                )

                // Segments (skip for dotted — dots only)
                let isDotted = (style == LineStyle.dotted.gpuIndex)
                if !isDotted, let segPipeline = segmentPipelineState, gpuPoints.count >= 2 {
                    encoder.setRenderPipelineState(segPipeline)
                    encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<GPUStrokeUniforms>.stride, index: 1)
                    encoder.setVertexBuffer(transformBuffer, offset: 0, index: 2)
                    var segCount = UInt32(gpuPoints.count - 1)
                    encoder.setVertexBytes(&segCount, length: MemoryLayout<UInt32>.stride, index: 3)
                    let instanceCount = Int(segCount) * transformCount
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                                          instanceCount: instanceCount)
                }

                // Dots — for dotted style (every point) or single-point taps
                if (isDotted || gpuPoints.count < 2), let dotPipeline = dotPipelineState {
                    encoder.setRenderPipelineState(dotPipeline)
                    encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<GPUStrokeUniforms>.stride, index: 1)
                    encoder.setVertexBuffer(transformBuffer, offset: 0, index: 2)
                    var ptCount = UInt32(gpuPoints.count)
                    encoder.setVertexBytes(&ptCount, length: MemoryLayout<UInt32>.stride, index: 3)
                    let instanceCount = Int(ptCount) * transformCount
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 1,
                                          instanceCount: instanceCount)
                }
            }
        }

        // MARK: - Re-render all strokes (for undo/redo)

        private func reRenderAllStrokes() {
            clearStrokeTexture()
            renderedStrokeCount = 0

            guard let strokeTex = strokeTexture,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let transforms = SymmetryTransform.transforms(
                for: appState.drawMode,
                symmetry: appState.symmetry,
                canvasSize: canvasSize
            )
            guard let txBuf = device.makeBuffer(
                bytes: transforms,
                length: MemoryLayout<simd_float3x3>.stride * transforms.count,
                options: .storageModeShared
            ) else { return }

            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = strokeTex
            desc.colorAttachments[0].loadAction = .load
            desc.colorAttachments[0].storeAction = .store

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else { return }
            let size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))

            let glow = appState.glowIntensity
            for stroke in drawingEngine.strokes {
                renderStroke3Pass(stroke, encoder: encoder,
                                canvasSize: size, transformBuffer: txBuf,
                                transformCount: transforms.count, glowIntensity: glow)
            }

            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            renderedStrokeCount = drawingEngine.strokes.count
        }

        // MARK: - Ripple rendering

        private func renderRipples(to texture: MTLTexture, commandBuffer: MTLCommandBuffer,
                                    canvasSize: CGSize) {
            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = texture
            desc.colorAttachments[0].loadAction = .clear
            desc.colorAttachments[0].storeAction = .store
            desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else { return }

            let ripples = drawingEngine.ripples
            if !ripples.isEmpty, let ripplePipeline = ripplePipelineState {
                var allRings: [GPURippleData] = []
                for r in ripples {
                    for ringIdx in 0..<r.rings {
                        let ringFrac = Float(ringIdx) / Float(max(r.rings - 1, 1))
                        let ringRadius = r.radius * (0.6 + 0.4 * ringFrac)
                        let ringAlpha = r.alpha * (1.0 - ringFrac * 0.5)
                        allRings.append(GPURippleData(
                            center: r.center,
                            radius: ringRadius,
                            alpha: ringAlpha,
                            color: r.color,
                            rings: Int32(r.rings)
                        ))
                    }
                }

                guard !allRings.isEmpty, let ringBuffer = device.makeBuffer(
                    bytes: allRings,
                    length: MemoryLayout<GPURippleData>.stride * allRings.count,
                    options: .storageModeShared
                ) else {
                    encoder.endEncoding()
                    return
                }

                encoder.setRenderPipelineState(ripplePipeline)
                encoder.setVertexBuffer(ringBuffer, offset: 0, index: 0)
                var size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
                encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                      vertexCount: 6,
                                      instanceCount: allRings.count)
            }

            encoder.endEncoding()
        }

        // MARK: - Ambient bloom rendering

        private func renderAmbientBlooms(encoder: MTLRenderCommandEncoder, canvasSize: CGSize) {
            let blooms = drawingEngine.ambientBlooms
            guard !blooms.isEmpty, let pipeline = ambientBloomPipelineState else { return }

            let gpuBlooms = blooms.map { GPUAmbientBloomData(
                center: $0.center, radius: $0.radius,
                alpha: $0.alpha, color: $0.color,
                progress: $0.radius / $0.maxRadius
            )}

            guard let buffer = device.makeBuffer(
                bytes: gpuBlooms,
                length: MemoryLayout<GPUAmbientBloomData>.stride * gpuBlooms.count,
                options: .storageModeShared
            ) else { return }

            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            var size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
            encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                  vertexCount: 6, instanceCount: gpuBlooms.count)
        }

        // MARK: - Sparkle rendering

        private func renderSparkles(encoder: MTLRenderCommandEncoder, canvasSize: CGSize) {
            let sparkles = drawingEngine.sparkles
            guard !sparkles.isEmpty, let pipeline = sparklePipelineState else { return }

            let gpuSparkles = sparkles.map { GPUSparkleData(
                position: $0.position, alpha: $0.alpha,
                size: $0.size, color: $0.color
            )}

            guard let buffer = device.makeBuffer(
                bytes: gpuSparkles,
                length: MemoryLayout<GPUSparkleData>.stride * gpuSparkles.count,
                options: .storageModeShared
            ) else { return }

            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            var size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
            encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                  vertexCount: 6, instanceCount: gpuSparkles.count)
        }

        // MARK: - Center glow overlay

        private func renderCenterGlow(encoder: MTLRenderCommandEncoder, canvasSize: CGSize) {
            guard let pipeline = centerGlowPipelineState else { return }

            // Use a soft neutral white so it doesn't recolor existing strokes when ink changes
            var canvasInfo = SIMD4<Float>(
                Float(canvasSize.width) * 0.5,
                Float(canvasSize.height) * 0.5,
                Float(canvasSize.width),
                Float(canvasSize.height)
            )
            var glowColor = SIMD4<Float>(0.7, 0.7, 0.8, 0.3) // subtle cool white, lower alpha

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&canvasInfo, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentBytes(&glowColor, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        // MARK: - Mandala border glow

        // MARK: - Breath pulse (4-phase breathing pattern)

        private func renderBreathPulse(encoder: MTLRenderCommandEncoder, canvasSize: CGSize,
                                       radiusPx: Float, fadeIn: Float) {
            guard let pipeline = breathPulsePipelineState else { return }

            let inkColor = appState.currentInkSIMD
            let phases = appState.breathPhases

            // Matches BreathPulseUniforms in shader:
            // float2 canvasSize, float2 center, float maxRadius, float time,
            // float4 color, float fadeIn, float inhale, float hold, float exhale, float hold2
            var uniforms = (
                SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height)),
                SIMD2<Float>(Float(canvasSize.width / 2), Float(canvasSize.height / 2)),
                radiusPx,
                Float(CACurrentMediaTime()),
                SIMD4<Float>(inkColor.x, inkColor.y, inkColor.z, 1.0),
                fadeIn,
                phases.inhale,
                phases.hold,
                phases.exhale,
                phases.hold2
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        // MARK: - Vignette

        private func renderVignette(encoder: MTLRenderCommandEncoder, canvasSize: CGSize) {
            guard let pipeline = vignettePipelineState else { return }

            var size = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        // MARK: - Clear

        func clearCanvas() {
            drawingEngine.clearAll()
            renderedStrokeCount = 0
            hasEverDrawn = false
            clearStrokeTexture()
            updateUndoRedoState()
        }
    }
}
