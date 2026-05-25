import Foundation
import Observation
import SwiftUI

/// Phase of the editor flow. Lives on the view model so the UI can switch
/// between the configure form and the result panel without changing routes.
enum EditorPhase {
    case configure
    case generating
    case result(StencilResponse, sourcePreview: UIImage)
    case failed(String)

    var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
}

/// Single source of truth for the editor screen.
@MainActor
@Observable
final class EditorViewModel {
    // Inputs
    var sourceImage: UIImage?
    var sourceFilename: String?

    var parameters: StencilParameters = .default

    // Flow state
    var phase: EditorPhase = .configure

    /// Created when a generation succeeds. Shared across Refine / Annotate /
    /// Export so the user can flip between sections without losing state.
    var retouchViewModel: RetouchViewModel?

    // Services
    private let service: StencilService
    private let history: HistoryStore

    init(
        service: StencilService = StencilService(),
        history: HistoryStore? = nil
    ) {
        self.service = service
        // Defer `.shared` access to the init body so the default-value
        // expression isn't evaluated outside the MainActor.
        self.history = history ?? HistoryStore.shared
    }

    /// Repopulate the form with a recent entry — keeps the currently-loaded
    /// source image (or none) so the user can re-run with a fresh photo.
    func apply(history entry: GenerationHistoryEntry) {
        parameters = StencilParameters(
            requestId:    UUID(),
            estilo:       entry.estilo,
            grosorLinea:  parameters.grosorLinea,
            contraste:    parameters.contraste,
            tier:         entry.tier,
            resolution:   entry.resolution,
            promptMode:   entry.promptMode,
            promptConfig: entry.promptConfig
        )
        phase = .configure
    }

    // MARK: - Derived

    var canGenerate: Bool {
        sourceImage != nil && !phase.isGenerating
    }

    var costLabel: String {
        CostTable.label(tier: parameters.tier, resolution: parameters.resolution)
    }

    /// Mirrors the server's `resolution_warning` heuristic: low-res source +
    /// high-res target. Lets the editor surface a hint before the round trip.
    var shouldShowLowResolutionWarning: Bool {
        guard let image = sourceImage else { return false }
        let mpx = (image.size.width * image.size.height) / 1_000_000
        return mpx < 1.0
            && parameters.resolution == .p4K
            && parameters.tier != .nano
    }

    // MARK: - Actions

    /// Promote weak shadow controls when the topography toggle is enabled,
    /// mirroring the Gradio behavior in `topography_enabled_changed`.
    func onShadowsToggleChanged(enabled: Bool) {
        guard enabled else { return }
        let detailRank: [String: Int] = [
            ShadowDetail.breve.rawValue: 0,
            ShadowDetail.medio.rawValue: 1,
            ShadowDetail.detallado.rawValue: 2,
            ShadowDetail.superDetallado.rawValue: 3,
        ]
        let weightRank: [String: Int] = [
            ShadowWeight.muySuave.rawValue: 0,
            ShadowWeight.suave.rawValue:    1,
            ShadowWeight.notable.rawValue:  2,
        ]
        if (detailRank[parameters.promptConfig.uiShadowDetail] ?? 0) < (detailRank[ShadowDetail.detallado.rawValue] ?? 0) {
            parameters.promptConfig.uiShadowDetail = ShadowDetail.detallado.rawValue
        }
        if (weightRank[parameters.promptConfig.uiShadowWeight] ?? 0) < (weightRank[ShadowWeight.suave.rawValue] ?? 0) {
            parameters.promptConfig.uiShadowWeight = ShadowWeight.suave.rawValue
        }
    }

    /// If the user switches to `nano`, force prompt_mode back to `.standard`
    /// because the server rejects `technical_trace + nano`.
    func onTierChanged() {
        if parameters.tier == .nano, parameters.promptMode == .technical_trace {
            parameters.promptMode = .standard
        }
    }

