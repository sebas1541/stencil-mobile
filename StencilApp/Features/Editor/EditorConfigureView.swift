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
            VStack(alignment: .leading, spacing: Spacing.xl) {
                tierSection
                styleAndResolutionRow
                promptControlsSection
                actionsSection
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: - Tier (vertical cards)

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Processing tier")
            let columns = [GridItem(.adaptive(minimum: 220), spacing: Spacing.md)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.md) {
                ForEach(ModelTier.allCases) { tier in
                    TierCard(
                        tier: tier,
                        isSelected: viewModel.parameters.tier == tier
                    ) {
                        viewModel.parameters.tier = tier
                        viewModel.onTierChanged()
                    }
                }
            }
            Text(viewModel.costLabel)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
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

    private var promptControlsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionLabel(text: "Prompt controls")
            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle(isOn: $viewModel.parameters.promptConfig.uiBackground) {
                    VStack(alignment: .leading) {
                        Text("Preserve background")
                            .font(AppFont.bodyEmphasis)
                        Text("Off replaces the background with pure white.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(AppColor.accent)

                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Main contour thickness")
                        .font(AppFont.bodyEmphasis)
                    Picker("Thickness", selection: $viewModel.parameters.promptConfig.uiThickness) {
                        ForEach(Thickness.allCases) { value in
                            Text(value.rawValue).tag(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { viewModel.parameters.promptConfig.uiShadowsEnabled },
                    set: { newValue in
                        viewModel.parameters.promptConfig.uiShadowsEnabled = newValue
                        viewModel.onShadowsToggleChanged(enabled: newValue)
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Topographic value contours")
                            .font(AppFont.bodyEmphasis)
                        Text("Adds broken guide lines marking tonal-zone boundaries.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(AppColor.accent)

                if viewModel.parameters.promptConfig.uiShadowsEnabled {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Detail")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker("Detail", selection: $viewModel.parameters.promptConfig.uiShadowDetail) {
                            ForEach(ShadowDetail.allCases) { value in
                                Text(value.rawValue).tag(value.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Weight")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker("Weight", selection: $viewModel.parameters.promptConfig.uiShadowWeight) {
                            ForEach(ShadowWeight.allCases) { value in
                                Text(value.rawValue).tag(value.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.leading, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Texture filtering")
                        .font(AppFont.bodyEmphasis)
                    Picker("Texture", selection: $viewModel.parameters.promptConfig.uiTextureLevel) {
                        ForEach(TextureLevel.allCases) { value in
                            Text(value.rawValue).tag(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(Spacing.lg)
            .liquidGlassCard()
            .animation(.snappy, value: viewModel.parameters.promptConfig.uiShadowsEnabled)
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

            Button {
                viewModel.generate(promptMode: .technical_trace)
            } label: {
                Label("Technical trace", systemImage: "square.dashed")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .keyboardShortcut("t", modifiers: [.command])
            .liquidGlassButton(.subtle)
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

// MARK: - Tier card

private struct TierCard: View {
    let tier: ModelTier
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: tier.isLocal ? "cpu" : "sparkles")
                        .font(.callout)
                        .foregroundStyle(isSelected ? AppColor.accent : .secondary)
                    Text(tier.displayName)
                        .font(AppFont.bodyEmphasis)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.accent)
                    }
                }
                Text(tier.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassChip(
                tint: isSelected ? AppColor.accent : nil,
                prominent: isSelected
            )
        }
        .buttonStyle(.plain)
    }
}
