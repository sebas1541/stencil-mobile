import SwiftUI

/// Apple Mail / Notes style: starts as a small magnifier icon chip, expands
/// into a full search field on tap. While expanded, shows a Spotlight-like
/// dropdown that indexes sections, tattoo styles, settings shortcuts, and
/// recent generations from the `HistoryStore`.
///
/// Uses `matchedGeometryEffect` so the chip morphs between states inside a
/// parent `GlassEffectContainer` — the Apple-recommended pattern.
struct GlobalSearchField: View {
    @Bindable var history: HistoryStore
    @Binding var query: String

    @State private var isExpanded: Bool = false
    @FocusState private var isFocused: Bool
    @Namespace private var morphNamespace

    var onPickSection: (AppSection) -> Void
    var onPickStyle: (StyleName) -> Void
    var onPickSettings: () -> Void
    var onPickHistory: (GenerationHistoryEntry) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if isExpanded {
                expandedField
                    .matchedGeometryEffect(id: "search.chip", in: morphNamespace)
                if isFocused {
                    results
                        .frame(maxWidth: 320, alignment: .trailing)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                collapsedButton
                    .matchedGeometryEffect(id: "search.chip", in: morphNamespace)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isExpanded)
        .animation(.snappy(duration: 0.18), value: trimmedQuery)
    }

    // MARK: - Collapsed (icon-only)

    private var collapsedButton: some View {
        Button {
            isExpanded = true
            // Defer focus so the field is in the view hierarchy before we
            // try to grab the keyboard.
            DispatchQueue.main.async { isFocused = true }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .liquidGlassNavigationSurface(.capsule)
        .accessibilityLabel("Search")
    }

    // MARK: - Expanded (full field)

    private var expandedField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Search", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)

            Button {
                if trimmedQuery.isEmpty {
                    collapse()
                } else {
                    query = ""
                }
            } label: {
                Image(systemName: trimmedQuery.isEmpty ? "xmark" : "xmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 8)
        .frame(width: 280)
        .liquidGlassNavigationSurface(.capsule)
        .onSubmit { /* nothing — selection happens via the dropdown */ }
        .onChange(of: isFocused) { _, focused in
            if !focused, trimmedQuery.isEmpty {
                // Collapse automatically when the user dismisses focus
                // without typing anything.
                collapse()
            }
        }
    }

    private func collapse() {
        query = ""
        isFocused = false
        isExpanded = false
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
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !sectionHits.isEmpty {
                    group(title: "Sections") {
                        ForEach(sectionHits) { section in
                            row(
                                icon: section.systemImage,
                                title: section.displayName,
                                subtitle: nil
                            ) { commit { onPickSection(section) } }
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
                            ) { commit { onPickStyle(style) } }
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
                            ) { commit { onPickSettings() } }
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
                            ) { commit { onPickHistory(entry) } }
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .liquidGlassCard(cornerRadius: Radius.md)
        }
    }

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
        collapse()
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
