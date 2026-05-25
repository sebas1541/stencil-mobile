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

/// Loading state with rotating tattoo-themed verbs + animated dots. Same
/// vibe as Claude Code's status indicators but tuned for what the stencil
/// pipeline is actually doing under the hood.
private struct GeneratingView: View {
    /// Verbs rotate every 1.8 s. List intentionally walks the pipeline in
    /// rough order so the user gets a sense of progress even though we
    /// don't get real progress events back from the server.
    private static let verbs: [String] = [
        "Studying the reference",
        "Classifying the subject",
        "Sketching base lines",
        "Tracing contours",
        "Inking the silhouette",
        "Carving out shadows",
        "Cleaning up speckles",
        "Refining edges",
        "Polishing the stencil",
        "Almost there",
    ]

    @State private var verbIndex: Int = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            icon
            verb
            AnimatedDots()
            Text("This usually takes 4–10 seconds depending on the tier.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.xxl)
        .frame(maxWidth: 520)
        .liquidGlassCard()
        .padding(Spacing.xl)
        .task {
            // Cycle the verb until the view disappears.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if Task.isCancelled { break }
                withAnimation(.smooth(duration: 0.45)) {
                    verbIndex = (verbIndex + 1) % Self.verbs.count
                }
            }
        }
    }

    private var icon: some View {
        Image(systemName: "wand.and.stars")
            .font(.system(size: 56, weight: .light))
            .foregroundStyle(AppColor.accent)
            .symbolEffect(.variableColor.iterative, options: .repeating)
            .padding(Spacing.lg)
            .background(
                Circle()
                    .fill(AppColor.accent.opacity(0.10))
            )
    }

    private var verb: some View {
        Text(Self.verbs[verbIndex])
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .frame(minHeight: 36)
            .id(verbIndex) // forces a fresh transition per verb
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Three indigo dots, the active one larger + fully opaque, sweeping every
/// 0.35 s. Pure SwiftUI, no timers leaking outside the view's task.
private struct AnimatedDots: View {
    private let count: Int = 3
    @State private var active: Int = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 10, height: 10)
                    .opacity(i == active ? 1.0 : 0.30)
                    .scaleEffect(i == active ? 1.25 : 1.0)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { break }
                withAnimation(.smooth(duration: 0.30)) {
                    active = (active + 1) % count
                }
            }
        }
        .accessibilityLabel("Loading")
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
