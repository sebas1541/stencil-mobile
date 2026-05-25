import SwiftUI

// MARK: - Availability helper

extension View {
    /// Applies `transform` only on iOS/iPadOS 26+. Used to gate Liquid Glass
    /// modifiers without forking the view tree.
    @ViewBuilder
    func ifAvailable26<Content: View>(
        _ transform: (Self) -> Content
    ) -> some View {
        if #available(iOS 26.0, *) {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Glass card

/// Card-style surface. Liquid Glass on 26+, `.regularMaterial` fallback below.
struct LiquidGlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                }
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(AppColor.borderSubtle, lineWidth: 0.5)
                        )
                }
        }
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass chip (capsule)

/// Pill-shaped glass surface used for chips, swatches, small toolbars.
struct LiquidGlassChip: ViewModifier {
    let tint: Color?
    let isProminent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    Color.clear.glassEffect(
                        glassConfig,
                        in: .capsule
                    )
                }
        } else {
            content
                .background {
                    Capsule(style: .continuous)
                        .fill(isProminent ? .thinMaterial : .ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(borderColor, lineWidth: isProminent ? 1 : 0.5)
                        )
                }
        }
    }

    @available(iOS 26.0, *)
    private var glassConfig: Glass {
        if let tint, isProminent {
            return .regular.tint(tint)
        } else if let tint {
            return .regular.tint(tint.opacity(0.6))
        } else {
            return .regular
        }
    }

    private var borderColor: Color {
        if isProminent { return tint ?? AppColor.accent }
        return AppColor.borderSubtle
    }
}

extension View {
    func liquidGlassChip(tint: Color? = nil, prominent: Bool = false) -> some View {
        modifier(LiquidGlassChip(tint: tint, isProminent: prominent))
    }
}

// MARK: - Glass button styling helper

/// Apply the right button style for the deployment target.
/// - `.prominent` → `.glassProminent` on 26+, `.borderedProminent` below.
/// - `.subtle`    → `.glass` on 26+, `.bordered` below.
enum GlassButtonKind {
    case prominent
    case subtle
}

struct LiquidGlassButtonStyle: ViewModifier {
    let kind: GlassButtonKind

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch kind {
            case .prominent: content.buttonStyle(.glassProminent)
            case .subtle:    content.buttonStyle(.glass)
            }
        } else {
            switch kind {
            case .prominent: content.buttonStyle(.borderedProminent)
            case .subtle:    content.buttonStyle(.bordered)
            }
        }
    }
}

extension View {
    func liquidGlassButton(_ kind: GlassButtonKind = .prominent) -> some View {
        modifier(LiquidGlassButtonStyle(kind: kind))
    }
}

// MARK: - Section label

/// Small uppercase caption used above grouped controls.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
