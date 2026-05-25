import Foundation
import Observation
import PencilKit
import UIKit

/// Owns all post-generation state: the original stencil, the user's retouch /
/// overlay settings, and the cached rendered images.
///
/// Recomputation happens on a background task that is debounced — every time
/// a slider changes, we cancel the in-flight task and schedule a fresh one
/// shortly after.
@MainActor
@Observable
final class RetouchViewModel {
    // MARK: - Inputs (from caller)

    /// Original stencil PNG bytes downloaded from `response.stencilUrl`.
    /// `nil` until the network fetch completes.
    var stencilImage: UIImage?

    /// The reference photo the user uploaded, kept for the overlay tab.
    let referenceImage: UIImage

    // MARK: - Settings

    var retouchSettings: RetouchSettings = RetouchSettings() {
        didSet { scheduleRetouchRender() }
    }

    var overlaySettings: OverlaySettings = OverlaySettings() {
        didSet { scheduleOverlayRender() }
    }

    // MARK: - Cached outputs

    /// Retouched / colour-swapped stencil — what the Retouch tab shows.
    var retouchedImage: UIImage?

    /// Stencil composited over the (brightness-adjusted) reference photo —
    /// what the Overlay tab shows.
    var overlayImage: UIImage?

    var isRendering: Bool = false

    /// Pencil annotations drawn on top of the retouched stencil. Survives
    /// tab switches because it lives on the view model.
    var annotationDrawing: PKDrawing = PKDrawing()

    /// When `true`, finger input is ignored on the annotation canvas — gives
    /// the artist palm-rest comfort with an Apple Pencil.
    var pencilOnlyDrawing: Bool = true

    // MARK: - Internals

    private let retouchEngine: RetouchEngine
    private let overlayCompositor: OverlayCompositor

    private var retouchTask: Task<Void, Never>?
    private var overlayTask: Task<Void, Never>?

    init(
        referenceImage: UIImage,
        stencilImage: UIImage? = nil,
        retouchEngine: RetouchEngine = RetouchEngine(),
        overlayCompositor: OverlayCompositor = OverlayCompositor()
    ) {
        self.referenceImage = referenceImage
        self.stencilImage = stencilImage
        self.retouchEngine = retouchEngine
        self.overlayCompositor = overlayCompositor
        if stencilImage != nil {
            scheduleRetouchRender()
            scheduleOverlayRender()
        }
    }

    /// Called by the parent view once the API stencil PNG has been downloaded.
    func adoptStencil(_ image: UIImage) {
        self.stencilImage = image
        scheduleRetouchRender()
        scheduleOverlayRender()
    }

    // MARK: - Render scheduling

    private func scheduleRetouchRender() {
        retouchTask?.cancel()
        guard let stencilCG = stencilImage?.cgImage else { return }
        let settings = retouchSettings
        let engine = retouchEngine

        retouchTask = Task { [weak self] in
            // Tiny debounce so dragging a slider doesn't fire a render per pixel.
            try? await Task.sleep(nanoseconds: 30_000_000)
            if Task.isCancelled { return }

            await MainActor.run { self?.isRendering = true }
            let result = engine.apply(settings, to: stencilCG)

            if Task.isCancelled { return }
            await MainActor.run {
                self?.retouchedImage = result
                self?.isRendering = false
                self?.scheduleOverlayRender()
            }
        }
    }

    private func scheduleOverlayRender() {
        overlayTask?.cancel()
        guard let stencilCG = retouchedImage?.cgImage ?? stencilImage?.cgImage,
              let referenceCG = referenceImage.cgImage else { return }
        let settings = overlaySettings
        let ink = retouchSettings.inkColor
        let compositor = overlayCompositor

        overlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000)
            if Task.isCancelled { return }

            let result = compositor.composite(
                reference: referenceCG,
                stencil: stencilCG,
                ink: ink,
                settings: settings
            )
            if Task.isCancelled { return }
            await MainActor.run {
                self?.overlayImage = result
            }
        }
    }

    // MARK: - Export helpers

    /// PNG bytes of the original (un-retouched) stencil downloaded from S3.
    func originalStencilPNG() -> Data? {
        stencilImage?.pngData()
    }

    /// PNG bytes of the current retouched + colour-swapped stencil.
    func retouchedStencilPNG() -> Data? {
        retouchedImage?.pngData() ?? stencilImage?.pngData()
    }

    /// Procreate-friendly PNG: the retouched stencil with the white background
    /// turned transparent. Mirrors `app/pipeline/export.py.export_for_procreate`
    /// — alpha=0 for any pixel where all of R,G,B > 240.
    func procreateTransparentPNG() -> Data? {
        let source = retouchedImage ?? stencilImage
        guard let source, let cg = source.cgImage else { return nil }
        return ProcreateExporter.transparentPNG(from: cg)
    }

    /// Render the current PKDrawing on top of the retouched stencil at the
    /// stencil's native pixel size. Returns `nil` when there's nothing to
    /// export yet.
    func annotatedStencilPNG() -> Data? {
        let base = retouchedImage ?? stencilImage
        guard let base else { return nil }

        // Skip the composite step if the artist hasn't drawn anything.
        if annotationDrawing.bounds.isEmpty {
            return base.pngData()
        }

        let size = base.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let composed = renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            let drawingImage = annotationDrawing.image(
                from: CGRect(origin: .zero, size: size),
                scale: 1
            )
            drawingImage.draw(in: CGRect(origin: .zero, size: size))
        }
        return composed.pngData()
    }

    /// Wipe all pencil strokes — used by the Clear button on the annotation
    /// panel.
    func clearAnnotation() {
        annotationDrawing = PKDrawing()
    }
}
