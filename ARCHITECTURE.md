# Stencil iPad app — architecture

A short tour of the moving pieces so future contributors can find their way without re-reading every file.

## Stack

- **Swift 5.10 / SwiftUI** with `@Observable` (iOS 17+)
- **iOS / iPadOS 17.0** minimum deployment target
- **No third-party dependencies** — Apple frameworks only:
  - SwiftUI, UIKit
  - Core Image + Core Image Kernel Language
  - PencilKit
  - PhotoKit (PhotosUI + Photos)
  - Foundation, Combine
- **xcodegen** generates `StencilApp.xcodeproj` from `project.yml` so the project file stays diffable.

## High-level shape

```
RootView (NavigationSplitView)
├── Sidebar
│   ├── Workspace
│   │   ├── New stencil  → EditorContainerView
│   │   └── Settings     → SettingsView
│   └── Recent
│       └── tap → editorViewModel.apply(history:) + select New stencil
└── Detail
    ├── EditorContainerView
    │   ├── .configure  → EditorConfigureView (ImportCard + tier/style/resolution/prompt + Generate)
    │   ├── .generating → GeneratingView
    │   ├── .result     → ResultView
    │   │                  ├── tab: Retouch  → RetouchPanel
    │   │                  ├── tab: Overlay  → OverlayPanel
    │   │                  ├── tab: Annotate → AnnotationPanel (PencilKit)
    │   │                  ├── tab: Export   → ExportPanel
    │   │                  └── Inspector     → ResultInspector
    │   └── .failed     → FailureView
    └── SettingsView
```

`EditorViewModel` is owned by `RootView` so the sidebar can mutate the editor form (history re-apply) before the editor pane re-appears.

## Module layout

```
StencilApp/
  App/           — @main, RootView, history-aware sidebar
  DesignSystem/  — Colors, Theme, LiquidGlass modifiers, ZoomableImageView, GlassImagePreview
  Core/          — Models (Codable mirror of FastAPI contract), enums, CostTable, APILimits
  Services/      — APIClient, StencilService, RetouchEngine, OverlayCompositor,
                   ProcreateExporter, PhotoSaver, HistoryStore
  Features/
    Import/      — ImportCardView (PhotosPicker + drag-drop, 15 MB cap)
    Editor/      — EditorViewModel, EditorContainerView, EditorConfigureView
    Result/      — RetouchViewModel, ResultView, RetouchPanel, OverlayPanel,
                   AnnotationCanvas, AnnotationPanel, ExportPanel, ResultInspector
    Settings/    — SettingsView (@AppStorage-backed base URL + api key + /health probe)
  Resources/     — Assets.xcassets (7 colour tokens light/dark + AppIcon), Info.plist
StencilAppTests/ — Models, StencilParameters, HistoryStore, ProcreateExporter XCTests
```

## Design system

### Colour tokens
Seven semantic tokens in the Asset Catalog, each with light + dark variants:

| Token | Role |
|---|---|
| `PrimaryBackground` | App-level canvas |
| `SecondaryBackground` | Inputs, raised surfaces inside cards |
| `CanvasBackground` | Image previews (white in light, near-black in dark) |
| `Accent` | Primary glass tint, button fills, focus rings |
| `AccentSecondary` | Cyan / teal — chart accents, secondary CTAs |
| `Danger` | Errors, destructive actions, warnings |
| `BorderSubtle` | Card borders, dashed drop targets |

Accessed via the `AppColor` enum. **Never hard-code colours in feature code.**

### Liquid Glass
`DesignSystem/LiquidGlass.swift` exposes three modifiers, each branching on `iOS 26`:

| API | iOS 26 | iOS 17–25 fallback |
|---|---|---|
| `.liquidGlassCard(cornerRadius:)` | `.glassEffect(.regular, in: .rect(...))` | `RoundedRectangle.fill(.regularMaterial)` + subtle border |
| `.liquidGlassChip(tint:prominent:)` | `.glassEffect(.regular[.tint(...)], in: .capsule)` | `Capsule.fill(.thinMaterial / .ultraThinMaterial)` + border |
| `.liquidGlassButton(.prominent/.subtle)` | `.buttonStyle(.glassProminent / .glass)` | `.buttonStyle(.borderedProminent / .bordered)` |

Plus `View.ifAvailable26 { ... }` to gate any other 26-only modifier inline.

### Reusable views
- `ZoomableImageView` — UIScrollView-backed image with pinch + pan + double-tap to reset, ranges 1×–6×.
- `GlassImagePreview` — standard glass card frame around a `ZoomableImageView`; used by every preview surface.
- `SectionLabel` — small uppercase label above grouped controls.

## Networking flow

