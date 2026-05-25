import SwiftUI

/// Top-level shell. Drops the old `NavigationSplitView` sidebar in favour of
/// a Calendar-style top toolbar that switches between four sections.
///
/// `EditorViewModel` owns both the configure pipeline AND the post-result
/// `RetouchViewModel`. That way RootView is a thin router — no `onChange`
/// gymnastics needed.
struct RootView: View {
    @State private var selectedSection: AppSection = .generate
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
        // If the user lands on a result-only section without a result yet,
        // snap back to Generate so the empty state isn't surprising.
        .onChange(of: selectedSection) { _, newSection in
            if newSection.requiresResult, editorViewModel.retouchViewModel == nil {
                selectedSection = .generate
            }
        }
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
                ResultRequiredView { selectedSection = .generate }
            }

        case .annotate:
            if let retouchViewModel = editorViewModel.retouchViewModel {
                AnnotationPanel(viewModel: retouchViewModel)
                    .padding(Spacing.xl)
            } else {
                ResultRequiredView { selectedSection = .generate }
            }

        case .export:
            if let retouchViewModel = editorViewModel.retouchViewModel,
               case let .result(response, _) = editorViewModel.phase {
                ExportPanel(viewModel: retouchViewModel, response: response)
                    .padding(Spacing.xl)
            } else {
                ResultRequiredView { selectedSection = .generate }
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
    var onGenerate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppColor.accent)
            Text("Generate a stencil first")
                .font(.title3.weight(.semibold))
            Text("Pick a reference photo and tap Generate. This section becomes available once a stencil exists.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button {
                onGenerate()
            } label: {
                Label("Go to Generate", systemImage: "arrow.right")
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
            }
            .liquidGlassButton(.prominent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    RootView()
}
