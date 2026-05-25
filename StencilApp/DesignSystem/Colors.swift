import SwiftUI

/// Semantic color tokens backed by the Asset Catalog.
///
/// Light theme leans slate-blue / blue-violet; dark theme leans navy with a
/// brighter violet accent. Tokens are referenced everywhere in the UI — never
/// hard-code a `Color` literal in feature code.
enum AppColor {
    static let primaryBackground   = Color("PrimaryBackground")
    static let secondaryBackground = Color("SecondaryBackground")
    static let canvasBackground    = Color("CanvasBackground")

    static let accent          = Color("Accent")
    static let accentSecondary = Color("AccentSecondary")
    static let danger          = Color("Danger")

    static let borderSubtle = Color("BorderSubtle")
}
