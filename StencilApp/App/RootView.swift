import SwiftUI

/// Side-bar driven shell. Collapses automatically to a navigation stack on
/// compact width (iPhone), shows a two-column split on iPad.
struct RootView: View {
    enum SidebarItem: Hashable {
        case newStencil
        case settings
    }

    @State private var selection: SidebarItem? = .newStencil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// Owned at the shell level so a sidebar tap on a history row can mutate
    /// the editor form before switching to the Editor pane.
    @State private var editorViewModel = EditorViewModel()
    @State private var history = HistoryStore.shared

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationTitle("Stencil")
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                Label("New stencil", systemImage: "wand.and.sparkles")
                    .tag(SidebarItem.newStencil)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            } header: {
                Text("Workspace")
            }

            if !history.entries.isEmpty {
                Section {
                    ForEach(history.entries.prefix(8)) { entry in
                        HistoryRow(entry: entry) {
                            editorViewModel.apply(history: entry)
                            selection = .newStencil
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                history.remove(id: entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        history.clear()
                    } label: {
                        Label("Clear history", systemImage: "trash")
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
                } header: {
                    Text("Recent")
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .newStencil, .none:
            EditorContainerView(viewModel: editorViewModel)
        case .settings:
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: GenerationHistoryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: entry.tier == .nano ? "cpu" : "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppColor.accent)
                    Text(entry.tier.displayName)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(Self.timeFormatter.string(from: entry.createdAt))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview("iPad", traits: .landscapeLeft) {
    RootView()
        .tint(AppColor.accent)
}
