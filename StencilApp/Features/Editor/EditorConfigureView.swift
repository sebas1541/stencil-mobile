import SwiftUI

/// Configure-and-generate form, redesigned as a two-column iPad layout so the
/// import card can breathe and the configuration column can show tier cards
/// without truncating.
struct EditorConfigureView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            twoColumnLayout
            stackedLayout
        }
    }

    // MARK: - Layouts

    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            importColumn
                .frame(minWidth: 360, idealWidth: 460, maxWidth: 520)

            configColumn
                .frame(maxWidth: .infinity)
        }
        .padding(Spacing.xl)
    }

    private var stackedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                importColumn
                configColumn
            }
            .padding(Spacing.xl)
        }
        .scrollClipDisabled()
    }

    // MARK: - Import column

    private var importColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Reference image")
            ImportCardView(
                selectedImage: $viewModel.sourceImage,
                selectedFilename: $viewModel.sourceFilename
            )
        }
    }

    // MARK: - Config column

    private var configColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                tierSection
                styleAndResolutionRow
                promptControlsSection
                actionsSection
            }
            // Vertical padding gives the bottom button's shadow breathing
            // room; horizontal padding does the same for any tier/card
            // shadows that bleed sideways. Combined with .scrollClipDisabled
            // below this keeps shadows from clipping at the scroll edges.
            .padding(.horizontal, 4)
            .padding(.vertical, Spacing.sm)
        }
        .scrollClipDisabled()
    }

    // MARK: - Tier (vertical list)

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Processing tier")
            VStack(spacing: 6) {
                ForEach(ModelTier.allCases) { tier in
                    TierRow(
                        tier: tier,
                        resolution: viewModel.parameters.resolution,
                        isSelected: viewModel.parameters.tier == tier
                    ) {
                        viewModel.parameters.tier = tier
                        viewModel.onTierChanged()
                    }
                }
            }
        }
    }

    // MARK: - Style + resolution

    private var styleAndResolutionRow: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionLabel(text: "Tattoo style")
                Menu {
                    ForEach(StyleName.allCases) { style in
                        Button {
                            viewModel.parameters.estilo = style
                        } label: {
                            if viewModel.parameters.estilo == style {
                                Label(style.displayName, systemImage: "checkmark")
                            } else {
                                Text(style.displayName)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.parameters.estilo.displayName)
                            .font(AppFont.bodyEmphasis)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity)
                    .liquidGlassCard(cornerRadius: Radius.md)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionLabel(text: "Export resolution")
                Picker("Resolution", selection: $viewModel.parameters.resolution) {
                    ForEach(Resolution.allCases) { res in
                        Text(res.displayName).tag(res)
                    }
                }
                .pickerStyle(.segmented)
                Text(viewModel.parameters.resolution.pixelDescription)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Prompt controls
    //
    // Four small cards instead of one big nested one. Each card carries a
    // single logical control so the visual hierarchy stops feeling muddled.

    private var promptControlsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Prompt controls")
            VStack(spacing: 6) {
                backgroundCard
                thicknessCard
                shadowsCard
                textureCard
            }
            .animation(.snappy, value: viewModel.parameters.promptConfig.uiShadowsEnabled)
        }
    }

    private var backgroundCard: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            iconBadge(systemName: "rectangle.dashed")
            VStack(alignment: .leading, spacing: 2) {
                Text("Preserve background")
                    .font(AppFont.bodyEmphasis)
                Text("Off replaces it with pure white.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $viewModel.parameters.promptConfig.uiBackground)
                .labelsHidden()
                .tint(AppColor.accent)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private var thicknessCard: some View {
        HStack(spacing: Spacing.md) {
            iconBadge(systemName: "lineweight")
            Text("Main contour thickness")
                .font(AppFont.bodyEmphasis)
            Spacer(minLength: Spacing.sm)
            Picker("Thickness", selection: $viewModel.parameters.promptConfig.uiThickness) {
                ForEach(Thickness.allCases) { value in
                    Text(value.rawValue).tag(value.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    @ViewBuilder
    private var shadowsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                iconBadge(systemName: "mountain.2")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Topographic value contours")
                        .font(AppFont.bodyEmphasis)
                    Text("Broken guide lines marking tonal zones.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.parameters.promptConfig.uiShadowsEnabled },
                    set: { newValue in
                        viewModel.parameters.promptConfig.uiShadowsEnabled = newValue
                        viewModel.onShadowsToggleChanged(enabled: newValue)
                    }
                ))
                .labelsHidden()
                .tint(AppColor.accent)
            }

            if viewModel.parameters.promptConfig.uiShadowsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Detail", selection: $viewModel.parameters.promptConfig.uiShadowDetail) {
                        ForEach(ShadowDetail.allCases) { value in
                            Text(value.rawValue).tag(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Weight", selection: $viewModel.parameters.promptConfig.uiShadowWeight) {
                        ForEach(ShadowWeight.allCases) { value in
                            Text(value.rawValue).tag(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private var textureCard: some View {
        HStack(spacing: Spacing.md) {
            iconBadge(systemName: "circle.grid.cross")
            Text("Texture filtering")
                .font(AppFont.bodyEmphasis)
            Spacer(minLength: Spacing.sm)
            Picker("Texture", selection: $viewModel.parameters.promptConfig.uiTextureLevel) {
                ForEach(TextureLevel.allCases) { value in
                    Text(value.rawValue).tag(value.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private func iconBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.callout)
            .foregroundStyle(AppColor.accent)
            .frame(width: 28, height: 28)
            .background {
                Circle().fill(AppColor.accent.opacity(0.12))
            }
    }

    // MARK: - Generate buttons

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                viewModel.generate(promptMode: .standard)
            } label: {
                Label("Generate stencil", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .keyboardShortcut("g", modifiers: [.command])
            .liquidGlassButton(.prominent)
            .disabled(!viewModel.canGenerate)
#if DEBUG
            // Long-press shortcut: skip the network and inject a mock result
            // so the rest of the UI is reachable in the simulator without
            // running the FastAPI microservice.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                    viewModel.injectMockResult()
                }
            )
#endif

            Button {
                viewModel.generate(promptMode: .technical_trace)
            } label: {
                Label("Technical trace", systemImage: "square.dashed")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .keyboardShortcut("t", modifiers: [.command])
            // Per Apple HIG: "Secondary actions should use standard buttons
            // or tinted fills in the content layer, not extra glass." Only
            // the primary "Generate stencil" gets `.glassProminent`.
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGenerate || !viewModel.parameters.tier.supportsTechnicalTrace)

            if !viewModel.parameters.tier.supportsTechnicalTrace {
                Text("Technical Trace requires an API tier. Pick Flash, Pro, or any Calisto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.shouldShowLowResolutionWarning {
                Label("Heads up: at 4K this source will look soft.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppColor.danger)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Tier row (single-line list item)
//
// Per Apple's iPadOS 26 guidance (Perplexity research, citing the
// "Adopting Liquid Glass" docs): selected list rows transform into a
// *tinted Liquid Glass pill*, not a solid accent fill. Unselected rows
// stay on a soft accent-tinted standard material. Text colour stays
// semantic — the glass tint + checkmark communicate selection.

private struct TierRow: View {
    let tier: ModelTier
    let resolution: Resolution
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: tier.isLocal ? "cpu" : "sparkles")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 18)

                Text(tier.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: Spacing.md)

                Text(tier.priceLabel(for: resolution))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.accent)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            if #available(iOS 26.0, *) {
                // Selected = tinted Liquid Glass pill (Apple's pattern for
                // list row selection on iPadOS 26).
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(AppColor.accent.opacity(0.55)),
                        in: .rect(cornerRadius: Radius.md)
                    )
            } else {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(AppColor.accent.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(AppColor.accent.opacity(0.50), lineWidth: 1)
                    )
            }
        } else {
            // Unselected = soft accent tint over the dark canvas — standard
            // material would disappear on a near-black background, so we
            // use a low-opacity indigo wash instead.
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(AppColor.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(AppColor.accent.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
