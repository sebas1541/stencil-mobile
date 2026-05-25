import Foundation
import Observation

/// One persisted generation: just the parameters and a small bit of result
/// metadata. We do NOT store image bytes — the presigned URLs the API returns
/// expire (1 h by default) and storing the source photos would balloon
/// UserDefaults. Re-running an entry just refills the editor form and the
/// user picks a fresh image.
struct GenerationHistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let estilo: StyleName
    let tier: ModelTier
    let resolution: Resolution
    let promptMode: PromptMode
    let promptConfig: PromptConfig

    /// Optional bits captured after the response comes back — purely
    /// informational, shown as a subtitle in the sidebar row.
    let contentType: String?
    let processingTimeMs: Int?

    var subtitle: String {
        let style = estilo.displayName
        if let contentType, let ms = processingTimeMs {
            return "\(style) · \(contentType) · \(ms) ms"
        }
        return style
    }
}

/// Persists a rolling window of recent generations. Backed by a JSON string
/// in `UserDefaults`. `@Observable` so views update automatically.
@MainActor
@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    /// Cap so UserDefaults stays small — JSON for 20 entries is ~5 KB.
    static let maxEntries: Int = 20

    private(set) var entries: [GenerationHistoryEntry] = []

    private static let storageKey = "stencil.history.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.entries = Self.load(from: defaults)
    }

    // MARK: - Mutations

    func record(parameters: StencilParameters, response: StencilResponse) {
        let entry = GenerationHistoryEntry(
            id: parameters.requestId,
            createdAt: Date(),
            estilo: parameters.estilo,
            tier: parameters.tier,
            resolution: parameters.resolution,
            promptMode: parameters.promptMode,
            promptConfig: parameters.promptConfig,
            contentType: response.contentType,
            processingTimeMs: response.usage.processingTimeMs
        )
        var next = entries
        next.removeAll { $0.id == entry.id }    // dedupe by request id
        next.insert(entry, at: 0)
        if next.count > Self.maxEntries {
            next = Array(next.prefix(Self.maxEntries))
        }
        entries = next
        persist()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            // Persistence is best-effort — log to console so a debug build
            // can surface bugs, but never crash the app over UserDefaults.
            print("HistoryStore: failed to persist — \(error)")
        }
    }

    private static func load(from defaults: UserDefaults) -> [GenerationHistoryEntry] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([GenerationHistoryEntry].self, from: data)
        } catch {
            print("HistoryStore: failed to decode — \(error)")
            return []
        }
    }
}
