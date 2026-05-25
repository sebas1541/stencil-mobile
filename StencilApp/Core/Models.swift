import Foundation

// MARK: - Enums (mirror app/models.py)

enum StyleName: String, CaseIterable, Codable, Identifiable, Hashable {
    case realismo
    case black_grey
    case tradicional
    case neotradicional
    case blackwork
    case fine_line
    case minimalista
    case japones
    case acuarela
    case puntillismo
    case geometrico
    case trash_polka
    case biomecanico
    case new_school
    case lettering

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realismo:       return "Realismo"
        case .black_grey:     return "Black & Grey"
        case .tradicional:    return "Tradicional"
        case .neotradicional: return "Neotradicional"
        case .blackwork:      return "Blackwork"
        case .fine_line:      return "Fine Line"
        case .minimalista:    return "Minimalista"
        case .japones:        return "Japonés"
        case .acuarela:       return "Acuarela"
        case .puntillismo:    return "Puntillismo"
        case .geometrico:     return "Geométrico"
        case .trash_polka:    return "Trash Polka"
        case .biomecanico:    return "Biomecánico"
        case .new_school:     return "New School"
        case .lettering:      return "Lettering"
        }
    }
}

enum ModelTier: String, CaseIterable, Codable, Identifiable, Hashable {
    case nano
    case flash
    case pro
    case gpt_mini
    case gpt_flash
    case gpt_pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nano:      return "Veca Nano"
        case .flash:     return "Veca Flash"
        case .pro:       return "Veca Pro"
        case .gpt_mini:  return "Calisto Mini"
        case .gpt_flash: return "Calisto Flash"
        case .gpt_pro:   return "Calisto Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .nano:      return "OpenCV local · Free"
        case .flash:     return "Gemini 3.1 Flash · ~$0.07–$0.15"
        case .pro:       return "Gemini 3 Pro · ~$0.14 (4K ~$0.24)"
        case .gpt_mini:  return "gpt-image-1-mini · from ~$0.006"
        case .gpt_flash: return "gpt-image-1.5 · from ~$0.013"
        case .gpt_pro:   return "gpt-image-2 · token-metered"
        }
    }

    /// Whether the tier requires the prompt_mode to be `standard`
    /// (technical_trace is rejected for nano).
    var supportsTechnicalTrace: Bool { self != .nano }

    /// Whether the tier consumes any image-generation API quota.
    var isLocal: Bool { self == .nano }
}

enum Resolution: String, CaseIterable, Codable, Identifiable, Hashable {
    case p1080 = "1080p"
    case p2K   = "2K"
    case p4K   = "4K"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var pixelDescription: String {
        switch self {
        case .p1080: return "1920 × 1080"
        case .p2K:   return "2560 × 1440"
        case .p4K:   return "3840 × 2160"
        }
    }
}

enum PromptMode: String, Codable, Hashable {
    case standard
    case technical_trace
}

// MARK: - prompt_config sub-enums (string-typed in the API)

enum Thickness: String, CaseIterable, Identifiable, Hashable {
    case fino = "Fino"
    case medio = "Medio"
    case grueso = "Grueso"
    var id: String { rawValue }
}

enum ShadowDetail: String, CaseIterable, Identifiable, Hashable {
    case breve = "Breve"
    case medio = "Medio"
    case detallado = "Detallado"
    case superDetallado = "Súper Detallado"
    var id: String { rawValue }
}

enum ShadowWeight: String, CaseIterable, Identifiable, Hashable {
    case muySuave = "Muy Suave"
    case suave    = "Suave"
    case notable  = "Notable"
    var id: String { rawValue }
}

enum TextureLevel: String, CaseIterable, Identifiable, Hashable {
    case bajo  = "Bajo (Limpio)"
    case medio = "Medio"
    case alto  = "Alto (Detallado)"
    var id: String { rawValue }
}

// MARK: - PromptConfig payload

