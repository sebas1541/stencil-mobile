import SwiftUI

/// Top-of-screen toolbar made of SEPARATE floating Liquid Glass capsules,
/// the way Apple's iPad apps (App Store, Maps, Calendar) lay out their
/// header chrome. Each chip is its own glass capsule; on iPadOS 26 they're
/// grouped inside a `GlassEffectContainer` so they share a sampling region
/// and morph smoothly when one of them resizes (search expand/collapse).
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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
    }

    // MARK: - Regular layout (iPad)

    private var regularLayout: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    regularContent
                }
            } else {
                regularContent
            }
        }
    }

    private var regularContent: some View {
        HStack(spacing: Spacing.sm) {
            newChip
            recentChip

            Spacer(minLength: Spacing.md)

            sectionPicker

            Spacer(minLength: Spacing.md)

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
                .liquidGlassNavigationSurface(.capsule)
        }
    }

    // MARK: - Compact layout (iPhone / Stage Manager narrow)

    private var compactLayout: some View {
        HStack(spacing: Spacing.sm) {
            overflowMenu
                .liquidGlassNavigationSurface(.capsule)

            sectionMenu
                .liquidGlassNavigationSurface(.capsule)

            Spacer(minLength: 0)

            GlobalSearchField(
                history: history,
                query: $searchQuery,
                onPickSection: { selectedSection = $0 },
                onPickStyle: onPickStyle,
                onPickSettings: onShowAccount,
                onPickHistory: onPickHistory
            )

            AvatarButton(onTap: onShowAccount)
                .liquidGlassNavigationSurface(.capsule)
        }
    }

    // MARK: - Chips

    private var newChip: some View {
        Button(action: onNew) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.callout.weight(.semibold))
                Text("New")
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background {
            Capsule(style: .continuous)
                .fill(AppColor.accent)
        }
        .accessibilityLabel("New stencil")
    }

    private var recentChip: some View {
        Menu {
            if history.entries.isEmpty {
                Text("No recent generations yet")
            } else {
                ForEach(history.entries.prefix(8)) { entry in
                    Button {
                        onPickHistory(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(entry.tier.displayName) · \(entry.estilo.displayName)")
                            Text(entry.subtitle).font(.caption)
                        }
                    }
                }
                Divider()
                Button(role: .destructive, action: onClearHistory) {
                    Label("Clear history", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.callout)
                Text("Recent")
                    .font(.callout.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(AppColor.accent)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
        }
        .liquidGlassNavigationSurface(.capsule)
    }

    /// System `Picker(.segmented)`. On iPadOS 26 the segmented picker IS
    /// Liquid Glass — Apple-stock spring, adaptive labels, sliding pill.
    /// Per HIG ("Build a SwiftUI app with the new design"): use the system
    /// control and don't override its animation.
    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                Text(section.displayName).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Compact helpers

    private var overflowMenu: some View {
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
            .padding(.vertical, 8)
        }
    }
}
