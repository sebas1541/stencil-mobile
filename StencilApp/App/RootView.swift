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
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .newStencil, .none:
            EditorContainerView()
        case .settings:
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    RootView()
        .tint(AppColor.accent)
}
