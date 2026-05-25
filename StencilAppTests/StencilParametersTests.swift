import XCTest
@testable import StencilApp

final class StencilParametersTests: XCTestCase {

    func testValidateAllowsTechnicalTraceOnApiTiers() throws {
        for tier in ModelTier.allCases where tier != .nano {
            var params = StencilParameters.default
            params.tier = tier
            params.promptMode = .technical_trace
            XCTAssertNoThrow(try params.validate(),
                             "\(tier) + technical_trace should be valid")
        }
    }

    func testValidateRejectsTechnicalTraceOnNano() {
        var params = StencilParameters.default
        params.tier = .nano
        params.promptMode = .technical_trace
        XCTAssertThrowsError(try params.validate()) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(
                message.lowercased().contains("technical trace"),
                "Error should mention 'Technical Trace' — got: \(message)"
            )
        }
    }

    func testValidateAllowsStandardOnAnyTier() throws {
        for tier in ModelTier.allCases {
            var params = StencilParameters.default
            params.tier = tier
            params.promptMode = .standard
            XCTAssertNoThrow(try params.validate(),
                             "\(tier) + standard should always be valid")
        }
    }

    func testDefaultParametersAreServerDefaults() {
        let defaults = StencilParameters.default
        XCTAssertEqual(defaults.estilo, .fine_line)
        XCTAssertEqual(defaults.grosorLinea, 2)
        XCTAssertEqual(defaults.contraste, 5)
        XCTAssertEqual(defaults.tier, .flash)
        XCTAssertEqual(defaults.resolution, .p4K)
        XCTAssertEqual(defaults.promptMode, .standard)
    }
}
