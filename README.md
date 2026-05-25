# Stencil — iPad / iPhone client

Native Swift / SwiftUI client for the [stencil microservice](https://github.com/sebas1541/microservice_stencil).

- **Min deployment**: iOS / iPadOS 17.0
- **Language**: Swift 5.10 (SwiftUI, `@Observable`, `NavigationSplitView`)
- **Design**: Liquid Glass (iOS 26) with `Material` fallbacks down to 17
- **No third-party dependencies** — only Apple frameworks
- **Universal**: one target ships to iPad and iPhone

## Project structure

```
StencilApp/
  App/           — @main, RootView (NavigationSplitView)
  DesignSystem/  — color tokens, glass modifiers, theme
  Core/          — Codable models matching the FastAPI contract
  Services/      — APIClient + StencilService
  Features/
    Import/      — PhotosPicker + drag-drop card
    Editor/      — main "configure → generate" flow
    Result/      — post-generation preview
    Settings/    — API base URL + X-Api-Key
  Resources/     — Assets.xcassets + Info.plist
```

## Getting set up

The Xcode project is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen). The generated `StencilApp.xcodeproj` is committed for convenience.

```bash
# First-time only
brew install xcodegen

# Regenerate the .xcodeproj after editing project.yml or adding files:
xcodegen generate

# Then open Xcode
open StencilApp.xcodeproj
```

## Running against the microservice

By default the app talks to `http://localhost:8000`. Override in **Settings** (sidebar → Settings) at runtime — the change takes effect on the next request.

If you're running the microservice on your Mac and testing on a real iPad, point the app at your machine's LAN IP (e.g. `http://192.168.1.42:8000`). For the simulator, `localhost` works.

## What's implemented (v0.1.0 / commit 1)

- Universal SwiftUI app, NavigationSplitView shell
- Asset Catalog color tokens with light + dark variants (slate-blue → navy + violet/cyan accents)
- Liquid Glass modifiers (`liquidGlassCard`, `liquidGlassChip`, `liquidGlassButton`) with `Material` fallbacks
- All `Codable` models mirroring the FastAPI contract
- `APIClient` actor (URLSession, optional `X-Api-Key`) + `StencilService` (presigned-upload → S3 PUT → /stencil)
- Image import (PhotosPicker + drag-and-drop), 15 MB client-side cap
- Editor with all configure controls: tier (6), style (15), resolution (3), prompt mode (2), full `prompt_config` (background, thickness, shadows + detail/weight reveal, texture)
- Generate + Technical Trace buttons, with `tier == .nano` gating Technical Trace
- Result view with side-by-side preview, content type, processing time, gemini calls, resolution warning
- Settings: API base URL, optional API key, `/health` probe

## What's coming next

- **Commit 4 onward** — Procreate PSD multi-layer export once the microservice exposes `POST /procreate-layers`; local history of recent generations in the sidebar; Apple Pencil annotation on top of the stencil.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘G | Generate stencil |
| ⌘T | Technical Trace |
| ⌘N | Back to setup (from Result) |
| ⌘R | Test `/health` (from Settings) |
