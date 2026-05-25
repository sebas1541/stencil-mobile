import SwiftUI

/// All nine retouching controls + the colour swatch picker. Every change goes
/// through the `@Bindable` view model, which schedules a debounced render.
struct RetouchPanel: View {
    @Bindable var viewModel: RetouchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            preview
            sliderGroup
            toggleGroup
            colorGroup
        }
    }

    // MARK: - Preview

    private var preview: some View {
        GlassImagePreview(image: viewModel.retouchedImage ?? viewModel.stencilImage)
    }

    // MARK: - Sliders

    private var sliderGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Adjustments")
            VStack(spacing: Spacing.lg) {
                LabeledSlider(
                    title: "Threshold",
                    description: "Higher → fewer pixels become lines",
                    range: 10...250,
                    step: 1,
                    value: $viewModel.retouchSettings.threshold,
                    valueFormat: "%.0f"
                )
                LabeledSlider(
                    title: "Line thickness",
                    description: "± value; large values internally capped",
                    range: -10...10,
                    step: 1,
                    value: $viewModel.retouchSettings.lineThickness,
                    valueFormat: "%+.0f"
                )
                LabeledSlider(
                    title: "Denoise (pre-threshold)",
                    description: "Speckle cleanup before thresholding",
                    range: 0...8,
                    step: 1,
                    value: $viewModel.retouchSettings.denoise,
                    valueFormat: "%.0f"
                )
                LabeledSlider(
                    title: "Noise filter",
                    description: "Remove isolated components below N px²",
                    range: 0...3000,
                    step: 10,
                    value: $viewModel.retouchSettings.noiseFilter,
                    valueFormat: "%.0f"
                )
                LabeledSlider(
                    title: "Close gaps",
                    description: "Bridge small breaks in lines",
                    range: 0...25,
                    step: 1,
                    value: $viewModel.retouchSettings.closeGaps,
                    valueFormat: "%.0f"
                )
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    // MARK: - Toggles

    private var toggleGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Polish")
            VStack(spacing: Spacing.sm) {
                Toggle("Smooth edges", isOn: $viewModel.retouchSettings.smooth)
                Toggle("Sharpen lines", isOn: $viewModel.retouchSettings.sharpen)
                Toggle("Invert (white on black)", isOn: $viewModel.retouchSettings.invert)
            }
            .tint(AppColor.accent)
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }

    // MARK: - Colour

    private var colorGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Line colour")
            HStack(spacing: Spacing.md) {
                ForEach(InkColor.allCases) { ink in
                    Swatch(
                        ink: ink,
                        isSelected: viewModel.retouchSettings.inkColor == ink
                    ) {
                        viewModel.retouchSettings.inkColor = ink
                    }
                }
                Spacer()
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
        }
    }
}

// MARK: - Building blocks

private struct LabeledSlider: View {
    let title: String
    let description: String
    let range: ClosedRange<Double>
    let step: Double
    @Binding var value: Double
    let valueFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Spacer()
                Text(String(format: valueFormat, value))
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

private struct Swatch: View {
    let ink: InkColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: ink.uiColor))
                        .frame(width: 36, height: 36)
                    if isSelected {
                        Circle()
                            .strokeBorder(AppColor.accent, lineWidth: 3)
                            .frame(width: 40, height: 40)
                    } else {
                        Circle()
                            .strokeBorder(AppColor.borderSubtle, lineWidth: 1)
                            .frame(width: 36, height: 36)
                    }
                }
                Text(ink.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AppColor.accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
