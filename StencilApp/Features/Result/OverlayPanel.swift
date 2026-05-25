import SwiftUI

/// Composited preview of the stencil on top of the reference photo. Three
/// sliders match the Gradio frontend exactly.
struct OverlayPanel: View {
    @Bindable var viewModel: RetouchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            preview
            sliders
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppColor.canvasBackground)
            if let image = viewModel.overlayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.md)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .liquidGlassCard()
    }

    private var sliders: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Overlay")
            VStack(spacing: Spacing.lg) {
                LabeledSlider(
                    title: "Stencil opacity",
                    description: "Preview only — export stays full quality",
                    range: 0...100,
                    step: 5,
                    value: $viewModel.overlaySettings.stencilOpacity
                )
                LabeledSlider(
                    title: "Reference opacity",
                    description: "Fade the photo underneath",
                    range: 0...100,
                    step: 5,
                    value: $viewModel.overlaySettings.referenceOpacity
                )
                LabeledSlider(
                    title: "Reference brightness",
                    description: "Brighten / dim the underlay (50 = -50%, 150 = +50%)",
                    range: 50...150,
                    step: 5,
                    value: $viewModel.overlaySettings.referenceBrightness
                )
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    let description: String
    let range: ClosedRange<Double>
    let step: Double
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(AppColor.accent)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
