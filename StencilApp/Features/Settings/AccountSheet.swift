import SwiftUI
import UIKit

/// Sheet that opens when the user taps the avatar in the top toolbar.
/// Wraps the existing `SettingsView` with a small account card on top.
/// Account / Sign-in-with-Apple is intentionally placeholder for v1.
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    accountCard
                    SettingsView()
                        .padding(.horizontal, -Spacing.xl)
                }
                .padding(Spacing.xl)
            }
            .scrollClipDisabled()
            .background(AppColor.primaryBackground.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Account card

    private var accountCard: some View {
        HStack(spacing: Spacing.lg) {
            AvatarButton(initials: initialsForDevice(),
                         diameter: 56,
                         onTap: {})
                .disabled(true)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text(UIDevice.current.name)
                    .font(.headline)
                Text("Signed in locally · Sign in with Apple coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard()
    }

    private func initialsForDevice() -> String {
        let name = UIDevice.current.name
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "S" }
        return String(first).uppercased()
    }
}
