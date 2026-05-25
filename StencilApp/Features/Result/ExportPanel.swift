import SwiftUI
import UIKit

/// Three-column export workspace. Big current-export preview on the left,
/// four export options in the middle (original, retouched, Procreate
/// transparent, annotated composite), and recent exports + metadata on the
/// right.
struct ExportPanel: View {
    @Bindable var viewModel: RetouchViewModel
    let response: StencilResponse

    @State private var shareItem: ShareItem?
    @State private var saveMessage: String?
    @State private var recentExports: [RecentExport] = []

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            stackedLayout
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Wide (iPad)

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            previewColumn
                .frame(maxWidth: .infinity)
            exportRowsColumn
                .frame(width: 380)
            recentColumn
                .frame(width: 260)
        }
    }

    // MARK: - Stacked (iPhone)

    private var stackedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                previewColumn
                    .frame(height: 320)
                exportRowsColumn
                recentColumn
            }
        }
    }

    // MARK: - Preview column

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Current export")
            GlassImagePreview(
                image: viewModel.retouchedImage ?? viewModel.stencilImage,
                height: 520
            )
        }
    }

    // MARK: - Export rows

    private var exportRowsColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Download")
            VStack(spacing: Spacing.sm) {
                exportRow(
                    title: "Original stencil (PNG)",
                    subtitle: "Provider-native bytes returned by the API.",
                    icon: "doc.on.doc",
                    onShare: { share(.original) },
                    onSave:  { saveToPhotos(.original) }
                )
                exportRow(
                    title: "Retouched stencil (PNG)",
                    subtitle: "Current retouch + line colour baked in.",
                    icon: "wand.and.stars.inverse",
                    onShare: { share(.retouched) },
                    onSave:  { saveToPhotos(.retouched) }
                )
                exportRow(
                    title: "Procreate transparent (PNG)",
                    subtitle: "White → alpha. Drop into Procreate layers.",
                    icon: "square.dashed.inset.filled",
                    onShare: { share(.procreate) },
                    onSave:  { saveToPhotos(.procreate) }
                )
                exportRow(
                    title: "Annotated stencil (PNG)",
                    subtitle: "Composites your Pencil strokes on top.",
                    icon: "pencil.tip.crop.circle",
                    onShare: { share(.annotated) },
                    onSave:  { saveToPhotos(.annotated) }
                )
            }

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(
                        saveMessage.lowercased().contains("error") ? AppColor.danger : .secondary
                    )
            }
        }
    }

    @ViewBuilder
    private func exportRow(
        title: String,
        subtitle: String,
        icon: String,
        onShare: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColor.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.accent)

                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.accent)
            }
        }
        .padding(Spacing.md)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    // MARK: - Recent column

    private var recentColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Recent exports")
            VStack(spacing: Spacing.sm) {
                if recentExports.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("No exports yet")
                            .font(.subheadline)
                        Text("Share or save a stencil to see it here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassCard(cornerRadius: Radius.md)
                } else {
                    ForEach(recentExports) { item in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: item.kind.icon)
                                .foregroundStyle(AppColor.accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.kind.title)
                                    .font(.subheadline.weight(.medium))
                                Text(item.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlassCard(cornerRadius: Radius.sm)
                    }
                }
            }

            Divider().padding(.vertical, Spacing.xs)

            VStack(alignment: .leading, spacing: 4) {
                Text("Request \(response.usage.requestId.prefix(8))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(response.usage.tier) · \(response.usage.outputResolution) · \(response.usage.processingTimeMs) ms")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Export plumbing

    private enum ExportKind: String, CaseIterable {
        case original, retouched, procreate, annotated

        var title: String {
            switch self {
            case .original:  return "Original PNG"
            case .retouched: return "Retouched PNG"
            case .procreate: return "Procreate PNG"
            case .annotated: return "Annotated PNG"
            }
        }

        var icon: String {
            switch self {
            case .original:  return "doc.on.doc"
            case .retouched: return "wand.and.stars.inverse"
            case .procreate: return "square.dashed.inset.filled"
            case .annotated: return "pencil.tip.crop.circle"
            }
        }
    }

    private struct RecentExport: Identifiable {
        let id = UUID()
        let kind: ExportKind
        let timestamp: Date
    }

    private func recordRecent(_ kind: ExportKind) {
        let entry = RecentExport(kind: kind, timestamp: Date())
        recentExports.insert(entry, at: 0)
        if recentExports.count > 10 {
            recentExports = Array(recentExports.prefix(10))
        }
    }

    private func share(_ kind: ExportKind) {
        saveMessage = nil
        guard let (data, suffix) = bytes(for: kind) else {
            saveMessage = "Stencil isn't ready yet."
            return
        }
        do {
            let id = response.usage.requestId.prefix(8)
            let filename = "stencil_\(id)_\(suffix).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
            recordRecent(kind)
        } catch {
            saveMessage = "Error writing temp file: \(error.localizedDescription)"
        }
    }

    private func saveToPhotos(_ kind: ExportKind) {
        saveMessage = nil
        guard let (data, _) = bytes(for: kind) else {
            saveMessage = "Stencil isn't ready yet."
            return
        }
        Task {
            let result = await PhotoSaver.save(data)
            await MainActor.run {
                switch result {
                case .success:
                    saveMessage = "Saved to Photos."
                    recordRecent(kind)
                case .denied:
                    saveMessage = "Photos access denied. Enable in Settings → Privacy."
                case let .failed(message):
                    saveMessage = "Error saving: \(message)"
                }
            }
        }
    }

    private func bytes(for kind: ExportKind) -> (Data, String)? {
        switch kind {
        case .original:  return viewModel.originalStencilPNG().map { ($0, "original") }
        case .retouched: return viewModel.retouchedStencilPNG().map { ($0, "retouched") }
        case .procreate: return viewModel.procreateTransparentPNG().map { ($0, "procreate") }
        case .annotated: return viewModel.annotatedStencilPNG().map { ($0, "annotated") }
        }
    }
}

// MARK: - Share sheet (file-local)

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
