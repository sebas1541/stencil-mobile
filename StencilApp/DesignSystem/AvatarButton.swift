import SwiftUI

/// Circular avatar chip at the right of the top toolbar. Real Liquid Glass
/// capsule on iPadOS 26 with the initial centered on top — same vocabulary
/// as the other floating toolbar chips.
struct AvatarButton: View {
    var initials: String = "S"
    var diameter: CGFloat = 38
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(initials)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppColor.accent)
                .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
        .liquidGlassNavigationSurface(.capsule)
        .accessibilityLabel("Account")
    }
}
