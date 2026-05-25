import SwiftUI

/// Circular avatar at the right of the top toolbar. Tap opens the account /
/// settings sheet. The visual is a gradient circle with the user's initials
/// — placeholder for v1, will hook up to Sign-in-with-Apple later.
struct AvatarButton: View {
    var initials: String = "S"
    var diameter: CGFloat = 34
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.accent, AppColor.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: diameter, height: diameter)

                Text(initials)
                    .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: AppColor.accent.opacity(0.25), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account")
    }
}
