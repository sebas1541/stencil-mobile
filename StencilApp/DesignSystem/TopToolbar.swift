import SwiftUI

/// The Calendar-style top toolbar: floating glass bar with three groups.
///
///   [+ New] [Recent ▾]   [ Generate │ Refine │ Annotate │ Export ]   [🔍 ___] (●)
///
/// - Left group: New button + Recent menu (replaces the old sidebar)
/// - Centre:     segmented section picker
/// - Right:      global search field + avatar that opens the settings sheet
struct TopToolbar: View {
    @Binding var selectedSection: AppSection
    @Binding var searchQuery: String

    /// Reflects which sections are disabled because there's no result yet.
    let isResultReady: Bool

    @Bindable var history: HistoryStore

    var onNew: () -> Void
    var onPickHistory: (GenerationHistoryEntry) -> Void
    var onClearHistory: () -> Void
    var onShowAccount: () -> Void
    var onPickStyle: (StyleName) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
            compactLayout
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        // Navigation-layer Liquid Glass surface (Apple's floating-pill
        // aesthetic from the App Store / Maps / Calendar headers).
        .liquidGlassNavigationSurface(.capsule)
        // Per Apple HIG / "Adopting Liquid Glass", the material itself
        // provides elevation — manual stacked shadows would muddy the
        // hierarchy. Single soft shadow only.
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 6)
    }

    // MARK: - Regular (iPad / unsplit)

    private var regularLayout: some View {
        HStack(spacing: Spacing.md) {
            leftGroup
            Spacer()
            sectionPicker
                .frame(maxWidth: 460)
            Spacer()
            rightGroup
        }
    }

    // MARK: - Compact (iPhone / Stage Manager narrow)

    private var compactLayout: some View {
        HStack(spacing: Spacing.sm) {
            Menu {
                Button {
                    onNew()
                } label: {
                    Label("New stencil", systemImage: "plus")
                }
                Section("Recent") {
                    if history.entries.isEmpty {
                        Text("No recent generations")
                    } else {
                        ForEach(history.entries.prefix(8)) { entry in
                            Button {
                                onPickHistory(entry)
                            } label: {
                                Text("\(entry.tier.displayName) · \(entry.estilo.displayName)")
                            }
                        }
                        Divider()
                        Button(role: .destructive, action: onClearHistory) {
                            Label("Clear history", systemImage: "trash")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .liquidGlassChip()
            }

            sectionMenu

            Spacer(minLength: 0)

            compactSearchButton
            AvatarButton(onTap: onShowAccount)
        }
    }

    // MARK: - Pieces

    private var leftGroup: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onNew) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.callout.weight(.semibold))
                    Text("New")
                        .font(.callout.weight(.medium))
                }
                // White-on-tint when prominent; the chip's tint is the accent,
                // so the label/icon need to be foreground-light for contrast.
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .liquidGlassChip(tint: AppColor.accent, prominent: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New stencil")

            RecentMenu(
                history: history,
                onSelect: onPickHistory,
                onClear: onClearHistory
            )
        }
    }

    /// Apple-style segmented picker. The selected indicator is a Liquid Glass
    /// pill that *slides* between segments via `matchedGeometryEffect`, the
    /// way Apple does it in the App Store / Maps / Calendar headers (iOS 26).
    ///
    /// Text colour stays `.primary` for every segment — selection is
    /// communicated by the glass pill behind the selected label, not by
    /// recolouring the text.
    @Namespace private var selectionNamespace

    private var sectionPicker: some View {
        HStack(spacing: 2) {
            ForEach(AppSection.allCases) { section in
                Button {
                    // Spring matches Apple's stock segmented control feel.
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .contentShape(Capsule())
                        .background(alignment: .center) {
                            if selectedSection == section {
                                selectedPill
                                    .matchedGeometryEffect(
                                        id: "section.selected",
                                        in: selectionNamespace
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(trackBackground)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The selected pill — opaque system-background fill with a hairline
    /// border + soft drop shadow, so it reads as a distinct surface
    /// floating above the translucent track. iOS 26 also overlays a
    /// `.glassEffect` so it picks up Liquid Glass refraction.
    @ViewBuilder
    private var selectedPill: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color(uiColor: .systemBackground))
            if #available(iOS 26.0, *) {
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    /// "Track" behind all segments — slightly tinted neutral so the white
    /// pill above visibly contrasts even in light mode. Matches the App
    /// Store header treatment.
    @ViewBuilder
    private var trackBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.06))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            )
    }

    private var rightGroup: some View {
        HStack(spacing: Spacing.md) {
            GlobalSearchField(
                history: history,
                query: $searchQuery,
                onPickSection: { section in
                    selectedSection = section
                },
                onPickStyle: onPickStyle,
                onPickSettings: onShowAccount,
                onPickHistory: onPickHistory
            )
            AvatarButton(onTap: onShowAccount)
        }
    }

    private var sectionMenu: some View {
        Menu {
            ForEach(AppSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.displayName, systemImage: section.systemImage)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedSection.systemImage)
                Text(selectedSection.displayName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(AppColor.accent)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .liquidGlassChip()
        }
    }

    private var compactSearchButton: some View {
        // On compact width, replace the inline field with an icon-only
        // entry point. Tapping triggers the same focus state by writing a
        // space then clearing — keeps the parent state machine simple.
        Image(systemName: "magnifyingglass")
            .font(.callout)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .liquidGlassChip()
            .accessibilityLabel("Search")
    }
}
