import SwiftUI

/// Top-level container for the editor flow. Owns the view model and switches
/// between the configure form, the generating spinner, and the result panel.
struct EditorContainerView: View {
    @State private var viewModel = EditorViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.primaryBackground.ignoresSafeArea()

                switch viewModel.phase {
                case .configure:
                    EditorConfigureView(viewModel: viewModel)
                case .generating:
                    GeneratingView()
                case let .result(response, preview):
                    ResultView(response: response, source: preview) {
                        viewModel.backToConfigure()
                    }
                case let .failed(message):
                    FailureView(message: message) {
                        viewModel.backToConfigure()
                    }
                }
            }
            .navigationTitle("Stencil Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Loading state

private struct GeneratingView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.accent)
            Text("Generating stencil…")
                .font(.headline)
            Text("This usually takes 4–10 seconds depending on the tier.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .padding(Spacing.xl)
        .liquidGlassCard()
        .padding(Spacing.xl)
    }
}

// MARK: - Failure state

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
            }
            .liquidGlassButton(.prominent)
        }
        .padding(Spacing.xl)
        .liquidGlassCard()
        .padding(Spacing.xl)
    }
}
