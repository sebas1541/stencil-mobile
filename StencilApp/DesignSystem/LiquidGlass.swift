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

// MARK: - Content-layer card
//
// IMPORTANT — these are CONTENT-LAYER surfaces. Per Apple's iPadOS 26
// design guidance (HIG: Materials, "Adopting Liquid Glass"), Liquid Glass
// is reserved for the NAVIGATION layer — toolbars, tab bars, sidebars.
// Content cards must use standard materials. This modifier therefore
// always renders `.regularMaterial`, even on iOS 26.
//
// Use `.liquidGlassNavigationSurface()` instead for the top toolbar /
// sidebar surfaces where genuine Liquid Glass is appropriate.

struct LiquidGlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColor.borderSubtle.opacity(0.6), lineWidth: 0.5)
                    )
            }
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Navigation-layer Liquid Glass surface

/// Use this for surfaces that genuinely belong in Apple's navigation
/// layer — top toolbar background, sidebar background, floating action
/// chips that overlay scrolling content.
struct LiquidGlassNavigationSurface: ViewModifier {
    let shape: ContainerShape

    enum ContainerShape {
        case capsule
        case rect(cornerRadius: CGFloat)
    }

    func body(content: Content) -> some View {
        content.background {
            navigationBackground
        }
    }

    @ViewBuilder
    private var navigationBackground: some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .capsule)
            case let .rect(cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            switch shape {
            case .capsule:
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            case let .rect(cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
        }
    }
}

extension View {
    func liquidGlassNavigationSurface(_ shape: LiquidGlassNavigationSurface.ContainerShape) -> some View {
        modifier(LiquidGlassNavigationSurface(shape: shape))
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
