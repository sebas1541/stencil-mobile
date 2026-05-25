import PencilKit
import SwiftUI
import UIKit

/// Three-column annotation workspace. Layers list on the left, full-bleed
/// canvas in the middle, controls on the right. Reuses `AnnotationCanvas`.
struct AnnotationPanel: View {
    @Bindable var viewModel: RetouchViewModel
    @State private var shareItem: ShareItem?
    @State private var saveMessage: String?
    @State private var isToolPickerVisible: Bool = true

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
            layersColumn
                .frame(width: 160)
            canvas
                .frame(maxWidth: .infinity)
            controlsColumn
                .frame(width: 260)
        }
    }

    // MARK: - Stacked (iPhone)

    private var stackedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                layersColumn
                canvas
                    .frame(height: 480)
                controlsColumn
            }
        }
    }

    // MARK: - Layers

    private var layersColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Layers")
            VStack(spacing: Spacing.sm) {
                layerChip(name: "Pencil strokes", icon: "scribble.variable", muted: false)
                layerChip(name: "Stencil base",   icon: "rectangle.grid.1x2", muted: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func layerChip(name: String, icon: String, muted: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(muted ? .secondary : AppColor.accent)
            Text(name)
                .font(AppFont.bodyEmphasis)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .liquidGlassChip(tint: muted ? nil : AppColor.accent, prominent: !muted)
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
        .frame(minHeight: 560)
        .liquidGlassCard()
    }

    // MARK: - Controls

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionLabel(text: "Pencil")
            VStack(spacing: Spacing.md) {
                Toggle(isOn: $viewModel.pencilOnlyDrawing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Pencil only")
                            .font(AppFont.bodyEmphasis)
                        Text("Ignores finger input.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $isToolPickerVisible) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show tool picker")
                            .font(AppFont.bodyEmphasis)
                        Text("Ink, marker, eraser.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(AppColor.accent)
            .padding(Spacing.lg)
            .liquidGlassCard()

            VStack(spacing: Spacing.sm) {
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

            Spacer(minLength: 0)
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

// MARK: - Share sheet plumbing (file-local)

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
