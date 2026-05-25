import Foundation

/// Top-level navigation buckets. Mapped 1:1 to the segmented control at the
/// centre of the toolbar — same role as Day/Week/Month/Year in Calendar.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case generate
    case refine
    case annotate
    case export

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generate: return "Generate"
        case .refine:   return "Refine"
        case .annotate: return "Annotate"
        case .export:   return "Export"
        }
    }

    /// SF Symbol used in compact-width fallback menus and accessibility.
    var systemImage: String {
        switch self {
        case .generate: return "wand.and.sparkles"
        case .refine:   return "slider.horizontal.3"
        case .annotate: return "pencil.tip"
        case .export:   return "square.and.arrow.up"
        }
    }

    /// Whether the section requires a generated stencil before it makes sense.
    /// Used by `RootView` to disable segments and snap back to `.generate`
    /// when the user lands on a result-only section without a result yet.
    var requiresResult: Bool {
        switch self {
        case .generate: return false
        case .refine, .annotate, .export: return true
        }
    }
}
