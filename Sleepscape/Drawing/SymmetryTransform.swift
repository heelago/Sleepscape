import Foundation
import simd

struct SymmetryTransform {
    /// Generate all symmetry transforms for the given mode and fold count.
    /// Each transform is a 3x3 affine matrix (translate to center → rotate → optional flip → translate back).
    static func transforms(for mode: DrawMode, symmetry: Int, canvasSize: CGSize) -> [simd_float3x3] {
        let cx = Float(canvasSize.width / 2)
        let cy = Float(canvasSize.height / 2)
        let n = mode == .free ? 1 : symmetry

        var result: [simd_float3x3] = []

        for i in 0..<n {
            let angle = Float(i) * (2 * .pi / Float(n))

            // Normal rotation
            result.append(makeTransform(angle: angle, flip: false, cx: cx, cy: cy))

            // Mirrored (Y-axis flip)
            if mode != .free {
                result.append(makeTransform(angle: angle, flip: true, cx: cx, cy: cy))
            }
        }

        return result
    }

    /// Build a 3×3 affine: translate(-cx,-cy) → rotate(angle) → optional Y-flip → translate(cx,cy)
    private static func makeTransform(angle: Float, flip: Bool, cx: Float, cy: Float) -> simd_float3x3 {
        let cosA = cos(angle)
        let sinA = sin(angle)

        // Rotation matrix
        var rot = simd_float3x3(
            SIMD3<Float>(cosA, sinA, 0),
            SIMD3<Float>(-sinA, cosA, 0),
            SIMD3<Float>(0, 0, 1)
        )

        // Optional Y-axis flip (mirror horizontally)
        if flip {
            let flipMatrix = simd_float3x3(
                SIMD3<Float>(-1, 0, 0),
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 1)
            )
            rot = rot * flipMatrix
        }

        // Translate to origin
        let toOrigin = simd_float3x3(
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(-cx, -cy, 1)
        )

        // Translate back
        let toCenter = simd_float3x3(
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(cx, cy, 1)
        )

        return toCenter * rot * toOrigin
    }
}
