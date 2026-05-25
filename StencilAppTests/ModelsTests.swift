import XCTest
@testable import StencilApp

final class ModelsTests: XCTestCase {

    // MARK: - PromptConfig snake-case round trip

    func testPromptConfigEncodesSnakeCaseKeys() throws {
        let config = PromptConfig(
            uiBackground: false,
            uiThickness: "Grueso",
            uiShadowsEnabled: true,
            uiShadowDetail: "Súper Detallado",
            uiShadowWeight: "Notable",
            uiTextureLevel: "Alto (Detallado)"
        )
        let data = try JSONEncoder().encode(config)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["ui_background"] as? Bool, false)
        XCTAssertEqual(json["ui_thickness"] as? String, "Grueso")
        XCTAssertEqual(json["ui_shadows_enabled"] as? Bool, true)
        XCTAssertEqual(json["ui_shadow_detail"] as? String, "Súper Detallado")
        XCTAssertEqual(json["ui_shadow_weight"] as? String, "Notable")
        XCTAssertEqual(json["ui_texture_level"] as? String, "Alto (Detallado)")
    }

    func testPromptConfigDefaultsMatchServerDefaults() {
        let defaults = PromptConfig()
        XCTAssertEqual(defaults.uiBackground, true)
        XCTAssertEqual(defaults.uiThickness, "Medio")
        XCTAssertEqual(defaults.uiShadowsEnabled, false)
        XCTAssertEqual(defaults.uiShadowDetail, "Detallado")
        XCTAssertEqual(defaults.uiShadowWeight, "Suave")
        XCTAssertEqual(defaults.uiTextureLevel, "Bajo (Limpio)")
    }

    // MARK: - StencilRequest wire format

    func testStencilRequestEncodesSnakeCaseTopLevelKeys() throws {
        let request = StencilRequest(
            requestId: "00000000-0000-0000-0000-000000000000",
            s3Key: "inputs/abc.jpg",
            estilo: .fine_line,
            grosorLinea: 3,
            contraste: 7,
            tier: .flash,
            resolution: .p4K,
            promptMode: .standard,
            promptConfig: PromptConfig()
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["request_id"] as? String, "00000000-0000-0000-0000-000000000000")
        XCTAssertEqual(json["s3_key"] as? String, "inputs/abc.jpg")
        XCTAssertEqual(json["estilo"] as? String, "fine_line")
        XCTAssertEqual(json["grosor_linea"] as? Int, 3)
        XCTAssertEqual(json["contraste"] as? Int, 7)
        XCTAssertEqual(json["tier"] as? String, "flash")
        XCTAssertEqual(json["resolution"] as? String, "4K")
        XCTAssertEqual(json["prompt_mode"] as? String, "standard")
        XCTAssertNotNil(json["prompt_config"])
    }

    // MARK: - StencilResponse decoding

    func testStencilResponseDecodesServerPayload() throws {
        let payload = """
        {
          "stencil_url": "https://example.com/stencil.png",
          "preview_url": "https://example.com/preview.webp",
          "formato": "PNG",
          "content_type": "portrait",
          "content_confidence": 0.91,
          "usage": {
            "request_id": "abcd1234-0000-0000-0000-000000000000",
            "tier": "flash",
            "gemini_calls": 2,
            "input_mpx": 3.21,
            "output_resolution": "4K",
            "processing_time_ms": 4123,
            "success": true,
            "resolution_warning": false
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(StencilResponse.self, from: payload)
        XCTAssertEqual(response.stencilUrl, "https://example.com/stencil.png")
        XCTAssertEqual(response.previewUrl, "https://example.com/preview.webp")
        XCTAssertEqual(response.formato, "PNG")
        XCTAssertEqual(response.contentType, "portrait")
        XCTAssertEqual(response.contentConfidence, 0.91, accuracy: 0.0001)
        XCTAssertEqual(response.usage.tier, "flash")
        XCTAssertEqual(response.usage.geminiCalls, 2)
        XCTAssertEqual(response.usage.processingTimeMs, 4123)
        XCTAssertFalse(response.usage.resolutionWarning)
    }

    // MARK: - Enum coverage

    func testStyleNameCoversAllServerStyles() {
        let expected: Set<String> = [
            "realismo", "black_grey", "tradicional", "neotradicional",
            "blackwork", "fine_line", "minimalista", "japones", "acuarela",
            "puntillismo", "geometrico", "trash_polka", "biomecanico",
            "new_school", "lettering"
        ]
        let actual = Set(StyleName.allCases.map(\.rawValue))
        XCTAssertEqual(actual, expected)
    }

    func testModelTierCoversAllSixTiers() {
        let expected: Set<String> = [
            "nano", "flash", "pro", "gpt_mini", "gpt_flash", "gpt_pro"
        ]
        let actual = Set(ModelTier.allCases.map(\.rawValue))
        XCTAssertEqual(actual, expected)
    }

    func testResolutionOmits6K() {
        // The API rejects 6K (Python upscaling disabled); we must not show
        // it as an option.
        let raw = ModelTier.allCases.map(\.rawValue)
        XCTAssertFalse(raw.contains("6K"))
        XCTAssertEqual(Resolution.allCases.count, 3)
    }

    // MARK: - Tier capabilities

    func testNanoIsTheOnlyLocalTier() {
        for tier in ModelTier.allCases {
            XCTAssertEqual(tier.isLocal, tier == .nano,
                           "isLocal should be true exclusively for .nano (got \(tier))")
        }
    }

    func testTechnicalTraceUnsupportedOnNano() {
        XCTAssertFalse(ModelTier.nano.supportsTechnicalTrace)
        for tier in ModelTier.allCases where tier != .nano {
            XCTAssertTrue(tier.supportsTechnicalTrace,
                           "\(tier) should support technical_trace")
        }
    }

    // MARK: - CostTable

    func testCostTableAllZeroForNano() {
        for res in Resolution.allCases {
            XCTAssertEqual(CostTable.estimate(tier: .nano, resolution: res), 0)
        }
        XCTAssertEqual(CostTable.label(tier: .nano, resolution: .p4K), "Free")
    }

    func testCostTableProHas4KBump() {
        let cost1080 = CostTable.estimate(tier: .pro, resolution: .p1080)
        let cost4K   = CostTable.estimate(tier: .pro, resolution: .p4K)
        XCTAssertGreaterThan(cost4K, cost1080)
    }

    func testCostLabelUsesFromPrefixForGptTiers() {
        let label = CostTable.label(tier: .gpt_flash, resolution: .p4K)
        XCTAssertTrue(label.contains("from"), "GPT tiers should be labelled as a floor")
    }

    func testCostLabelUsesTildeForGeminiTiers() {
        let label = CostTable.label(tier: .flash, resolution: .p2K)
        XCTAssertTrue(label.contains("~"), "Gemini tier label should start with ~")
        XCTAssertFalse(label.lowercased().contains("from"),
                       "Gemini tier label should not say 'from'")
    }
}
