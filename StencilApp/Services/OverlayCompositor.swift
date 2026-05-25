import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Three sliders matching `frontend/app.py` `_make_overlay_preview`.
struct OverlaySettings: Equatable {
    /// 0..100 step 5, default 85.
    var stencilOpacity: Double = 85
    /// 0..100 step 5, default 45.
    var referenceOpacity: Double = 45
    /// 50..150 step 5, default 100. Acts as a brightness multiplier
    /// (clamped to [0.25, 2.0] like the Gradio code).
    var referenceBrightness: Double = 100
}

/// Builds the side-by-side "stencil over reference" preview that lives in the
/// Overlay tab. Pure-function compositor — no state.
///
/// The math mirrors the Gradio frontend exactly:
///
///     canvas    = reference * ref_alpha + white * (1 - ref_alpha)
///     line_mask = stencil_gray < 0.5
///     canvas[line_mask] = canvas[line_mask] * (1 - line_alpha) + line_rgb * line_alpha
///
/// Implemented with a single `CIColorKernel` for speed.
final class OverlayCompositor {
    private let context: CIContext

    init() {
        self.context = CIContext(options: [.cacheIntermediates: false])
    }

    func composite(
        reference: CGImage,
        stencil: CGImage,
        ink: InkColor,
        settings: OverlaySettings
    ) -> UIImage? {
        let width = stencil.width
        let height = stencil.height
        let target = CGRect(x: 0, y: 0, width: width, height: height)

        // Resize the reference to match the stencil's pixel dimensions.
        let referenceCI = CIImage(cgImage: reference)
        let scaleX = CGFloat(width) / referenceCI.extent.width
        let scaleY = CGFloat(height) / referenceCI.extent.height
        let scaledReference = referenceCI
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: target)

        let stencilCI = CIImage(cgImage: stencil).cropped(to: target)

        let brightnessFactor = max(0.25, min(2.0, settings.referenceBrightness / 100.0))
        let stencilAlpha    = max(0.0, min(1.0, settings.stencilOpacity / 100.0))
        let referenceAlpha  = max(0.0, min(1.0, settings.referenceOpacity / 100.0))
        let rgb = ink.rgb ?? (0, 0, 0)

        guard let kernel = Self.overlayKernel else { return nil }

        let output = kernel.apply(
            extent: target,
            roiCallback: { _, rect in rect },
            arguments: [
                scaledReference,
                stencilCI,
                brightnessFactor,
                stencilAlpha,
                referenceAlpha,
                CIVector(x: CGFloat(rgb.r), y: CGFloat(rgb.g), z: CGFloat(rgb.b), w: 1)
            ]
        )

        guard let output, let cg = context.createCGImage(output, from: target) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    private static let overlayKernel: CIKernel? = {
        let source = """
            kernel vec4 composeOverlay(
                sampler reference,
                sampler stencil,
                float brightness,
                float stencilAlpha,
                float referenceAlpha,
                vec4 inkRGB
            ) {
                vec4 ref = sample(reference, samplerCoord(reference));
                vec4 sten = sample(stencil, samplerCoord(stencil));

                vec3 brightRef = clamp(ref.rgb * brightness, 0.0, 1.0);
                vec3 canvas = brightRef * referenceAlpha + vec3(1.0) * (1.0 - referenceAlpha);

                float gray = (sten.r + sten.g + sten.b) / 3.0;
                float lineMask = step(gray, 0.5);

                vec3 tinted = canvas * (1.0 - stencilAlpha) + inkRGB.rgb * stencilAlpha;
                vec3 final = mix(canvas, tinted, lineMask);

                return vec4(final, 1.0);
            }
        """
        return CIKernel(source: source)
    }()
}
