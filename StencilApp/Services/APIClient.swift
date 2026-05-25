import Foundation

/// Strongly-typed errors surfaced to the UI layer.
enum APIError: LocalizedError {
    case invalidBaseURL
    case missingURL
    case http(status: Int, body: String?)
    case transport(underlying: Error)
    case decoding(underlying: Error)
    case imageTooLarge(bytes: Int)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The configured API base URL is not a valid URL."
        case .missingURL:
            return "The request URL is missing."
        case let .http(status, body):
            if let body, !body.isEmpty {
                return "Server returned HTTP \(status): \(body)"
            }
            return "Server returned HTTP \(status)."
        case let .transport(error):
            return "Network error: \(error.localizedDescription)"
        case let .decoding(error):
            return "Response decoding failed: \(error.localizedDescription)"
        case let .imageTooLarge(bytes):
            let mb = Double(bytes) / 1_048_576
            return String(format: "Image is %.1f MB. Max allowed is 15 MB.", mb)
        case let .other(message):
            return message
        }
    }
}

/// Thin wrapper around `URLSession` that injects the base URL and the optional
/// `X-Api-Key` header. Decoding is JSON-based; pass any `Codable` body.
actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Source of the current base URL + api key, refreshed on every call so
    /// that toggling settings doesn't require restarting the app.
    var settingsProvider: @Sendable () -> APISettings = { APISettings.current() }

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func setSettingsProvider(_ provider: @escaping @Sendable () -> APISettings) {
        self.settingsProvider = provider
    }

    // MARK: - High-level helpers

    func get<Response: Decodable>(
        _ path: String,
        as: Response.Type = Response.self
    ) async throws -> Response {
        let request = try buildRequest(path: path, method: "GET", body: Optional<EmptyBody>.none)
        return try await perform(request)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as: Response.Type = Response.self
    ) async throws -> Response {
        let request = try buildRequest(path: path, method: "POST", body: body)
        return try await perform(request)
    }

    /// Raw PUT used for S3 presigned uploads. Note: bypasses the base URL and
    /// the `X-Api-Key` header — the presigned URL already encodes auth.
    func put(data: Data, to url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (responseData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.other("Unexpected non-HTTP response from S3")
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: responseData, encoding: .utf8)
                throw APIError.http(status: http.statusCode, body: body)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(underlying: error)
        }
    }

    // MARK: - Internals

    private struct EmptyBody: Encodable {}

    private func buildRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) throws -> URLRequest {
        let settings = settingsProvider()
        guard var base = URL(string: settings.baseURL) else {
            throw APIError.invalidBaseURL
        }
        // Allow `path` to start with "/" or not — normalize.
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        base.append(path: cleaned)

        var request = URLRequest(url: base)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let key = settings.apiKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-Api-Key")
        }

        if let body, !(body is EmptyBody) {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.other("Failed to encode request body: \(error.localizedDescription)")
            }
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.other("Unexpected non-HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.http(status: http.statusCode, body: body)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }
}

// MARK: - APISettings (read from @AppStorage by the UI layer)

struct APISettings: Sendable {
    var baseURL: String
    var apiKey: String?

    static let baseURLKey = "stencil.apiBaseURL"
    static let apiKeyKey  = "stencil.apiKey"
    static let defaultBaseURL = "http://localhost:8000"

    /// Snapshot the current settings from `UserDefaults`. Called on every API
    /// call so changes take effect immediately.
    static func current() -> APISettings {
        let defaults = UserDefaults.standard
        let url = defaults.string(forKey: baseURLKey) ?? defaultBaseURL
        let key = defaults.string(forKey: apiKeyKey)
        return APISettings(baseURL: url, apiKey: key)
    }
}
