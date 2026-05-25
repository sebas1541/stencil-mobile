import SwiftUI

/// "Spotlight-style" global search at the right of the toolbar. Indexes four
/// kinds of things at once: sections, tattoo styles, settings shortcuts, and
/// recent generations from the `HistoryStore`. Tapping a result fires the
/// appropriate callback on the parent.
struct GlobalSearchField: View {
    @Bindable var history: HistoryStore

    @Binding var query: String
    @FocusState private var isFocused: Bool

    var onPickSection: (AppSection) -> Void
    var onPickStyle: (StyleName) -> Void
    var onPickSettings: () -> Void
    var onPickHistory: (GenerationHistoryEntry) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            field
            if isFocused {
                results
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.18), value: isFocused)
        .animation(.snappy(duration: 0.18), value: trimmedQuery)
    }

    // MARK: - Field

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)
            if !trimmedQuery.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minWidth: 220, maxWidth: 320)
        .liquidGlassChip(tint: nil, prominent: false)
    }

    // MARK: - Results dropdown

    @ViewBuilder
    private var results: some View {
        let sectionHits = matchingSections
        let styleHits   = matchingStyles
        let settingHits = matchingSettings
        let historyHits = matchingHistory

        if sectionHits.isEmpty && styleHits.isEmpty
            && settingHits.isEmpty && historyHits.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("No matches")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard(cornerRadius: Radius.md)
            .padding(.top, 6)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !sectionHits.isEmpty {
                    group(title: "Sections") {
                        ForEach(sectionHits) { section in
                            row(
                                icon: section.systemImage,
                                title: section.displayName,
                                subtitle: nil
                            ) {
                                commit { onPickSection(section) }
                            }
                        }
                    }
                }
                if !styleHits.isEmpty {
                    group(title: "Styles") {
                        ForEach(styleHits) { style in
                            row(
                                icon: "paintbrush",
                                title: style.displayName,
                                subtitle: "Apply + go to Generate"
                            ) {
                                commit { onPickStyle(style) }
                            }
                        }
                    }
                }
                if !settingHits.isEmpty {
                    group(title: "Settings") {
                        ForEach(settingHits, id: \.self) { hint in
                            row(
                                icon: "gearshape",
                                title: hint,
                                subtitle: "Open settings"
                            ) {
                                commit { onPickSettings() }
                            }
                        }
                    }
                }
                if !historyHits.isEmpty {
                    group(title: "History") {
                        ForEach(historyHits) { entry in
                            row(
                                icon: "clock",
                                title: "\(entry.tier.displayName) · \(entry.estilo.displayName)",
                                subtitle: entry.subtitle
                            ) {
                                commit { onPickHistory(entry) }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .liquidGlassCard(cornerRadius: Radius.md)
            .padding(.top, 6)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func row(
        icon: String,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func commit(_ action: () -> Void) {
        action()
        query = ""
        isFocused = false
    }

    // MARK: - Index

    private var matchingSections: [AppSection] {
        guard !trimmedQuery.isEmpty else { return AppSection.allCases }
        let q = trimmedQuery.lowercased()
        return AppSection.allCases.filter { $0.displayName.lowercased().contains(q) }
    }

    private var matchingStyles: [StyleName] {
        guard !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery.lowercased()
        return StyleName.allCases.filter { style in
            style.displayName.lowercased().contains(q)
                || style.rawValue.lowercased().contains(q)
        }
    }

    private var matchingSettings: [String] {
        guard !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery.lowercased()
        let candidates = ["API base URL", "X-Api-Key", "Photo permissions", "Test /health"]
        return candidates.filter { $0.lowercased().contains(q) }
    }

    private var matchingHistory: [GenerationHistoryEntry] {
        let entries = history.entries
        guard !trimmedQuery.isEmpty else { return Array(entries.prefix(5)) }
        let q = trimmedQuery.lowercased()
        return entries.filter { entry in
            entry.tier.displayName.lowercased().contains(q)
                || entry.estilo.displayName.lowercased().contains(q)
                || (entry.contentType ?? "").lowercased().contains(q)
        }
    }
}
