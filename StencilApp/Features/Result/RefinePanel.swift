import SwiftUI

/// Combines the previous Retouch and Overlay tabs into one workspace. The
/// preview is the hero, sliders sit on the right, and a two-chip switcher
/// on the left flips between retouch / overlay groups.
struct RefinePanel: View {
    @Bindable var viewModel: RetouchViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case retouch
        case overlay
        var id: String { rawValue }

        var title: String {
            switch self {
            case .retouch: return "Retouch"
            case .overlay: return "Overlay"
            }
        }

        var systemImage: String {
            switch self {
            case .retouch: return "slider.horizontal.3"
            case .overlay: return "rectangle.on.rectangle"
            }
        }
    }

    @State private var mode: Mode = .retouch

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            stackedLayout
        }
    }

    // MARK: - Wide (iPad)

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            modeColumn
                .frame(width: 160)
            previewColumn
                .frame(maxWidth: .infinity)
            slidersColumn
                .frame(width: 320)
        }
    }

    // MARK: - Stacked (iPhone / Stage Manager)

    private var stackedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                modeColumn
                previewColumn
                    .frame(height: 360)
                slidersColumn
            }
        }
    }

    // MARK: - Columns

    private var modeColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Tools")
            VStack(spacing: Spacing.sm) {
                ForEach(Mode.allCases) { entry in
                    Button {
                        withAnimation(.snappy) { mode = entry }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: entry.systemImage)
                                .foregroundStyle(mode == entry ? AppColor.accent : .secondary)
                            Text(entry.title)
                                .font(AppFont.bodyEmphasis)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .liquidGlassChip(
                            tint: mode == entry ? AppColor.accent : nil,
                            prominent: mode == entry
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            if viewModel.isRendering {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Rendering…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var previewColumn: some View {
        switch mode {
        case .retouch:
            if let after = viewModel.retouchedImage,
               let original = viewModel.stencilImage {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(AppColor.canvasBackground)
                    ComparisonImageView(before: original, after: after)
                        .padding(Spacing.md)
                }
                .frame(minHeight: 520)
                .liquidGlassCard()
            } else {
                GlassImagePreview(image: viewModel.retouchedImage ?? viewModel.stencilImage,
                                  height: 520)
            }

        case .overlay:
            GlassImagePreview(image: viewModel.overlayImage,
                              height: 520)
        }
    }

    @ViewBuilder
    private var slidersColumn: some View {
        switch mode {
        case .retouch:
            retouchSliders
        case .overlay:
            overlaySliders
        }
    }

    // MARK: - Retouch sliders

    private var retouchSliders: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionLabel(text: "Adjustments")
                VStack(spacing: Spacing.md) {
                    LabeledSlider(title: "Threshold",
                                   description: "Higher → fewer pixels become lines",
                                   range: 10...250, step: 1,
                                   value: $viewModel.retouchSettings.threshold,
                                   format: "%.0f")
                    LabeledSlider(title: "Line thickness",
                                   description: "Large values internally capped",
                                   range: -10...10, step: 1,
                                   value: $viewModel.retouchSettings.lineThickness,
                                   format: "%+.0f")
                    LabeledSlider(title: "Denoise",
                                   description: "Pre-threshold speckle cleanup",
                                   range: 0...8, step: 1,
                                   value: $viewModel.retouchSettings.denoise,
                                   format: "%.0f")
                    LabeledSlider(title: "Noise filter",
                                   description: "Remove isolated components < N px²",
                                   range: 0...3000, step: 10,
                                   value: $viewModel.retouchSettings.noiseFilter,
                                   format: "%.0f")
                    LabeledSlider(title: "Close gaps",
                                   description: "Bridge small breaks",
                                   range: 0...25, step: 1,
                                   value: $viewModel.retouchSettings.closeGaps,
                                   format: "%.0f")
                }
                .padding(Spacing.lg)
                .liquidGlassCard()

                SectionLabel(text: "Polish")
                VStack(spacing: Spacing.sm) {
                    Toggle("Smooth edges", isOn: $viewModel.retouchSettings.smooth)
                    Toggle("Sharpen lines", isOn: $viewModel.retouchSettings.sharpen)
                    Toggle("Invert (white on black)", isOn: $viewModel.retouchSettings.invert)
                }
                .tint(AppColor.accent)
                .padding(Spacing.lg)
                .liquidGlassCard()

                SectionLabel(text: "Line colour")
                HStack(spacing: Spacing.md) {
                    ForEach(InkColor.allCases) { ink in
                        ColorSwatch(ink: ink,
                                    isSelected: viewModel.retouchSettings.inkColor == ink) {
                            viewModel.retouchSettings.inkColor = ink
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
                .liquidGlassCard()
            }
        }
    }

    // MARK: - Overlay sliders

    private var overlaySliders: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionLabel(text: "Overlay")
            VStack(spacing: Spacing.md) {
                LabeledSlider(title: "Stencil opacity",
                               description: "Preview only; export stays full quality",
                               range: 0...100, step: 5,
                               value: $viewModel.overlaySettings.stencilOpacity,
                               format: "%.0f")
                LabeledSlider(title: "Reference opacity",
                               description: "Fade the photo underneath",
                               range: 0...100, step: 5,
                               value: $viewModel.overlaySettings.referenceOpacity,
                               format: "%.0f")
                LabeledSlider(title: "Reference brightness",
                               description: "50 = -50%, 150 = +50%",
                               range: 50...150, step: 5,
                               value: $viewModel.overlaySettings.referenceBrightness,
                               format: "%.0f")
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
            Spacer(minLength: 0)
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
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Spacer()
                Text(String(format: format, value))
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

private struct ColorSwatch: View {
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