struct PromptConfig: Codable, Hashable {
    var uiBackground: Bool        = true
    var uiThickness: String       = Thickness.medio.rawValue
    var uiShadowsEnabled: Bool    = false
    var uiShadowDetail: String    = ShadowDetail.detallado.rawValue
    var uiShadowWeight: String    = ShadowWeight.suave.rawValue
    var uiTextureLevel: String    = TextureLevel.bajo.rawValue

    enum CodingKeys: String, CodingKey {
        case uiBackground      = "ui_background"
        case uiThickness       = "ui_thickness"
        case uiShadowsEnabled  = "ui_shadows_enabled"
        case uiShadowDetail    = "ui_shadow_detail"
        case uiShadowWeight    = "ui_shadow_weight"
        case uiTextureLevel    = "ui_texture_level"
    }
}

// MARK: - /stencil request + response

struct StencilRequest: Codable {
    let requestId: String        // UUID v4
    let s3Key: String
    let estilo: StyleName
    let grosorLinea: Int         // 1..5, only used by `nano`
    let contraste: Int           // 1..10, only used by `nano`
    let tier: ModelTier
    let resolution: Resolution
    let promptMode: PromptMode
    let promptConfig: PromptConfig

    enum CodingKeys: String, CodingKey {
        case requestId    = "request_id"
        case s3Key        = "s3_key"
        case estilo
        case grosorLinea  = "grosor_linea"
        case contraste
        case tier
        case resolution
        case promptMode   = "prompt_mode"
        case promptConfig = "prompt_config"
    }
}

struct UsageRecord: Codable, Hashable {
    let requestId: String
    let tier: String
    let geminiCalls: Int
    let inputMpx: Double
    let outputResolution: String
    let processingTimeMs: Int
    let success: Bool
    let resolutionWarning: Bool

    enum CodingKeys: String, CodingKey {
        case requestId         = "request_id"
        case tier
        case geminiCalls       = "gemini_calls"
        case inputMpx          = "input_mpx"
        case outputResolution  = "output_resolution"
        case processingTimeMs  = "processing_time_ms"
        case success
        case resolutionWarning = "resolution_warning"
    }
}

struct StencilResponse: Codable {
    let stencilUrl: String
    let previewUrl: String
    let formato: String
    let contentType: String
    let contentConfidence: Double
    let usage: UsageRecord

    enum CodingKeys: String, CodingKey {
        case stencilUrl        = "stencil_url"
        case previewUrl        = "preview_url"
        case formato
        case contentType       = "content_type"
        case contentConfidence = "content_confidence"
        case usage
    }
}

// MARK: - /presigned-upload request + response

struct PresignedUploadRequest: Codable {
    let filename: String
}

struct PresignedUploadResponse: Codable {
    let uploadUrl: String
    let s3Key: String

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case s3Key     = "s3_key"
    }
}

// MARK: - Client-side limits

enum APILimits {
    /// Server rejects > 15 MB. Enforce client-side first.
    static let maxImageBytes: Int = 15 * 1024 * 1024
}

// MARK: - Cost table (display-only; matches frontend/app.py)

enum CostTable {
    /// Output cost in USD for the main generation call.
    static func estimate(tier: ModelTier, resolution: Resolution) -> Double {
        switch (tier, resolution) {
        case (.nano, _):       return 0
        case (.flash, .p1080): return 0.067
        case (.flash, .p2K):   return 0.101
        case (.flash, .p4K):   return 0.151
        case (.pro, .p1080):   return 0.135
        case (.pro, .p2K):     return 0.135
        case (.pro, .p4K):     return 0.241
        case (.gpt_mini, _):   return 0.006
        case (.gpt_flash, _):  return 0.013
        case (.gpt_pro, _):    return 0.050
        }
    }

    /// Returns a UX-friendly cost label.
    static func label(tier: ModelTier, resolution: Resolution) -> String {
        let cost = estimate(tier: tier, resolution: resolution)
        if tier == .nano { return "Free" }
        let prefix = (tier == .gpt_mini || tier == .gpt_flash || tier == .gpt_pro)
            ? "from ~"
            : "~"
        return "\(prefix)$\(String(format: "%.3f", cost)) / image"
    }
}
