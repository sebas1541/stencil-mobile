import SwiftUI

/// Generate-section host. Switches between configure, generating, result
/// preview, and failure based on `viewModel.phase`. RootView handles the
/// outer toolbar and section routing.
struct EditorContainerView: View {
    @Bindable var viewModel: EditorViewModel
    var onSwitchTo: (AppSection) -> Void

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .configure:
                EditorConfigureView(viewModel: viewModel)
            case .generating:
                GeneratingView()
            case let .result(response, source):
                GenerateResultPreview(
                    response: response,
                    source: source,
                    retouchViewModel: viewModel.retouchViewModel,
                    onRefine: { onSwitchTo(.refine) },
                    onAnnotate: { onSwitchTo(.annotate) },
                    onExport: { onSwitchTo(.export) },
                    onStartOver: { viewModel.startOver() }
                )
            case let .failed(message):
                FailureView(message: message) {
                    viewModel.backToConfigure()
                }
            }
        }
    }
}

// MARK: - Generating

/// Loading state: a single lowercase verb that rotates every 1.6 s with three
/// animated dots filling in beside it. Same lineage as Claude Code's
/// "polishing… philosophizing… brewing…" status line.
private struct GeneratingView: View {
    /// Lowercase whimsical -ing verbs. A few are genuine stencil-pipeline
    /// stages, the rest are pure Claude-Code-style flavour.
    private static let verbs: [String] = [
        "thinking",
        "studying",
        "sketching",
        "tracing",
        "inking",
        "shading",
        "contouring",
        "stippling",
        "polishing",
        "refining",
        "philosophizing",
        "pondering",
        "brewing",
        "marinating",
        "conjuring",
        "transmuting",
        "channeling",
        "crafting",
        "rendering",
        "almost there",
    ]

    @State private var verbIndex: Int = 0

    var body: some View {
        // Whole card is JUST the verb + its dots. No icon, no subtitle, no
        // duration hint — matches the user's "cleaner please" ask.
        VerbWithDots(verb: Self.verbs[verbIndex])
            .id(verbIndex) // restart the dot animation on each verb swap
            .contentTransition(.opacity)
            .padding(.horizontal, Spacing.xxl)
            .padding(.vertical, Spacing.xxl)
            .frame(maxWidth: 520)
            .liquidGlassCard()
            .padding(Spacing.xl)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    if Task.isCancelled { break }
                    withAnimation(.smooth(duration: 0.40)) {
                        verbIndex = (verbIndex + 1) % Self.verbs.count
                    }
                }
            }
    }
}

/// `<verb>` followed by three dots that fade in one-at-a-time on a
/// ~0.35 s cadence, then all reset. Lowercase, monospaced-digit-safe,
/// no shift in layout because the dot positions are reserved.
private struct VerbWithDots: View {
    let verb: String
    @State private var dotCount: Int = 0

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(verb)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            // Three dots positioned in a fixed-width slot so the verb stays
            // exactly where it is regardless of how many dots are showing.
            ZStack(alignment: .leading) {
                Text("...")
                    .opacity(0)   // reserves space
                Text(String(repeating: ".", count: dotCount))
            }
            .font(.system(size: 32, weight: .medium, design: .rounded))
            .foregroundStyle(AppColor.accent)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { break }
                withAnimation(.smooth(duration: 0.25)) {
                    dotCount = (dotCount + 1) % 4
                }
            }
        }
        .accessibilityLabel(verb)
    }
}

// MARK: - Failure

private struct FailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.danger)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(action: onRetry) {
                Label("Back to setup", systemImage: "arrow.uturn.backward")
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
            }
            .liquidGlassButton(.prominent)
        }
        .padding(Spacing.xl)
        .liquidGlassCard()
        .padding(Spacing.xl)
    }
}

// MARK: - Result preview shown inside Generate

private struct GenerateResultPreview: View {
    let response: StencilResponse
    let source: UIImage
    let retouchViewModel: RetouchViewModel?

    var onRefine: () -> Void
    var onAnnotate: () -> Void
    var onExport: () -> Void
    var onStartOver: () -> Void

    @State private var loadedStencil: UIImage?
    @State private var loadError: String?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            // Left: comparison hero
            comparisonCard
                .frame(maxWidth: .infinity)

            // Right: metadata + actions
            sidePanel
                .frame(width: 320)
        }
        .padding(Spacing.xl)
        .task { await loadStencil() }
    }

    private var comparisonCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppColor.canvasBackground)

            if let after = loadedStencil {
                ComparisonImageView(before: source, after: after)
                    .padding(Spacing.md)
            } else if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
                    .padding(Spacing.lg)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Downloading stencil…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 520)
        .liquidGlassCard()
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Header card with KPIs
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Stencil ready")
                    .font(.title3.weight(.semibold))
                Text("\(response.usage.tier) · \(response.usage.outputResolution) · \(response.usage.processingTimeMs) ms")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                kpiRow(label: "Detected", value: "\(response.contentType) (\(Int(response.contentConfidence * 100))%)")
                kpiRow(label: "Source", value: String(format: "%.2f Mpx", response.usage.inputMpx))
                kpiRow(label: "Gemini calls", value: "\(response.usage.geminiCalls)")
                if response.usage.resolutionWarning {
                    Label("Low-res source for \(response.usage.outputResolution)",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(AppColor.danger)
                        .padding(.top, 4)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard()

            // Action stack — jumping to the other sections
            VStack(spacing: Spacing.sm) {
                actionButton(
                    title: "Refine the lines",
                    subtitle: "Threshold, denoise, overlay…",
                    icon: "slider.horizontal.3",
                    action: onRefine
                )
                actionButton(
                    title: "Annotate with Pencil",
                    subtitle: "Mark up the stencil",
                    icon: "pencil.tip",
                    action: onAnnotate
                )
                actionButton(
                    title: "Export & share",
                    subtitle: "Download or save to Photos",
                    icon: "square.and.arrow.up",
                    action: onExport
                )
            }

            Button(role: .destructive, action: onStartOver) {
                Label("Start over", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .keyboardShortcut("n", modifiers: [.command])
            .liquidGlassButton(.subtle)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func actionButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
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
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .liquidGlassCard(cornerRadius: Radius.md)
        }
        .buttonStyle(.plain)
    }

    private func kpiRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }

    // MARK: - Networking

    private func loadStencil() async {
        // If the retouch view model already has the stencil cached we reuse
        // those pixels — saves a redundant download when the user lands here
        // after coming back from Refine / Annotate / Export.
        if let cached = retouchViewModel?.stencilImage {
            loadedStencil = cached
            return
        }
        guard let url = URL(string: response.stencilUrl) else {
            loadError = "Invalid stencil URL"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                loadedStencil = image
                retouchViewModel?.adoptStencil(image)
            } else {
                loadError = "Could not decode the stencil."
            }
        } catch {
            loadError = "Failed to download stencil: \(error.localizedDescription)"
        }
    }
}
