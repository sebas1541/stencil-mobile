import SwiftUI

/// The main "set up your stencil" form. All controls hang off `viewModel`.
struct EditorConfigureView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ImportCardView(
                    selectedImage: $viewModel.sourceImage,
                    selectedFilename: $viewModel.sourceFilename
                )

                tierSection
                styleAndResolutionSection
                promptControlsSection
                actionsSection
            }
            .padding(Spacing.xl)
        }
    }

    // MARK: - Tier

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Processing tier")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(ModelTier.allCases) { tier in
                        TierChip(
                            tier: tier,
                            isSelected: viewModel.parameters.tier == tier
                        ) {
                            viewModel.parameters.tier = tier
                            viewModel.onTierChanged()
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            Text(viewModel.costLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Style + resolution

    private var styleAndResolutionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
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

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionLabel(text: "Export resolution")
                    Picker("Resolution", selection: $viewModel.parameters.resolution) {
                        ForEach(Resolution.allCases) { res in
                            Text(res.displayName).tag(res)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(viewModel.parameters.resolution.pixelDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
        VStack(spacing: Spacing.md) {
            Button {
                viewModel.generate(promptMode: .standard)
            } label: {
                Label("Generate stencil", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .keyboardShortcut("g", modifiers: [.command])
            .liquidGlassButton(.prominent)
            .disabled(!viewModel.canGenerate)

            Button {
                viewModel.generate(promptMode: .technical_trace)
            } label: {
                Label("Technical trace", systemImage: "square.dashed")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
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
                Label("Heads up: at 4K the source image is going to look soft.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppColor.danger)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Tier chip

private struct TierChip: View {
    let tier: ModelTier
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: tier.isLocal ? "cpu" : "sparkles")
                        .font(.caption)
                        .foregroundStyle(isSelected ? AppColor.accent : .secondary)
                    Text(tier.displayName)
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(.primary)
                }
                Text(tier.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(width: 200, alignment: .leading)
            .liquidGlassChip(
                tint: isSelected ? AppColor.accent : nil,
                prominent: isSelected
            )
        }
        .buttonStyle(.plain)
    }
}
