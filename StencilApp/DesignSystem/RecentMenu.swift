import SwiftUI

/// "Recent ▾" menu at the top-left of the toolbar. Replaces the sidebar's
/// "Recent" section. Tapping a row applies that history entry to the editor
/// view model and switches the user back to the Generate section.
struct RecentMenu: View {
    @Bindable var history: HistoryStore
    var maxRows: Int = 8
    var onSelect: (GenerationHistoryEntry) -> Void
    var onClear: () -> Void

    var body: some View {
        Menu {
            if history.entries.isEmpty {
                Text("No recent generations yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history.entries.prefix(maxRows)) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(entry.tier.displayName) · \(entry.estilo.displayName)")
                            Text(entry.subtitle)
                                .font(.caption)
                        }
                    }
                }
                Divider()
                Button(role: .destructive, action: onClear) {
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
            .padding(.vertical, Spacing.sm)
            .liquidGlassChip(tint: nil, prominent: false)
        }
    }
}
