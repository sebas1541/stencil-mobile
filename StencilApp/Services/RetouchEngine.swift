import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// User-facing line color presets for the swatch picker.
/// Hex values match the frontend (`frontend/app.py` `_LINE_COLORS`):
///   Black → keep grayscale (no tint)
///   Red   → (200, 20, 20)  — red transfer paper
///   Blue  → (0, 80, 210)   — blue/purple hectograph transfer paper
enum InkColor: String, CaseIterable, Identifiable, Hashable {
    case black
    case red
    case blue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .red:   return "Red"
        case .blue:  return "Blue"
        }
    }

    /// `nil` = leave the image grayscale (no recoloring).
    var rgb: (r: Double, g: Double, b: Double)? {
        switch self {
        case .black: return nil
        case .red:   return (200.0 / 255.0,  20.0 / 255.0,  20.0 / 255.0)
        case .blue:  return (  0.0 / 255.0,  80.0 / 255.0, 210.0 / 255.0)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .black: return .label
        case .red:   return UIColor(red: 200/255, green: 20/255,  blue: 20/255,  alpha: 1)
        case .blue:  return UIColor(red: 0,        green: 80/255,  blue: 210/255, alpha: 1)
        }
    }
}

/// Settings that drive `RetouchEngine.apply`. Mirrors the controls in
/// `frontend/app.py` 1:1.
struct RetouchSettings: Equatable {
    /// 10..250, default 128. Higher = fewer pixels become lines.
    var threshold: Double = 128

    /// -10..+10, default 0. Applies morphology only when |value| >= 4.
    /// Positive dilates, negative erodes.
    var lineThickness: Double = 0

    /// 0..8, default 0. Speckle cleanup before the threshold (kept as a
    /// post-threshold morphological opening here for simplicity).
    var denoise: Double = 0

    /// 0..3000 (step 10), default 0. Removes isolated components smaller than
    /// N pixels (approximated here as a stronger morphological opening).
    var noiseFilter: Double = 0

    /// 0..25, default 0. Bridges small gaps via morphological closing.
    var closeGaps: Double = 0

    /// Open + close pass with ellipse kernel.
    var smooth: Bool = false

    /// Small close pass.
    var sharpen: Bool = false

    /// Final colour inversion (white lines on black bg).
    var invert: Bool = false

    /// Line colour preset.
    var inkColor: InkColor = .black
}

/// Stateless Core Image pipeline that transforms a stencil PNG (black lines
/// on white background) into the user-retouched binary image. All steps are
/// pure functions over CIImage so chaining is cheap and re-runs on every
/// slider change are fast enough for interactive use.
final class RetouchEngine {
    private let context: CIContext

    init() {
        // GPU-backed context. `cacheIntermediates: false` keeps memory low for
        // the morphology chain.
        let options: [CIContextOption: Any] = [.cacheIntermediates: false]
        self.context = CIContext(options: options)
    }

