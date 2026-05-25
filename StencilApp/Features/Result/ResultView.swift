import SwiftUI

/// Post-generation view. v1: preview + metadata; retouching + export ship in
/// a later commit.
struct ResultView: View {
    let response: StencilResponse
    let source: UIImage
    let onBack: () -> Void

    @State private var loadedPreview: UIImage?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                comparison
                usageGrid
                placeholder
            }
            .padding(Spacing.xl)
        }
        .task { await loadPreview() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stencil ready")
                    .font(.title2.weight(.semibold))
                Text("\(response.usage.tier) · \(response.usage.outputResolution) · \(response.usage.processingTimeMs) ms")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onBack) {
                Label("New stencil", systemImage: "arrow.uturn.backward")
            }
            .liquidGlassButton(.subtle)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Before / after")
            HStack(spacing: Spacing.md) {
                imageTile(label: "Source", image: source)
                imageTile(label: "Stencil", image: loadedPreview)
            }
        }
    }

    private var usageGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Details")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: Spacing.md)],
                alignment: .leading,
                spacing: Spacing.md
            ) {
                kpi(title: "Detected content",
                    value: "\(response.contentType) (\(Int(response.contentConfidence * 100))%)")
                kpi(title: "Source size",
                    value: String(format: "%.2f Mpx", response.usage.inputMpx))
                kpi(title: "Gemini calls",
                    value: "\(response.usage.geminiCalls)")
                kpi(title: "Output format",
                    value: response.formato)
                if response.usage.resolutionWarning {
                    kpi(title: "Warning",
                        value: "Low-res source for \(response.usage.outputResolution)",
                        warning: true)
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Coming next")
            Text("Retouching tools (threshold, line thickness, denoise, close gaps, smooth, sharpen, invert, color swap), the reference overlay, and the Procreate exports will land in the next commit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(cornerRadius: Radius.md)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func imageTile(label: String, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppColor.canvasBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(Spacing.sm)
                } else if loadError == nil {
                    ProgressView()
                } else {
                    Text(loadError ?? "")
                        .font(.caption)
                        .foregroundStyle(AppColor.danger)
                        .padding(Spacing.md)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .liquidGlassCard()
        }
    }

    @ViewBuilder
    private func kpi(title: String, value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(warning ? AppColor.danger : .primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    // MARK: - Networking

    private func loadPreview() async {
        guard loadedPreview == nil else { return }
        guard let url = URL(string: response.previewUrl) else {
            loadError = "Invalid preview URL"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                loadedPreview = image
            } else {
                loadError = "Could not decode preview"
            }
        } catch {
            loadError = "Failed to load preview: \(error.localizedDescription)"
        }
    }
}
