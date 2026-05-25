import SwiftUI

/// Post-generation view. Hosts three tabs (Retouch / Overlay / Export) and
/// owns the `RetouchViewModel` that drives the cached image pipeline.
struct ResultView: View {
    let response: StencilResponse
    let source: UIImage
    let onBack: () -> Void

    @State private var viewModel: RetouchViewModel
    @State private var loadError: String?
    @State private var selectedTab: ResultTab = .retouch
    @State private var showInspector: Bool = false

    enum ResultTab: String, Hashable, Identifiable, CaseIterable {
        case retouch, overlay, annotate, export
        var id: String { rawValue }

        var title: String {
            switch self {
            case .retouch:  return "Retouch"
            case .overlay:  return "Overlay"
            case .annotate: return "Annotate"
            case .export:   return "Export"
            }
        }

        var systemImage: String {
            switch self {
            case .retouch:  return "slider.horizontal.3"
            case .overlay:  return "rectangle.on.rectangle"
            case .annotate: return "pencil.tip"
            case .export:   return "square.and.arrow.up"
            }
        }
    }

    init(response: StencilResponse, source: UIImage, onBack: @escaping () -> Void) {
        self.response = response
        self.source = source
        self.onBack = onBack
        _viewModel = State(initialValue: RetouchViewModel(referenceImage: source))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                tabPicker
                content
            }
            .padding(Spacing.xl)
        }
        .task { await loadStencil() }
        .toolbar { inspectorToolbar }
        .inspector(isPresented: $showInspector) {
            ResultInspector(response: response)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
        }
    }

    @ToolbarContentBuilder
    private var inspectorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showInspector.toggle()
            } label: {
                Image(systemName: showInspector
                      ? "sidebar.right"
                      : "info.circle")
            }
            .accessibilityLabel("Toggle details")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stencil ready")
                    .font(.title2.weight(.semibold))
                Text("\(response.usage.tier) · \(response.usage.outputResolution) · \(response.usage.processingTimeMs) ms · \(response.contentType) (\(Int(response.contentConfidence * 100))%)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onBack) {
                Label("New stencil", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .liquidGlassButton(.subtle)
        }
    }

    // MARK: - Tab picker (glass chip row, scrolls horizontally on narrow widths)

    private var tabPicker: some View {
        HStack(spacing: Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(ResultTab.allCases) { tab in
                        Button {
                            withAnimation(.snappy) { selectedTab = tab }
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.sm)
                                .liquidGlassChip(
                                    tint: selectedTab == tab ? AppColor.accent : nil,
                                    prominent: selectedTab == tab
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            if viewModel.isRendering {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColor.accent)
            }
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var content: some View {
        if let error = loadError {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(AppColor.danger)
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity)
            .liquidGlassCard()
        } else if viewModel.stencilImage == nil {
            placeholder
        } else {
            switch selectedTab {
            case .retouch:  RetouchPanel(viewModel: viewModel)
            case .overlay:  OverlayPanel(viewModel: viewModel)
            case .annotate: AnnotationPanel(viewModel: viewModel)
            case .export:   ExportPanel(viewModel: viewModel, response: response)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)
            Text("Downloading stencil…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .liquidGlassCard()
    }

    // MARK: - Networking

    private func loadStencil() async {
        guard viewModel.stencilImage == nil else { return }
        // Prefer the high-res PNG over the WebP preview so retouching has
        // pixels to work with. The preview URL is faster but downscaled.
        guard let url = URL(string: response.stencilUrl) else {
            loadError = "Invalid stencil URL"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                viewModel.adoptStencil(image)
            } else {
                loadError = "Could not decode the downloaded stencil."
            }
        } catch {
            loadError = "Failed to download stencil: \(error.localizedDescription)"
        }
    }
}
