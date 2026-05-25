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

/// Use this for surfaces that belong in Apple's navigation layer — top
/// toolbar chips, sidebar background, floating action chips that overlay
/// scrolling content.
///
/// Implementation note: on iPadOS 26 we apply `.glassEffect()` DIRECTLY to
/// the content view (the Apple-correct API), NOT as a `background { ... }`
/// with a `.fill(.clear)` shape. Earlier versions did the latter and
/// SwiftUI optimised the empty fill away, which is why the glass was
/// rendering invisibly on the toolbar chips.
struct LiquidGlassNavigationSurface: ViewModifier {
    enum ContainerShape {
        case capsule
        case rect(cornerRadius: CGFloat)
    }

    let shape: ContainerShape
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            applyGlass(to: content)
        } else {
            applyFallback(to: content)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func applyGlass(to content: Content) -> some View {
        let glass: Glass = tint.map { Glass.regular.tint($0) } ?? .regular

        switch shape {
        case .capsule:
            content.glassEffect(glass, in: .capsule)
        case let .rect(cornerRadius):
            content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    private func applyFallback(to content: Content) -> some View {
        let fill: AnyShapeStyle = tint
            .map { AnyShapeStyle($0.opacity(0.88)) }
            ?? AnyShapeStyle(.ultraThinMaterial)
        switch shape {
        case .capsule:
            content.background {
                Capsule(style: .continuous)
                    .fill(fill)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
        case let .rect(cornerRadius):
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
        }
    }
}

extension View {
    /// Apply navigation-layer Liquid Glass to a view (toolbar chip / floating
    /// action). Pass `tint:` to give the glass a coloured wash — e.g.
    /// `.liquidGlassNavigationSurface(.capsule, tint: AppColor.accent)` for
    /// the primary "New" button.
    func liquidGlassNavigationSurface(
        _ shape: LiquidGlassNavigationSurface.ContainerShape,
        tint: Color? = nil
    ) -> some View {
        modifier(LiquidGlassNavigationSurface(shape: shape, tint: tint))
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
        switch kind {
        case .prominent:
            // Primary action — Apple recommends .glassProminent for the one
            // primary action per screen state, even in the content layer.
            if #available(iOS 26.0, *) {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.borderedProminent)
            }
        case .subtle:
            // Secondary actions live in the content layer and per Apple HIG
            // should be standard bordered buttons, NOT extra Liquid Glass.
            // We deliberately drop the iOS 26 `.glass` mapping that was
            // here previously.
            content.buttonStyle(.bordered)
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
