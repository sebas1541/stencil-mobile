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

    // Services
    private let service: StencilService

    init(service: StencilService = StencilService()) {
        self.service = service
    }

    // MARK: - Derived

    var canGenerate: Bool {
        sourceImage != nil && !phase.isGenerating
    }

    var costLabel: String {
        CostTable.label(tier: parameters.tier, resolution: parameters.resolution)
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

        guard let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData() else {
            phase = .failed("Could not encode the source image.")
            return
        }

        phase = .generating
        let filename = sourceFilename ?? "reference.jpg"
        let parameters = self.parameters

        Task { [service] in
            do {
                let response = try await service.generate(
                    imageData: data,
                    filename: filename,
                    params: parameters
                )
                await MainActor.run {
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
    }
}
