import PencilKit
import SwiftUI
import UIKit

/// Draw on top of the retouched stencil with Apple Pencil (or finger). The
/// PKCanvasView is overlaid on the same `GlassImagePreview` frame used by the
/// other tabs so zoom + pan still feel consistent.
struct AnnotationPanel: View {
    @Bindable var viewModel: RetouchViewModel
    @State private var shareItem: ShareItem?
    @State private var saveMessage: String?
    @State private var isToolPickerVisible: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            canvas
            controls
            informationCard
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppColor.canvasBackground)

            if let base = viewModel.retouchedImage ?? viewModel.stencilImage {
                Image(uiImage: base)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.md)
                    .opacity(0.65)
                    .accessibilityHidden(true)
            }

            AnnotationCanvas(
                drawing: $viewModel.annotationDrawing,
                pencilOnly: viewModel.pencilOnlyDrawing,
                isToolPickerVisible: isToolPickerVisible
            )
            .padding(Spacing.md)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .liquidGlassCard()
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Annotation")

            VStack(spacing: Spacing.md) {
                Toggle(isOn: $viewModel.pencilOnlyDrawing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Pencil only")
                            .font(AppFont.bodyEmphasis)
                        Text("Ignores finger input so you can rest your hand on the screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(AppColor.accent)

                Toggle(isOn: $isToolPickerVisible) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show tool picker")
                            .font(AppFont.bodyEmphasis)
                        Text("PencilKit's ink / marker / eraser palette.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(AppColor.accent)

                Divider()

                HStack(spacing: Spacing.md) {
                    Button(role: .destructive) {
                        viewModel.clearAnnotation()
                    } label: {
                        Label("Clear strokes", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton(.subtle)
                    .disabled(viewModel.annotationDrawing.bounds.isEmpty)

                    Button {
                        shareAnnotated()
                    } label: {
                        Label("Share annotated", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton(.prominent)
                    .disabled(viewModel.stencilImage == nil)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(
                            saveMessage.lowercased().contains("error") ? AppColor.danger : .secondary
                        )
                }
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Tip")
            Text("Use the system tool picker to swap inks, sizes, or grab the eraser. Strokes are layered above the retouched stencil and only baked in when you export.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(cornerRadius: Radius.md)
        }
    }

    // MARK: - Sharing

    private func shareAnnotated() {
        saveMessage = nil
        guard let data = viewModel.annotatedStencilPNG() else {
            saveMessage = "Stencil isn't ready yet."
            return
        }
        do {
            let id = UUID().uuidString.prefix(8)
            let filename = "stencil_annotated_\(id).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            saveMessage = "Error writing temp file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Share sheet plumbing (file-local copies to avoid cross-file coupling)

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