    /// Run the full pipeline against `source` (assumed to be a stencil from
    /// the API, i.e. dark lines on a light background) and return a fresh
    /// UIImage.
    func apply(_ settings: RetouchSettings, to source: CGImage) -> UIImage? {
        let baseExtent = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        var image = CIImage(cgImage: source)

        // ── 1. Threshold (with the same coupling to Line Thickness that the
        //       Gradio frontend uses: threshold += clamp(lineWeight*4, -24, 24)).
        let coupledOffset = max(-24.0, min(24.0, settings.lineThickness * 4.0))
        let effectiveThreshold = max(1.0, min(254.0, settings.threshold + coupledOffset)) / 255.0

        if let thresholded = applyThreshold(to: image, threshold: effectiveThreshold) {
            image = thresholded
        }

        // ── 2. Line thickness — dilate / erode only when |weight| >= 4 so
        //       tiny moves don't fight the threshold coupling above.
        if abs(settings.lineThickness) >= 4 {
            let radius = morphologyRadius(forLineThickness: settings.lineThickness)
            // The image is white-bg / black-line — to thicken lines we need to
            // SHRINK the white background, which is `morphologyMinimum`.
            // To thin lines we need to GROW the white background → `morphologyMaximum`.
            if settings.lineThickness > 0 {
                image = morphologyMinimum(image, radius: radius)
            } else {
                image = morphologyMaximum(image, radius: radius)
            }
        }

        // ── 3. Denoise: opening = erode lines then dilate (removes tiny
        //       isolated black specks). Slider 0..8 → radius 0..2.
        if settings.denoise > 0 {
            let r = min(2.0, settings.denoise / 4.0)
            image = morphologyMaximum(image, radius: r)   // erase isolated lines
            image = morphologyMinimum(image, radius: r)   // restore strong lines
        }

        // ── 4. Noise filter (px²): similar to denoise but stronger. Slider
        //       0..3000 → radius 0..3.
        if settings.noiseFilter > 0 {
            let r = min(3.0, settings.noiseFilter / 1000.0)
            image = morphologyMaximum(image, radius: r)
            image = morphologyMinimum(image, radius: r)
        }

        // ── 5. Close gaps: closing = dilate then erode (bridges small gaps).
        //       Slider 0..25 → radius 0..6 (internally capped).
        if settings.closeGaps > 0 {
            let r = min(6.0, settings.closeGaps / 4.0)
            image = morphologyMinimum(image, radius: r)   // grow lines
            image = morphologyMaximum(image, radius: r)   // restore non-line spaces
        }

        // ── 6. Smooth (open + close with small radius).
        if settings.smooth {
            image = morphologyMaximum(image, radius: 1)
            image = morphologyMinimum(image, radius: 1)
            image = morphologyMinimum(image, radius: 1.5)
            image = morphologyMaximum(image, radius: 1.5)
        }

        // ── 7. Sharpen — small closing to reconnect tiny corner breaks.
        if settings.sharpen {
            image = morphologyMinimum(image, radius: 1)
            image = morphologyMaximum(image, radius: 1)
        }

        // ── 8. Invert if requested.
        if settings.invert {
            let inv = CIFilter.colorInvert()
            inv.inputImage = image
            if let output = inv.outputImage { image = output }
        }

        // ── 9. Line colour swap. Black pixels become tint; white stays white.
        //       `gray=0 → tint`, `gray=1 → white`, linear in between.
        if let tint = settings.inkColor.rgb, let tinted = tintBlackLines(in: image, rgb: tint) {
            image = tinted
        }

        // ── Render to CGImage → UIImage with the original orientation/scale.
        guard let cg = context.createCGImage(image, from: baseExtent) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    // MARK: - Building blocks

    private func morphologyRadius(forLineThickness value: Double) -> Double {
        // Match the Gradio behavior: 1 morphology iteration with a 3×3 kernel
        // when |value| >= 4. Core Image uses a continuous radius, so map the
        // discrete slider into 1.0–2.0.
        let absVal = abs(value)
        if absVal < 4 { return 0 }
        return 1.0 + min(1.0, (absVal - 4) / 6.0)
    }

    private func morphologyMaximum(_ image: CIImage, radius: Double) -> CIImage {
        guard radius > 0 else { return image }
        let filter = CIFilter.morphologyMaximum()
        filter.inputImage = image
        filter.radius = Float(radius)
        return filter.outputImage ?? image
    }

    private func morphologyMinimum(_ image: CIImage, radius: Double) -> CIImage {
        guard radius > 0 else { return image }
        let filter = CIFilter.morphologyMinimum()
        filter.inputImage = image
        filter.radius = Float(radius)
        return filter.outputImage ?? image
    }

    /// Hard threshold using `CIColorThreshold` (iOS 17+).
    private func applyThreshold(to image: CIImage, threshold: Double) -> CIImage? {
        if #available(iOS 17.0, *) {
            let filter = CIFilter.colorThreshold()
            filter.inputImage = image
            filter.threshold = Float(threshold)
            return filter.outputImage
        }
        // Fallback (unused at our 17+ deployment target): clamp manually via
        // a color matrix sweep — approximates threshold but is not exact.
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        let strength = Float(1.0 / max(0.001, 1.0 - threshold))
        matrix.rVector = CIVector(x: CGFloat(strength), y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: CGFloat(strength), z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(strength), w: 0)
        matrix.biasVector = CIVector(
            x: CGFloat(-Float(threshold) * strength),
            y: CGFloat(-Float(threshold) * strength),
            z: CGFloat(-Float(threshold) * strength),
            w: 0
        )
        return matrix.outputImage
    }

    /// Recolor only the dark pixels with `rgb`, leaving the white background
    /// alone. Implemented with a custom `CIColorKernel` so the math runs on
    /// GPU in a single pass.
    private func tintBlackLines(in image: CIImage, rgb: (r: Double, g: Double, b: Double)) -> CIImage? {
        guard let kernel = Self.tintKernel else { return image }
        let arguments: [Any] = [
            image,
            CIVector(x: CGFloat(rgb.r), y: CGFloat(rgb.g), z: CGFloat(rgb.b), w: 1)
        ]
        return kernel.apply(extent: image.extent, arguments: arguments)
    }

    private static let tintKernel: CIColorKernel? = {
        let source = """
            kernel vec4 tintBlack(__sample s, vec4 tint) {
                float gray = (s.r + s.g + s.b) / 3.0;
                vec3 outColor = mix(tint.rgb, vec3(1.0), gray);
                return vec4(outColor, s.a);
            }
        """
        return CIColorKernel(source: source)
    }()
}
