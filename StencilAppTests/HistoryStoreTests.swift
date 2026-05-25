import XCTest
@testable import StencilApp

@MainActor
final class HistoryStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Each test gets its own isolated UserDefaults so persistence is
        // sandboxed and order-independent.
        let suiteName = "stencil.history.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
        defaults = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func makeParameters(tier: ModelTier = .flash) -> StencilParameters {
        StencilParameters(
            requestId: UUID(),
            estilo: .fine_line,
            grosorLinea: 2,
            contraste: 5,
            tier: tier,
            resolution: .p4K,
            promptMode: .standard,
            promptConfig: PromptConfig()
        )
    }

    private func makeResponse(tier: ModelTier = .flash,
                              processingTimeMs: Int = 4000) -> StencilResponse {
        StencilResponse(
            stencilUrl: "https://example.com/stencil.png",
            previewUrl: "https://example.com/preview.webp",
            formato: "PNG",
            contentType: "portrait",
            contentConfidence: 0.9,
            usage: UsageRecord(
                requestId: UUID().uuidString,
                tier: tier.rawValue,
                geminiCalls: 2,
                inputMpx: 3.21,
                outputResolution: "4K",
                processingTimeMs: processingTimeMs,
                success: true,
                resolutionWarning: false
            )
        )
    }

    // MARK: - Tests

    func testRecordPrependsEntry() {
        let store = HistoryStore(defaults: defaults)
        XCTAssertTrue(store.entries.isEmpty)

        let params = makeParameters()
        let response = makeResponse()
        store.record(parameters: params, response: response)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.id, params.requestId)
    }

    func testRecordDedupesByRequestId() {
        let store = HistoryStore(defaults: defaults)
        let params = makeParameters()
        store.record(parameters: params, response: makeResponse(processingTimeMs: 1000))
        store.record(parameters: params, response: makeResponse(processingTimeMs: 9000))

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.processingTimeMs, 9000,
                       "The second record() should replace the first when request_id matches")
    }

    func testRecordCapsAtMaxEntries() {
        let store = HistoryStore(defaults: defaults)
        for _ in 0..<(HistoryStore.maxEntries + 5) {
            store.record(parameters: makeParameters(), response: makeResponse())
        }
        XCTAssertEqual(store.entries.count, HistoryStore.maxEntries)
    }

    func testPersistAndReload() {
        let storeA = HistoryStore(defaults: defaults)
        let params = makeParameters(tier: .gpt_pro)
        storeA.record(parameters: params, response: makeResponse(tier: .gpt_pro))

        let storeB = HistoryStore(defaults: defaults)
        XCTAssertEqual(storeB.entries.count, 1)
        XCTAssertEqual(storeB.entries.first?.tier, .gpt_pro)
    }

    func testClearWipesEntries() {
        let store = HistoryStore(defaults: defaults)
        store.record(parameters: makeParameters(), response: makeResponse())
        store.record(parameters: makeParameters(), response: makeResponse())
        XCTAssertEqual(store.entries.count, 2)

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)

        // Re-instantiating from the same defaults must reflect the clear.
        let reloaded = HistoryStore(defaults: defaults)
        XCTAssertTrue(reloaded.entries.isEmpty)
    }

    func testRemoveById() {
        let store = HistoryStore(defaults: defaults)
        let params = makeParameters()
        store.record(parameters: params, response: makeResponse())
        store.record(parameters: makeParameters(), response: makeResponse())

        store.remove(id: params.requestId)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries.contains { $0.id == params.requestId })
    }
}