    func generate(promptMode: PromptMode) {
        guard let image = sourceImage else { return }
        parameters.requestId = UUID()
        parameters.promptMode = promptMode

        do {
            try parameters.validate()
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            return
        }

        // Encode as JPEG (smaller, server accepts it). Fall back to PNG only
        // if JPEG encoding ever fails — and adjust the filename so the
        // server-side mimetypes.guess_type() returns the right content type.
        let encoded: (data: Data, ext: String)
        if let jpeg = image.jpegData(compressionQuality: 0.92) {
            encoded = (jpeg, "jpg")
        } else if let png = image.pngData() {
            encoded = (png, "png")
        } else {
            phase = .failed("Could not encode the source image.")
            return
        }

        phase = .generating
        // The server uses the filename ONLY to derive the Content-Type via
        // mimetypes.guess_type(). PhotosPickerItem.itemIdentifier is a local
        // identifier like "8F3D2A4E.../L0/001" with no extension, so we
        // override with a consistent filename matching the bytes we encoded.
        let filename = "reference.\(encoded.ext)"
        let data = encoded.data
        let parameters = self.parameters

        Task { [service, history] in
            do {
                let response = try await service.generate(
                    imageData: data,
                    filename: filename,
                    params: parameters
                )
                await MainActor.run {
                    history.record(parameters: parameters, response: response)
                    self.retouchViewModel = RetouchViewModel(referenceImage: image)
                    self.phase = .result(response, sourcePreview: image)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    self.phase = .failed(message)
                }
            }
        }
    }

    func backToConfigure() {
        phase = .configure
        retouchViewModel = nil
    }

    /// Hard reset: clears the loaded image, parameters stay so the user can
    /// quickly re-run with another photo.
    func startOver() {
        sourceImage = nil
        sourceFilename = nil
        retouchViewModel = nil
        parameters.requestId = UUID()
        phase = .configure
    }

#if DEBUG
    /// DEBUG-only: skip the real network round trip and pretend the API
    /// returned a stencil. Uses the loaded photo if available; otherwise
    /// generates a procedural placeholder so the rest of the UI is reachable
    /// in the simulator without spinning up the microservice or even picking
    /// a photo first.
    ///
    /// Wire it up via a long-press on the Generate button.
    func injectMockResult() {
        let image = sourceImage ?? Self.placeholderImage()

        let requestId = UUID()
        let usage = UsageRecord(
            requestId: requestId.uuidString,
            tier: parameters.tier.rawValue,
            geminiCalls: parameters.tier.isLocal ? 1 : 2,
            inputMpx: Double((image.size.width * image.size.height) / 1_000_000),
            outputResolution: parameters.resolution.rawValue,
            processingTimeMs: 1234,
            success: true,
            resolutionWarning: false
        )
        let response = StencilResponse(
            stencilUrl: "about:blank",
            previewUrl: "about:blank",
            formato: "PNG",
            contentType: "portrait",
            contentConfidence: 0.93,
            usage: usage
        )

        // Adopt sourceImage if missing, so Refine has *something* to compare.
        if sourceImage == nil { sourceImage = image }

        let retouch = RetouchViewModel(referenceImage: image)
        retouch.adoptStencil(image)
        self.retouchViewModel = retouch
        history.record(parameters: parameters, response: response)
        phase = .result(response, sourcePreview: image)
    }

    /// Procedural mid-grey image with a simple radial pattern so the user can
    /// at least see the comparison + annotation surfaces working.
    private static func placeholderImage(size: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Background gradient — slate to white.
            let colors = [
                UIColor(white: 0.92, alpha: 1).cgColor,
                UIColor(white: 0.78, alpha: 1).cgColor
            ]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            // Big offset circle so retouching/threshold/dilation actually have
            // an edge to chew on.
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(8)
            let inset = size.width * 0.18
            context.cgContext.strokeEllipse(in: CGRect(x: inset, y: inset,
                                                      width: size.width - inset * 2,
                                                      height: size.height - inset * 2))
            context.cgContext.setLineWidth(3)
            context.cgContext.strokeEllipse(in: CGRect(x: size.width * 0.35,
                                                      y: size.height * 0.35,
                                                      width: size.width * 0.3,
                                                      height: size.height * 0.3))
        }
    }
#endif
}