1. UI builds a `StencilParameters` (the user's local-side config + a fresh `requestId: UUID`).
2. UI gives `StencilService.generate(imageData:filename:params:)` the bytes.
3. Service does the three-step round trip:
   1. `POST /presigned-upload { filename }` → `{ upload_url, s3_key }`
   2. `PUT <upload_url>` with the bytes (auth is in the presigned URL — no `X-Api-Key`)
   3. `POST /stencil { request_id, s3_key, … }` → `StencilResponse`
4. ViewModel transitions to `.result(response, sourcePreview:)` and `HistoryStore.record(...)` appends.

Errors are surfaced through `APIError`, which conforms to `LocalizedError`.

Client-side guards before the round trip:
- Image must be ≤ 15 MB (`APILimits.maxImageBytes`).
- `request_id` is a UUID v4.
- `prompt_mode == .technical_trace` is rejected if `tier == .nano`.

## Retouching pipeline

`RetouchEngine` is a stateless Core Image chain operating on a cached `CGImage`. Every slider/toggle change schedules a 30 ms-debounced render on a background `Task` with cancellation.

Order matters — same order as `frontend/app.py:_apply_retouching_binary`:

1. **Threshold** (`CIColorThreshold`) with the same line-thickness coupling as the frontend: `threshold += clamp(weight*4, ±24)`.
2. **Line thickness** (`CIMorphologyMinimum/Maximum`) — gated to `|weight| ≥ 4` to match the frontend no-op band.
3. **Denoise** — morphological opening with small radius.
4. **Noise filter** — opening with stronger radius.
5. **Close gaps** — morphological closing.
6. **Smooth** — open + close with ellipse-radius kernels.
7. **Sharpen** — small close.
8. **Invert** — `CIColorInvert`.
9. **Line colour** — custom `CIColorKernel` that mixes the chosen RGB in for dark pixels and keeps white pixels white. Source kept simple (Core Image Kernel Language); migrating to a precompiled `.metal` file is a future polish that would eliminate the only deprecation warning in the project.

`OverlayCompositor` is a single custom `CIKernel` that follows the frontend math 1:1:
```
canvas    = ref * refAlpha + white * (1 - refAlpha)
linesMask = stencil.gray < 0.5
canvas    = mix(canvas, tinted_canvas, linesMask)
```

## Annotation pipeline

`PKCanvasView` (wrapped in `AnnotationCanvas`) is overlaid on top of the retouched stencil. The `PKDrawing` is two-way-bound to the `RetouchViewModel`, so strokes survive tab switches.

Export composites the drawing onto the retouched stencil with `UIGraphicsImageRenderer` at the stencil's native pixel size:
```swift
renderer.image { _ in
    base.draw(in: rect)
    annotationDrawing.image(from: rect, scale: 1).draw(in: rect)
}
```

## History

`HistoryStore` (`@Observable`, `@MainActor`) persists the last 20 successful generations as JSON in `UserDefaults`. Each entry stores **parameters only**:
- Image bytes would balloon `UserDefaults`.
- Presigned URLs expire (1 h by default per the FastAPI config) so storing them adds no value.
- Re-applying an entry refills the form; the user picks a fresh image.

The store dedupes by `request_id`, caps at `HistoryStore.maxEntries = 20`, and persists best-effort (a failed write logs and is never fatal).

## What's intentionally not in v1

| Feature | Why deferred | What it needs |
|---|---|---|
| Procreate PSD multi-layer export | The server-side path runs in-process Python (`app/pipeline/procreate_layers.py`) and is not exposed over HTTP | Add `POST /procreate-layers` to the microservice that wraps `generate_procreate_api_layers` + `export_api_procreate_layers`, then wire a fourth export row that ships the PSD bytes |
| Metal-precompiled CIKernels | The Core Image Kernel Language API still works on iOS 26; replacing it would require a `.metal` file in the bundle with `-fcikernel` flags | A small Metal source file + `CIColorKernel(functionName:fromMetalLibraryData:)` |
| Recent generation thumbnails in the sidebar | Source/preview URLs expire | Store a downscaled local PNG alongside each history entry (with a size budget) |
| Stage Manager polish | Layouts work but could be tuned for very narrow windows | Test in Stage Manager + tune sidebar/inspector minimum widths |
| Background generation continuation | A backgrounded app cancels the URLSession task | Move uploads/generations to a `URLSessionConfiguration.background` configuration |

## Building

```bash
brew install xcodegen   # one-time
xcodegen generate
open StencilApp.xcodeproj
```

Tests run from Xcode (`⌘U`) or via:
```bash
xcodebuild test \
  -project StencilApp.xcodeproj \
  -scheme StencilApp \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'
```

(Requires an iPad simulator runtime installed. `xcodebuild -downloadPlatform iOS` from a fresh Xcode install if you haven't yet — ~7 GB download.)
