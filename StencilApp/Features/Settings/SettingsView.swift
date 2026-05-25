import SwiftUI

/// API base URL + optional X-Api-Key. Persisted via `@AppStorage` so changes
/// take effect on the next request without a restart.
struct SettingsView: View {
    @AppStorage(APISettings.baseURLKey) private var baseURL: String = APISettings.defaultBaseURL
    @AppStorage(APISettings.apiKeyKey)  private var apiKey: String  = ""

    @State private var probeMessage: String?
    @State private var isProbing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                serverSection
                authSection
                probeSection
                aboutSection
            }
            .padding(Spacing.xl)
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Server")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Base URL")
                    .font(AppFont.bodyEmphasis)
                TextField("http://localhost:8000", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(AppColor.secondaryBackground)
                    )
                Text("Where the FastAPI microservice is reachable. For local docker-compose this is `http://localhost:8000`. On a real iPad, use your machine's LAN IP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Authentication")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("X-Api-Key (optional)")
                    .font(AppFont.bodyEmphasis)
                SecureField("Leave empty if the server has no API_KEY", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(AppColor.secondaryBackground)
                    )
                Text("Required only when the server has `API_KEY` configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    private var probeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Connection")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    Task { await probeHealth() }
                } label: {
                    Label("Test /health", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButton(.subtle)
                .disabled(isProbing)

                if let probeMessage {
                    Text(probeMessage)
                        .font(.footnote)
                        .foregroundStyle(probeMessage.lowercased().contains("ok") ? .secondary : AppColor.danger)
                }
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "About")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Stencil")
                    .font(.headline)
                Text("v0.1.0 — iPad/iPhone client for the stencil microservice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    // MARK: - Probe

    private func probeHealth() async {
        isProbing = true
        defer { isProbing = false }
        probeMessage = nil

        guard let url = URL(string: baseURL)?.appending(path: "health") else {
            probeMessage = "Invalid base URL"
            return
        }
        do {
            var request = URLRequest(url: url)
            if !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                probeMessage = "OK · \(body)"
            } else if let http = response as? HTTPURLResponse {
                probeMessage = "Server returned HTTP \(http.statusCode)"
            } else {
                probeMessage = "Unexpected response"
            }
        } catch {
            probeMessage = "Failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView().navigationTitle("Settings")
    }
}
