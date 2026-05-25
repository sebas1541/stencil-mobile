import Foundation
import UniformTypeIdentifiers

/// High-level orchestration of the two-step generation flow:
///   1. `POST /presigned-upload` → returns S3 PUT URL + s3_key
///   2. PUT the bytes to S3
///   3. `POST /stencil` with the s3_key → returns presigned download URLs
struct StencilService {
    let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    /// Full upload + generation in one call.
    func generate(
        imageData: Data,
        filename: String,
        params: StencilParameters
    ) async throws -> StencilResponse {
        guard imageData.count <= APILimits.maxImageBytes else {
            throw APIError.imageTooLarge(bytes: imageData.count)
        }

        // 1. Presigned upload
        let presign = try await client.post(
            "/presigned-upload",
            body: PresignedUploadRequest(filename: filename),
            as: PresignedUploadResponse.self
        )

        // 2. PUT to S3
        guard let url = URL(string: presign.uploadUrl) else {
            throw APIError.missingURL
        }
        let contentType = Self.mimeType(for: filename)
        try await client.put(data: imageData, to: url, contentType: contentType)

        // 3. Generate
        let request = StencilRequest(
            requestId:    params.requestId.uuidString.lowercased(),
            s3Key:        presign.s3Key,
            estilo:       params.estilo,
            grosorLinea:  params.grosorLinea,
            contraste:    params.contraste,
            tier:         params.tier,
            resolution:   params.resolution,
            promptMode:   params.promptMode,
            promptConfig: params.promptConfig
        )
        return try await client.post("/stencil", body: request, as: StencilResponse.self)
    }

    /// Best-effort MIME lookup from filename extension.
    static func mimeType(for filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension.lowercased()
        if let type = UTType(filenameExtension: ext), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}

/// User-facing collection of fields the editor screen builds up before tapping
/// Generate. Decoupled from `StencilRequest` so we can pre-validate without
/// needing the s3_key yet.
struct StencilParameters {
    var requestId: UUID
    var estilo: StyleName
    var grosorLinea: Int
    var contraste: Int
    var tier: ModelTier
    var resolution: Resolution
    var promptMode: PromptMode
    var promptConfig: PromptConfig

    static let `default` = StencilParameters(
        requestId:    UUID(),
        estilo:       .fine_line,
        grosorLinea:  2,
        contraste:    5,
        tier:         .flash,
        resolution:   .p4K,
        promptMode:   .standard,
        promptConfig: PromptConfig()
    )

    /// Client-side validation rules mirroring `/stencil`'s server rejects.
    func validate() throws {
        if promptMode == .technical_trace && tier == .nano {
            throw APIError.other(
                "Technical Trace requires an API tier. Pick Veca Flash/Pro or Calisto."
            )
        }
    }
}
