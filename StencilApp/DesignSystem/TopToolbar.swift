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
        .padding(.vertical, Spacing.sm)
        .liquidGlassCard(cornerRadius: Radius.lg)
        // Subtle elevation so the bar reads as "above the content layer"
        // even when the underlying canvas is the same hue. Two shadows give a
        // softer, more Apple-y feel than a single hard one.
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.04), radius: 2,  x: 0, y: 1)
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

    /// Custom segmented picker built from glass chips so we get a clearly
    /// visible "selected" state instead of the very subtle default segmented
    /// control. Matches Calendar's Day/Week/Month/Year vibe more closely.
    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(AppSection.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            selectedSection == section ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background {
                            if selectedSection == section {
                                Capsule(style: .continuous)
                                    .fill(AppColor.accent)
                                    .shadow(color: AppColor.accent.opacity(0.35), radius: 6, x: 0, y: 2)
                            } else {
                                Capsule(style: .continuous)
                                    .fill(Color.clear)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(AppColor.borderSubtle, lineWidth: 0.5)
                )
        }
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
