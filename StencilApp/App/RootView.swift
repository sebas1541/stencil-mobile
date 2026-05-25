import SwiftUI

/// Top-level shell. Drops the old `NavigationSplitView` sidebar in favour of
/// a Calendar-style top toolbar that switches between four sections.
///
/// `EditorViewModel` owns both the configure pipeline AND the post-result
/// `RetouchViewModel`. That way RootView is a thin router — no `onChange`
/// gymnastics needed.
struct RootView: View {
    @State private var selectedSection: AppSection = {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(where: { $0.hasPrefix("--initial-section=") }) {
            let raw = String(args[idx].dropFirst("--initial-section=".count))
            if let section = AppSection(rawValue: raw) { return section }
        }
#endif
        return .generate
    }()
    @State private var searchQuery: String = ""
    @State private var isAccountPresented: Bool = false

    @State private var editorViewModel = EditorViewModel()
    @State private var history = HistoryStore.shared

    var body: some View {
        ZStack(alignment: .top) {
            AppColor.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TopToolbar(
                    selectedSection: $selectedSection,
                    searchQuery: $searchQuery,
                    isResultReady: editorViewModel.retouchViewModel != nil,
                    history: history,
                    onNew: handleNew,
                    onPickHistory: handlePickHistory,
                    onClearHistory: { history.clear() },
                    onShowAccount: { isAccountPresented = true },
                    onPickStyle: handlePickStyle
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(AppColor.accent)
        .sheet(isPresented: $isAccountPresented) {
            AccountSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // We intentionally let the user navigate to result-only sections even
        // without a result — the section itself renders an empty state
        // (`ResultRequiredView`) that explains the missing prerequisite and
        // bounces them back to Generate when they're ready. Auto-snapping
        // back made the segmented control feel unresponsive.
#if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .stencilInjectMock)) { _ in
            editorViewModel.injectMockResult()
            // Apply --section=… launch arg if present.
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(where: { $0.hasPrefix("--section=") }) {
                let raw = String(args[idx].dropFirst("--section=".count))
                if let section = AppSection(rawValue: raw) {
                    selectedSection = section
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stencilInjectMockGenerating)) { _ in
            editorViewModel.injectMockGenerating()
        }
#endif
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .generate:
            EditorContainerView(
                viewModel: editorViewModel,
                onSwitchTo: { selectedSection = $0 }
            )

        case .refine:
            if let retouchViewModel = editorViewModel.retouchViewModel {
                RefinePanel(viewModel: retouchViewModel)
                    .padding(Spacing.xl)
            } else {
                ResultRequiredView(section: .refine) { selectedSection = .generate }
            }

        case .annotate:
            if let retouchViewModel = editorViewModel.retouchViewModel {
                AnnotationPanel(viewModel: retouchViewModel)
                    .padding(Spacing.xl)
            } else {
                ResultRequiredView(section: .annotate) { selectedSection = .generate }
            }

        case .export:
            if let retouchViewModel = editorViewModel.retouchViewModel,
               case let .result(response, _) = editorViewModel.phase {
                ExportPanel(viewModel: retouchViewModel, response: response)
                    .padding(Spacing.xl)
            } else {
                ResultRequiredView(section: .export) { selectedSection = .generate }
            }
        }
    }

    // MARK: - Actions

    private func handleNew() {
        editorViewModel.startOver()
        selectedSection = .generate
    }

    private func handlePickHistory(_ entry: GenerationHistoryEntry) {
        editorViewModel.apply(history: entry)
        selectedSection = .generate
    }

    private func handlePickStyle(_ style: StyleName) {
        editorViewModel.parameters.estilo = style
        selectedSection = .generate
    }
}

// MARK: - Empty state when a result-only section is visited without a result

private struct ResultRequiredView: View {
    let section: AppSection
    var onGenerate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: section.systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AppColor.accent)
                .padding(Spacing.lg)
                .background(
                    Circle().fill(AppColor.accent.opacity(0.08))
                )

            VStack(spacing: Spacing.sm) {
                Text(headline)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                onGenerate()
            } label: {
                Label("Go to Generate", systemImage: "arrow.right")
                    .frame(maxWidth: 240)
                    .padding(.vertical, Spacing.sm)
            }
            .liquidGlassButton(.prominent)
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }

    private var headline: String {
        switch section {
        case .generate: return "Generate a stencil first"
        case .refine:   return "Nothing to refine yet"
        case .annotate: return "Nothing to annotate yet"
        case .export:   return "Nothing to export yet"
        }
    }

    private var subtitle: String {
        switch section {
        case .generate:
            return "Pick a reference photo and tap Generate."
        case .refine:
            return "Threshold, line thickness, denoise, close gaps, smooth, sharpen, invert, and colour swap — all live here once you have a stencil."
        case .annotate:
            return "Draw on top of the stencil with Apple Pencil — palm-rest mode plus the system ink / marker / eraser palette. Generate one first."
        case .export:
            return "Save the stencil as PNG, drop it into Procreate with transparent background, or share the annotated composite. Generate one first."
        }
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    RootView()
}
