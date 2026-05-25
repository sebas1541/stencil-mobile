import SwiftUI

/// Spacing, radius, and typography scales used across the app.
/// Numbers are intentional — change them here, never inline in views.
enum Radius {
    /// Small chips, tight controls.
    static let sm: CGFloat = 8
    /// Default control radius (buttons, segmented controls, inputs).
    static let md: CGFloat = 12
    /// Large surfaces (cards, sheets, glass panels).
    static let lg: CGFloat = 20
    /// Hero containers (canvas frame, full-bleed panels).
    static let xl: CGFloat = 28
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppFont {
    static let sectionLabel = Font.caption.weight(.semibold)
    static let bodyEmphasis = Font.body.weight(.semibold)
    static let kpiNumber    = Font.title2.weight(.semibold)
}
