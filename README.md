# Stencil — iPad / iPhone client

Native Swift / SwiftUI client for the [stencil microservice](https://github.com/sebas1541/microservice_stencil). Built for tattoo artists working on iPad with Apple Pencil.

- **Min deployment**: iOS / iPadOS **17.0** (Liquid Glass on 26+, `Material` fallbacks below)
- **Language**: Swift 5.10
- **No third-party dependencies** — Apple frameworks only (SwiftUI, Core Image, PencilKit, PhotoKit)
- **Universal**: one target ships to iPad and iPhone

## What it does

1. **Pick or drop** a reference photo (PhotosPicker + drag-drop).
2. **Configure** style, tier, resolution, and the full `prompt_config` (background, thickness, topographic shadows + detail/weight, texture).
3. **Generate** via `POST /presigned-upload` → S3 `PUT` → `POST /stencil`. Same flow as the Python Gradio test rig.
4. **Retouch** the result locally on the GPU — threshold, line thickness, denoise, noise filter, close gaps, smooth, sharpen, invert, line colour.
5. **Overlay** the stencil on top of the reference photo with opacity / brightness sliders for placement preview.
6. **Annotate** with Apple Pencil — draws on top of the retouched stencil, palm-rest mode, ink/marker/eraser via the system tool picker.
7. **Export** as PNG via Share sheet or save directly to Photos. Three flavours: provider-native PNG, retouched PNG, Procreate-friendly transparent PNG (white → alpha).
8. **History** of the last 20 generations in the sidebar; tap to re-apply settings to the editor.

## Liquid Glass

Three reusable modifiers — `liquidGlassCard`, `liquidGlassChip`, `liquidGlassButton(.prominent/.subtle)` — branch on iOS 26 at the call site. On 26 they use `glassEffect` / `.glassProminent` / `.glass`. On 17–25 they fall back to `Material.regular` / `.ultraThinMaterial` plus tinted borders. See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design system.

The palette is slate-blue / blue-violet in light mode and navy + cyan in dark mode. Seven semantic colour tokens in the Asset Catalog cover the whole UI — there is no hard-coded colour anywhere in feature code.

## Project structure

```
StencilApp/
  App/           — @main, RootView (NavigationSplitView shell)
  DesignSystem/  — colour tokens, glass modifiers, zoomable preview wrapper
  Core/          — Codable models matching the FastAPI contract
  Services/      — APIClient + StencilService + RetouchEngine + OverlayCompositor
                   + ProcreateExporter + PhotoSaver + HistoryStore
  Features/
    Import/      — PhotosPicker + drag-drop card
    Editor/      — configure form + Generate / Technical Trace
    Result/      — Retouch / Overlay / Annotate / Export tabs + Inspector
    Settings/    — API base URL + X-Api-Key + /health probe + About
  Resources/     — Assets.xcassets + Info.plist
StencilAppTests/ — XCTest target for Models, parameters, history, exporter
```

## Getting set up

The Xcode project is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
# First-time only
brew install xcodegen

# Regenerate the .xcodeproj after editing project.yml or adding files:
xcodegen generate

# Then open Xcode and run on an iPad simulator
open StencilApp.xcodeproj
```

## Running against the microservice

By default the app talks to `http://localhost:8000`. Override in **Settings** (sidebar → Settings) at runtime — the change takes effect on the next request.

If you're running the microservice on your Mac and testing on a real iPad, point the app at your machine's LAN IP (e.g. `http://192.168.1.42:8000`). For the simulator, `localhost` works.

If the server is configured with an `API_KEY`, paste it into Settings → Authentication. The app sends it as `X-Api-Key` on every API request (but not on the S3 `PUT` — the presigned URL already encodes auth).

## Keyboard shortcuts

| Shortcut | Action | Where |
|---|---|---|
| ⌘G | Generate stencil | Editor |
| ⌘T | Technical Trace | Editor |
| ⌘N | Back to setup | Result |
| ⌘R | Test `/health` | Settings |

## Testing

```bash
xcodebuild test \
  -project StencilApp.xcodeproj \
  -scheme StencilApp \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'
```

The test target covers:
- Codable round-trips for `StencilRequest` / `StencilResponse` / `PromptConfig` (snake_case wire keys verified)
- All 15 styles, 6 tiers, 3 resolutions are present
- `CostTable` exhaustively
- `StencilParameters.validate()` (technical_trace + nano rejected on every tier permutation)
- `HistoryStore` record / dedupe / cap / clear / persist
- `ProcreateExporter` alpha pass on a 2×2 fixture with two threshold settings

## What's intentionally not in v1

| | |
|---|---|
| Procreate PSD multi-layer export | Needs a new server endpoint (`POST /procreate-layers`) that wraps `generate_procreate_api_layers` — the Python frontend uses an in-process call that isn't reachable over HTTP. |
| Metal precompiled CIKernels | Core Image Kernel Language is deprecated since iOS 12 but still works on iOS 26. Migration is a build-system change (needs a `.metal` file with `-fcikernel`) and yields no user-visible difference. |
| Recent generation thumbnails | Stored history is parameters-only; presigned URLs expire (1 h default) so re-fetching is not reliable. A persistent thumbnail strategy needs a local disk store. |

Reference docs:
- [STENCIL_APP_FUNCTIONALITY.md](STENCIL_APP_FUNCTIONALITY.md) — what the Python frontend does and how the iPad app maps onto it
- [liquid-glass.md](liquid-glass.md) — Liquid Glass research notes for backward-compat patterns
- [ARCHITECTURE.md](ARCHITECTURE.md) — detailed design-system + pipeline notes
