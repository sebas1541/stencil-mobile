import SwiftUI

/// Right-side inspector panel shown on iPad (and iPhone landscape) when the
/// user opens the "i" button. Surfaces every field the API returns so power
/// users can audit cost / processing / quality without leaving the result.
struct ResultInspector: View {
    let response: StencilResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                summarySection
                processingSection
                contentSection
                costSection
            }
            .padding(Spacing.lg)
        }
        .background(AppColor.primaryBackground)
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Summary")
                .font(.headline)
            row(label: "Tier",        value: response.usage.tier)
            row(label: "Resolution",  value: response.usage.outputResolution)
            row(label: "Format",      value: response.formato)
            row(label: "Request ID",  value: String(response.usage.requestId.prefix(8)))
        }
        .padding(Spacing.lg)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Processing")
                .font(.headline)
            row(label: "Wall time", value: "\(response.usage.processingTimeMs) ms")
            row(label: "Gemini calls", value: "\(response.usage.geminiCalls)")
            row(label: "Source size", value: String(format: "%.2f Mpx", response.usage.inputMpx))
            if response.usage.resolutionWarning {
                Label("Low-resolution source for the requested output",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppColor.danger)
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.lg)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Detected content")
                .font(.headline)
            row(label: "Category", value: response.contentType)
            row(label: "Confidence", value: "\(Int(response.contentConfidence * 100))%")
        }
        .padding(Spacing.lg)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Estimated cost")
                .font(.headline)
            Text(CostTable.label(
                tier: tierEnum(),
                resolution: resolutionEnum()
            ))
            .font(.subheadline.weight(.medium))
            Text("Display-only — the server does not enforce or report a real bill.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .liquidGlassCard(cornerRadius: Radius.md)
    }

    // MARK: - Helpers

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
        }
    }

    private func tierEnum() -> ModelTier {
        ModelTier(rawValue: response.usage.tier) ?? .flash
    }

    private func resolutionEnum() -> Resolution {
        Resolution(rawValue: response.usage.outputResolution) ?? .p4K
    }
}
