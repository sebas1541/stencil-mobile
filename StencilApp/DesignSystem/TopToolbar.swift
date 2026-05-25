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

    /// System `Picker(.segmented)` — on iPadOS 26 this control automatically
    /// adopts Liquid Glass, including the sliding pill, the correct spring
    /// motion, and adaptive label colours. Apple's design sessions
    /// explicitly say "you get the correct motion only by using the system
    /// control and not overriding its animation" — so the previous custom
    /// matchedGeometryEffect pill is gone.
    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                Text(section.displayName).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
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
