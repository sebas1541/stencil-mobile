import SwiftUI
import UIKit

/// Three downloads — the original stencil, the retouched/colour-swapped
/// version, and the Procreate-friendly transparent PNG (white → alpha).
struct ExportPanel: View {
    @Bindable var viewModel: RetouchViewModel
    let response: StencilResponse

    @State private var shareItem: ShareItem?
    @State private var saveMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            previewCard
            exportButtons
            informationCard
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Current export")
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppColor.canvasBackground)
                if let image = viewModel.retouchedImage ?? viewModel.stencilImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(Spacing.md)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .liquidGlassCard()
        }
    }

    // MARK: - Buttons

    private var exportButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Download")

            VStack(spacing: Spacing.sm) {
                exportRow(
                    title: "Original stencil (PNG)",
                    subtitle: "Provider-native bytes returned by the API, untouched.",
                    icon: "doc.on.doc",
                    action: { share(.original) }
                )
                exportRow(
                    title: "Retouched stencil (PNG)",
                    subtitle: "Current retouch settings + line colour baked in.",
                    icon: "wand.and.stars.inverse",
                    action: { share(.retouched) }
                )
                exportRow(
                    title: "Procreate transparent (PNG)",
                    subtitle: "White background turned into alpha — drop directly into Procreate layers.",
                    icon: "square.dashed.inset.filled",
                    action: { share(.procreate) }
                )
            }

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(saveMessage.lowercased().contains("error") ? AppColor.danger : .secondary)
            }
        }
    }

    @ViewBuilder
    private func exportRow(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .liquidGlassCard(cornerRadius: Radius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Information card

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Procreate PSD layers")
            Text("Multi-layer PSD export needs a dedicated server endpoint. It's listed in the project roadmap and will ship once the microservice exposes `POST /procreate-layers`.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(cornerRadius: Radius.md)
        }
    }

    // MARK: - Sharing

    private enum ExportKind {
        case original, retouched, procreate
    }

    private func share(_ kind: ExportKind) {
        saveMessage = nil
        guard let (data, suffix) = bytes(for: kind) else {
            saveMessage = "Stencil isn't ready yet — wait a moment and try again."
            return
        }
        do {
            let id = response.usage.requestId.prefix(8)
            let filename = "stencil_\(id)_\(suffix).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            saveMessage = "Error writing temp file: \(error.localizedDescription)"
        }
    }

    private func bytes(for kind: ExportKind) -> (Data, String)? {
        switch kind {
        case .original:  return viewModel.originalStencilPNG().map { ($0, "original") }
        case .retouched: return viewModel.retouchedStencilPNG().map { ($0, "retouched") }
        case .procreate: return viewModel.procreateTransparentPNG().map { ($0, "procreate") }
        }
    }
}

// MARK: - Share sheet wrapper

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
