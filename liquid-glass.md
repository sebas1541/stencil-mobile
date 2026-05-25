Here’s a structured deep‑dive tailored to your app: how Liquid Glass works, which APIs/controls you actually get, and how to ship a clean 26‑first design with solid 16–25 fallbacks.

***
## 1. Liquid Glass: material & APIs
### What Liquid Glass actually is
Liquid Glass is a new digital “meta‑material” for the navigation/control layer, not just a new blur. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

Key optical/physical characteristics:

- **Lensing vs blur**: Previous materials “scattered light”; Liquid Glass dynamically bends, shapes, and concentrates light in real time, creating a lens effect that warps content behind it as it moves. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- **Specular highlights & lighting**: Glass lives in a simulated light environment; highlights move with geometry and interactions (locking/unlocking, device motion), so controls catch light like real glass. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- **Adaptive shadows**: Shadows change opacity based on background (stronger over text, lighter over flat backgrounds) to keep controls readable without hard‑coding shadow values. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- **Dynamic tint & light/dark adaptation**: The material is built from layered tints that continuously adjust as content scrolls behind, flipping small elements between light and dark and modulating tint ranges to maintain contrast. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- **Fluid motion**: The visual and motion design are coupled; glass “flexes” and “energizes with light” on touch, with gel‑like elasticity and morphing between control states (menus expanding from buttons, badges morphing out of toolbar icons). [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

Design‑wise, Liquid Glass is explicitly for **the navigation layer** (toolbars, tab bars, sidebars, sheets, menus, etc.), not for main content surfaces (lists, media, etc.), to preserve hierarchy. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

Compared with `Material.regular` / `.ultraThinMaterial`:

- Materials in iOS 15–17 were essentially blur+vibrancy combos tuned for a static light/dark palette.  
- Liquid Glass is **context‑adaptive** (multi‑layer system that responds to content, size, and platform) and **motion‑aware** (lensing and highlight motion tied to scroll & device motion). [en.wikipedia](https://en.wikipedia.org/wiki/Liquid_Glass)
### Variants: Regular vs Clear
From the design session:

- **Regular**  
  - Default, fully adaptive: works at any size, over any content. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
  - Flips between light/dark appearances for small elements (tab/tool bars), and drives dynamic text/symbol legibility.  
- **Clear**  
  - Permanently more transparent, no adaptive behavior; must be paired with a dimming layer for legible foreground content. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
  - Recommended only when:  
    1. Surface sits over media‑rich content.  
    2. Dimming layer doesn’t harm that content.  
    3. Foreground glyphs are bold and bright. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)

In SwiftUI, these map onto a `Glass` configuration type passed into `glassEffect` (e.g. `.regular`, `.clear`, plus tinting and modes like `.interactive`). Third‑party references show variants like `.regular.tint(...)` and `.clear.interactive()` used with `glassEffect`. [github](https://github.com/conorluddy/LiquidGlassReference)
### Core SwiftUI APIs (iOS/iPadOS 26)
Liquid Glass support in SwiftUI is centered around:

#### `glassEffect` (View modifier)

Docs and references describe a primary overload:

- Conceptual signature (based on Apple’s `View` docs and SwiftUI references): [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)

  ```swift
  func glassEffect(
      _ glass: Glass = .regular,
      in shape: some Shape = .capsule,
      isEnabled: Bool = true
  ) -> some View
  ```

- Behavior:  
  - Applies a Liquid Glass background behind the view, defaulting to a capsule shape and the Regular variant. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
  - `glass` lets you choose variant and configuration (e.g. `.regular`, `.clear`, `.regular.tint(.orange)`). [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)
  - `shape` defines the glass shape, often `.capsule` or `.rect(cornerRadius: ...)`. [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)
  - `isEnabled` allows toggling the material for performance or accessibility reasons. [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)

Example (badge with tint and custom shape):

```swift
struct BadgeView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 16))
    }
}
```

SwiftUI also supports a zero‑argument form when defaults are fine: [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)

```swift
Text("Hello")
    .padding()
    .glassEffect()   // Regular glass, capsule shape
```

#### `GlassEffectContainer`

Apple describes `GlassEffectContainer` as a view that “combines multiple Liquid Glass shapes into a single shape that can morph individual shapes into one another.” [exploreswiftui](https://exploreswiftui.com/wwdc25)

- Conceptual initializers (from Apple‑derived references): [createwithswift](https://www.createwithswift.com/grouping-elements-within-a-glass-effect-container-in-swiftui/)

  ```swift
  struct GlassEffectContainer<Content: View>: View {
      init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)
  }
  ```

Usage patterns:

- Group multiple `.glassEffect` views so they share a sampling region and morph as one “mass” during layout changes. [medium](https://medium.com/devtechie/glasseffectcontainer-in-ios-26-f575f86f1f54)
- Improves performance and visual correctness because “glass cannot sample other glass” — container lets overlapping elements share one sampling region. [createwithswift](https://www.createwithswift.com/grouping-elements-within-a-glass-effect-container-in-swiftui/)

Example grouping buttons:

```swift
GlassEffectContainer(spacing: 20) {
    HStack {
        Button("Home") { }
            .glassEffect()

        Button("Settings") { }
            .glassEffect()

        Button("Profile") { }
            .glassEffect()
    }
    .padding(.horizontal, 16)
}
.padding(.bottom, 24)
```

#### Morphing & IDs: `glassEffectID`, unions

For morphing transitions between glass states, SwiftUI exposes identifiers and unions: [github](https://github.com/mertozseven/LiquidGlassSwiftUI)

- Conceptual APIs (from SwiftUI references): [github](https://github.com/mertozseven/LiquidGlassSwiftUI)

  ```swift
  func glassEffectID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View
  func glassEffectUnion<ID: Hashable>(id: ID, namespace: Namespace.ID) -> some View
  ```

Usage:

- Tag glass surfaces (e.g. collapsed toolbar button vs expanded badge stack) so SwiftUI can morph one into the other when state changes. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- `glassEffectUnion` groups elements into fluidly merging blobs within a container. [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)

Example (badge morphing from toolbar button):

```swift
@Namespace private var glassNamespace
@State private var expanded = false

var body: some View {
    GlassEffectContainer {
        if expanded {
            HStack {
                ForEach(0..<3) { index in
                    Text("Badge \(index + 1)")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect()
                        .glassEffectID("badge-\(index)", in: glassNamespace)
                }
            }
        } else {
            Button {
                expanded.toggle()
            } label: {
                Label("Awards", systemImage: "rosette")
            }
            .glassEffect()
            .glassEffectID("badge-0", in: glassNamespace)
        }
    }
    .animation(.spring(), value: expanded)
}
```

#### Glass button styles

SwiftUI adds built‑in button styles that adopt Liquid Glass: [natashatherobot](https://www.natashatherobot.com/p/liquidglass-button-ios-26)

- `ButtonStyle.glass`
- `ButtonStyle.glassProminent`

Apple’s docs describe these as glass border styles “used in context of an accessory toolbar” and prominent primary actions. [exploreswiftui](https://exploreswiftui.com/library/button/glass-button-styles)

Conceptual usage:

```swift
VStack(spacing: 16) {
    HStack {
        Button("Glass") { /* action */ }
            .buttonStyle(.glass)

        Button("Glass Tinted") { }
            .buttonStyle(.glass)
            .tint(.orange)
    }

    HStack {
        Button("Primary") { }
            .buttonStyle(.glassProminent)

        Button("Danger") { }
            .buttonStyle(.glassProminent)
            .tint(.red)
    }
}
.padding()
```

Notes:

- `.glass` is subtle; blends with background; good for secondary actions. [natashatherobot](https://www.natashatherobot.com/p/liquidglass-button-ios-26)
- `.glassProminent` behaves like a prominent primary button; `.tint` changes the glass‑tinted color (with some mode‑specific quirks in early 26 betas). [exploreswiftui](https://exploreswiftui.com/library/button/glass-button-styles)

#### Background & scroll edge effects

Complementary APIs that interact with glass but aren’t themselves “glass”:

- **`backgroundExtensionEffect` (View modifier)** – “Adds the background extension effect to the view. The view will be duplicated into mirrored copies placed around the view on any edge with available safe area, with a blur on top.” [exploreswiftui](https://exploreswiftui.com/wwdc25)
  - Used e.g. to let hero images extend behind floating sidebars, while glass sidebar floats above. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- **Scroll edge effects** – soft/hard edge blur/fade where content scrolls under glass toolbars. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
  - SwiftUI exposes `scrollEdgeEffectStyle` to tune softness/hardness for dense layouts like Calendar. [exploreswiftui](https://exploreswiftui.com/wwdc25)

You generally don’t call a `glassBackgroundEffect` modifier directly; instead, toolbars/tab bars/sheets adopt glass automatically when built for iOS/iPadOS 26 with the new SDK. [swiftwithmajid](https://swiftwithmajid.com/2025/06/10/what-is-new-in-swiftui-after-wwdc25/)
### Tint, accent, and dark mode behavior
Liquid Glass’s tinting system is explicitly designed to respect and extend your app’s tint color: [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

- Choosing a tint color generates **a full tone ramp** mapped to underlying content brightness, like real colored glass. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- Tint applies across labels, icons, and fully tinted buttons, “changing hue, brightness and saturation depending on what’s behind without deviating too much from the intended color.” [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- Tinting should be reserved for primary actions; over‑tinting everything makes hierarchy muddy. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

In SwiftUI:

- `.tint(...)` on a `Button` with `.buttonStyle(.glassProminent)` tints the glass; on `.glass` it tints icon/text on subtle glass. [natashatherobot](https://www.natashatherobot.com/p/liquidglass-button-ios-26)
- Text inside `glassEffect` automatically uses a vibrant color that tracks tint + background to maintain contrast; you rarely need manual `foregroundStyle` unless you want custom hierarchy. [docs.vibetunnel](https://docs.vibetunnel.sh/apple/docs/liquid-glass/swiftui)
- Small glass surfaces can flip between light/dark modes independently of system’s overall appearance to maintain legibility over mixed backgrounds, while large surfaces (sidebars, big menus) adapt but typically don’t flip fully light/dark. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
### Concentric corners & container shapes
The new design system formalizes radii rules via **concentricity**: [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

- Shapes align by sharing a common center for their corner radii, so surfaces nest cleanly (sidebar → card → button → pill). [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Three primary shape types: [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
  - **Fixed shapes**: constant corner radius (classic rounded rectangles).  
  - **Capsules**: radius is half height, naturally concentric with device corner arcs; used heavily for bars, switches, sliders, buttons. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
  - **Concentric shapes**: radius derived from parent radius minus padding; used when elements are inset from a parent (e.g. button at bottom of sheet).  

SwiftUI exposes **`ConcentricRectangle`** with initializers like “Uniform Concentric Rectangle” and “Concentric Rectangle whose corner radii are defined from the same circle center as its parent element.” [exploreswiftui](https://exploreswiftui.com/wwdc25)

Use cases:

- Buttons anchored at the bottom of a sheet should share corner center with the sheet (concentric rectangle) instead of arbitrary radius. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- On iPhone, near screen edges, use capsules with extra margin; on iPad/Mac, use concentric rectangles aligned to window edges. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
### Performance & accessibility
Performance guidance (from Apple + expert references):

- Liquid Glass is GPU‑intensive (real‑time lensing, dynamic shadows, interactive highlights), but is heavily optimized when used through the system controls and `glassEffect`. [github](https://github.com/conorluddy/LiquidGlassReference)
- Recommendations: [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
  - Wrap related surfaces in `GlassEffectContainer` to reduce redundant sampling.  
  - Keep total independent glass surfaces per screen moderate (e.g. 5–10) and disable glass for off‑screen/hidden views using `isEnabled`.  
  - Avoid stacking custom blurs behind glass; let the system handle translucency.  

Accessibility integration is built in if you use the system APIs—Liquid Glass responds automatically to system settings: [discussions.apple](https://discussions.apple.com/thread/256136970)

- **Reduce Transparency** → makes glass frostier and less transparent, suppressing much of the background content. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- **Increase Contrast** → makes elements predominantly black/white with higher‑contrast borders. [linkedin](https://www.linkedin.com/posts/shieldsjamie_just-done-an-update-on-my-iphone-worst-activity-7389367715657850880-X5LO)
- **Reduce Motion** → reduces the intensity of lensing, elastic motion and inter‑glass highlight spreading. [discussions.apple](https://discussions.apple.com/thread/256136970)

This is precisely why Apple recommends using the native Liquid Glass APIs instead of custom effects: “If you use Apple’s APIs for the glass effects, you’ll automatically receive all the accessibility alternatives.” [reddit](https://www.reddit.com/r/UXDesign/comments/1l7fexe/apples_new_liquid_glass_ui_doesnt_look_accessible/)

***
## 2. Components that adopt Liquid Glass in iOS/iPadOS 26
Out of the box, when you build with the 26 SDK, many controls adopt Liquid Glass automatically. Below is an inventory with behavior and relevant SwiftUI hooks. [swiftwithmajid](https://swiftwithmajid.com/2025/06/10/what-is-new-in-swiftui-after-wwdc25/)
### Buttons
System buttons gain new shapes and glass styles: [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

- **Plain/Bordered/BorderedProminent** retain their semantics but are visually tuned for the new design (capsule shapes by default). [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- **Glass styles**: `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`. [exploreswiftui](https://exploreswiftui.com/wwdc25)

Screenshot mental model: a white pill “Glass” button with soft translucency and subtle highlight, and a blue “Tinted Glass” pill with more saturated glass, both floating above content.
SwiftUI API:

```swift
Button("Generate stencil") { /* action */ }
    .buttonStyle(.glassProminent)
    .tint(Color.accentColor)
```

Fallback (16–25):

```swift
if #available(iOS 26, *) {
    button.buttonStyle(.glassProminent)
} else {
    button.buttonStyle(.borderedProminent)
}
```
### Tab bars (including floating tab bar)
- iPhone tab bar **floats above content**, can minimize on scroll via `tabBarMinimizeBehavior`. [exploreswiftui](https://exploreswiftui.com/wwdc25)
- TabView can host a **bottom accessory** view (e.g., mini player or status bar) above the tabs via `tabViewBottomAccessory`. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- All of these surfaces are rendered on Liquid Glass. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

Relevant APIs: [exploreswiftui](https://exploreswiftui.com/wwdc25)

```swift
TabView {
    // …
}
.tabBarMinimizeBehavior(.onScrollDown)
.tabViewBottomAccessory {
    NowPlayingBar()
}
```

(SwiftUI uses glass automatically; there is no `.tabViewStyle(.sidebarAdaptable)` with glass in Apple’s references—sidebar behavior is handled by `NavigationSplitView` + sidebars, not a TabView style.) [exploreswiftui](https://exploreswiftui.com/wwdc25)
### Toolbars & navigation bars
- Toolbars “are placed on a Liquid Glass surface that floats above your app content and automatically adapts to what’s beneath it.” [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- Items are auto‑grouped; grouped items share a glass backing. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

New APIs: [exploreswiftui](https://exploreswiftui.com/wwdc25)

- `ToolbarSpacer(.fixed(CGFloat))` & `ToolbarSpacer(.flexible)` to create grouped sections.  
- `sharedBackgroundVisibility` to remove a glass background for an item (e.g. avatar). [exploreswiftui](https://exploreswiftui.com/wwdc25)

SwiftUI example:

```swift
.toolbar {
    ToolbarItemGroup(placement: .principal) {
        Button {
            /* favorite */
        } label: {
            Label("Favorite", systemImage: "heart")
        }
        Button {
            /* add to collection */
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    ToolbarSpacer(.flexible)

    ToolbarItem {
        Button {
            /* share */
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
```

Glass is implied on iOS/iPadOS 26 toolbars; you don’t explicitly call `glassEffect` here. [swiftwithmajid](https://swiftwithmajid.com/2025/06/10/what-is-new-in-swiftui-after-wwdc25/)
### Sidebars (NavigationSplitView on iPad)
- `NavigationSplitView` sidebars become **floating Liquid Glass sidebars** with content scrolling behind them, plus background extension effect for hero content. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- On iPad/Mac, sidebars are inset; content can extend behind via `backgroundExtensionEffect`. [exploreswiftui](https://exploreswiftui.com/wwdc25)

SwiftUI example:

```swift
NavigationSplitView {
    SidebarView()
        .navigationTitle("Projects")
        .backgroundExtensionEffect()
} detail: {
    DetailView()
}
```
### Sheets & popovers
- Partial‑height sheets on iOS 26 are inset by default with Liquid Glass backgrounds; as they grow to full‑height, background transitions to opaque, anchoring to screen edge. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- Sheets and dialogs can **morph out of the button** that presents them using navigation zoom transitions (structural API, not glass‑specific). [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Popovers and menus also “flow smoothly out of Liquid Glass controls.” [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

You normally rely on `.sheet`/`.popover`—the glass background is automatic on 26. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
### Alerts & confirmation dialogs
- Alerts and dialogs “automatically morph out of the buttons that present them” and visually sit on Liquid Glass surfaces. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Standard SwiftUI `.alert` and `.confirmationDialog` pick up the new visuals automatically on 26.
### Menus & context menus
- Menus get new layout, consistent icon placement, and use Liquid Glass surfaces when presented from glass controls or toolbars. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Context menus on iOS adopt the same menu model (selection indicator + icon + label + accessory). [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

Standard API:

```swift
Menu {
    Button("Duplicate", systemImage: "doc.on.doc") { }
    Button("Delete", systemImage: "trash", role: .destructive) { }
} label: {
    Label("More", systemImage: "ellipsis.circle")
}
```
### Pickers, sliders, toggles, steppers
Build‑a‑SwiftUI‑app session notes “controls like toggles, segmented pickers, and sliders now transform into Liquid Glass during interaction.” [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

- **Sliders**  
  - Gain tick marks (auto from `step:`; customizable via ticks closures) and options like `neutralValue`. [exploreswiftui](https://exploreswiftui.com/wwdc25)
  - Track and thumb adopt Liquid Glass during interaction.  
- **Segmented controls / segmented pickers**  
  - Use capsule shapes and glass surfaces when placed in toolbars or on glass backgrounds. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- **Toggles/steppers**  
  - Use capsule shapes and interactive glass‑driven motion; you don’t manually apply `glassEffect` to them.
### Search fields
- Search fields can appear on dedicated Liquid Glass surfaces (toolbar search, search tab). [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Patterns: toolbar search (bottom on iPhone, top‑trailing on iPad/Mac) and dedicated search tab role in TabView. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

SwiftUI:

```swift
NavigationSplitView {
    Sidebar()
} detail: {
    ListView()
}
.searchable(text: $query)
.searchToolbarBehavior(.minimized)   // optional on 26
```
### Cards & grouped containers
- Cards, inspectors and inspectors’ toolbars are re‑tuned to align shapes and spacing with Liquid Glass; inspector columns on iPad/Mac use subtle layering rather than full glass, but may contain local glass controls. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- Custom cards should use `glassEffect` or concentric rectangles for alignment when floating above content. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
### Floating action elements
- Floating menus, controls (e.g. Maps‑style pulsing buttons) and badges are prime candidates for custom Liquid Glass via `glassEffect` + `GlassEffectContainer`. [dev](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)

Example (floating FAB row):

```swift
GlassEffectContainer {
    HStack(spacing: 16) {
        Button {
            /* zoom */
        } label: {
            Image(systemName: "plus.magnifyingglass")
        }
        .glassEffect(.regular.interactive())

        Button {
            /* reset */
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .glassEffect(.regular.interactive())
    }
    .padding(12)
}
.padding()
```

***
## 3. Backward compatibility down to iPadOS 16
### Clean `#available` patterns in SwiftUI
To avoid duplicating view trees, wrap availability in **modifiers**, not the body’s structure.

Pattern:

```swift
extension View {
    @ViewBuilder
    func glassIfAvailable(
        glass: Glass = .regular,
        shape: AnyShape? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let shape {
                self.glassEffect(glass, in: shape)
            } else {
                self.glassEffect(glass)
            }
        } else {
            self.background(.thinMaterial)   // or .regularMaterial
        }
    }
}
```

Usage:

```swift
CardView()
    .glassIfAvailable(glass: .regular)
```

No duplication, and your layout tree remains stable; only the background changes.
### Reusable `ViewModifier` for glass fallback
You can encode this as a `ViewModifier` for reuse:

```swift
struct LiquidGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                )
        }
    }
}

extension View {
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCard())
    }
}
```

Usage:

```swift
VStack {
    // card content
}
.liquidGlassCard()
```

Same strategy for buttons/tab bars/etc.
### Backport patterns for specific surfaces
**Buttons (glass → bordered)**

```swift
extension Button {
    @ViewBuilder
    func tattooPrimaryButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
```

**Tab bar (floating + minimize → standard TabView)**

- 26+: use `tabBarMinimizeBehavior` & `tabViewBottomAccessory`. [exploreswiftui](https://exploreswiftui.com/wwdc25)
- 16–25: omit these modifiers; TabView renders as a classic fixed bar.

```swift
TabView(selection: $selection) {
    // tabs
}
.ifAvailable26 { tabView in
    tabView
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NowPlayingBar()
        }
}
```

Where:

```swift
extension View {
    @ViewBuilder
    func ifAvailable26<Content: View>(
        _ transform: (Self) -> Content
    ) -> some View {
        if #available(iOS 26, *) {
            transform(self)
        } else {
            self
        }
    }
}
```

**Sheets (Liquid Glass → `.presentationBackground`)**

iOS/iPadOS 16.4+ adds `presentationBackground(_:)` for sheets. [djangocas](https://djangocas.dev/blog/ios/swiftui-changes-in-ios-16.4-beta2/)

```swift
.sheet(isPresented: $isPresented) {
    EditorSheet()
        .ifAvailable26 { view in
            view   // Let system glass handle background on 26
        }
        .ifNotAvailable26 { view in
            view.presentationBackground(.thinMaterial)
        }
}
```

Where `ifNotAvailable26` mirrors the helper above with `#unavailable(iOS 26, *)` in newer Swift.
### APIs gated on iOS 17+ and 18+
From SwiftUI evolution pre‑Liquid‑Glass: [medium](https://medium.com/@Shubhransh-Gupta/highlights-from-wwdc-2024-whats-new-in-swiftui-6f31866086bc)

- **iOS 17+ notable APIs**  
  - `@Observable` macro & `@Bindable` property wrapper (new observation model). [medium](https://medium.com/@Shubhransh-Gupta/highlights-from-wwdc-2024-whats-new-in-swiftui-6f31866086bc)
  - New `NavigationStack` and `NavigationSplitView` refinements (introduced earlier but significantly improved). [subscription.packtpub](https://subscription.packtpub.com/book/business-and-other/9781805121732/1/ch01lvl1sec03/what-s-new-in-swiftui)
  - Inspectors (`.inspector`, `.inspectorColumnWidth`) for detail panels on iPad/Mac. [wwdcnotes](https://www.wwdcnotes.com/notes/wwdc23/10161/)
  - `Table` on iOS/iPadOS, new material and environment APIs, enhanced `symbolEffect`, additional navigation and sheet-handling APIs. [subscription.packtpub](https://subscription.packtpub.com/book/business-and-other/9781805121732/1/ch01lvl1sec03/what-s-new-in-swiftui)

- **iOS 16.4–16.x**  
  - Advanced sheet APIs: `presentationBackground(_:)`, `presentationBackgroundInteraction(_:)`, `presentationContentInteraction(_:)` for resizable sheets. [djangocas](https://djangocas.dev/blog/ios/swiftui-changes-in-ios-16.4-beta2/)

Concrete iOS 18‑only SwiftUI additions are not captured in the sources above; you’d need to consult Apple’s “What’s new in SwiftUI” 2024/2025 docs for a complete list. The key point: if you are willing to target **iPadOS 17+**, you unlock the modern observation system, better navigation APIs, and Inspectors, all of which are very relevant for a tool‑heavy app like yours. [wwdcnotes](https://www.wwdcnotes.com/notes/wwdc23/10161/)
### Should you bump min deployment to iPadOS 17 or 18?
Apple’s official adoption numbers (App Store‑based, Feb 12 2026): [9to5mac](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/?extended-comments=1)

- **Of iPads introduced in last 4 years**:  
  - iPadOS 26: 66%  
  - iPadOS 18: 28%  
  - Earlier (17 and below): 6%  

- **Of all active iPads**:  
  - iPadOS 26: 57%  
  - iPadOS 18: 26%  
  - Earlier: 17%  

Earlier Apple stats at the iPadOS 17 launch (for context): [9to5mac](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/?extended-comments=1)

- iPadOS 17: 61%  
- iPadOS 16: 29%  
- Earlier: 10%  

Implications:

- **Targeting iPadOS 16+**: Supports nearly all active devices, but you’re optimizing for a shrinking tail; 16 is now only part of the “Earlier” 17% bucket.  
- **Targeting iPadOS 17+**: You drop (at most) a high‑single‑digit to low‑teens percentage of active devices, but gain the modern observation model, better sheets, Inspectors, and simpler adoption of new design system APIs. [medium](https://medium.com/@Shubhransh-Gupta/highlights-from-wwdc-2024-whats-new-in-swiftui-6f31866086bc)
- **Targeting iPadOS 18+**: Would currently exclude ~57% of iPads that are already on 26 and some proportion on 18; it’s not a realistic baseline for 2026. [appleinsider](https://appleinsider.com/articles/26/02/13/ios-26-adoption-rate-isnt-the-crisis-some-analysts-are-portraying)

For a new, pro‑leaning stencil app, a **17+ baseline** is a very reasonable tradeoff: you lose a small, shrinking slice of older devices, but dramatically simplify your implementation (modern navigation/observation, easier adoption of recent SwiftUI features) while still being compatible with iPads that haven’t yet jumped to 26. [medium](https://medium.com/@Shubhransh-Gupta/highlights-from-wwdc-2024-whats-new-in-swiftui-6f31866086bc)

***
## 4. Color system & theming for Liquid Glass
### Palette strategy with Liquid Glass
Apple’s design‑system talk emphasizes that system colors were subtly tuned across light/dark and increased‑contrast appearances to **harmonize with Liquid Glass**, improving hue differentiation while keeping the “optimistic” Apple feel. They recommend: [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

- Let the **content layer** carry most of the color; Liquid Glass sits above as a dynamic, adaptive overlay. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)
- Use tint selectively on navigation/actions, not everywhere. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

For your app:

- Define a **tokenized palette** in the asset catalog (e.g. `PrimaryBackground`, `SecondaryBackground`, `Accent`, `Danger`, etc.), each with light/dark variants and maybe high‑contrast tweaks.  
- Use **semantic names**, not raw colors, so you can retune later without touching the code.  

Implementation outline:

1. In the asset catalog, create Color Sets:
   - Enable “Any, Dark” appearances (and “High Contrast” if you want fine tuning).  
2. Name them e.g. `PrimaryBackground`, `SecondaryBackground`, `CanvasBackground`, `Accent`, `AccentSecondary`, `Danger`, `CanvasStroke`.  
3. In code, define:

   ```swift
   enum AppColor {
       static let primaryBackground = Color("PrimaryBackground")
       static let secondaryBackground = Color("SecondaryBackground")
       static let canvasBackground   = Color("CanvasBackground")
       static let accent            = Color("Accent")
       static let accentSecondary   = Color("AccentSecondary")
       static let danger            = Color("Danger")
   }
   ```

Then use `.tint(AppColor.accent)` on glass‑prominent controls and use background colors only where you truly own the surface (canvas, cards that aren’t glass, etc.).
### System vs custom colors under glass
Apple’s guidance:

- System colors (like `systemBackground`, `secondarySystemBackground`, `systemGroupedBackground`) remain good base choices; they’ve been retuned to work with Liquid Glass. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- However, **for a strong brand look**, you should define a cohesive palette that still plays nicely with glass by respecting contrast and not competing at the navigation layer. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)

Practical compromise:

- Use `Color(.systemBackground)` / `.secondarySystemBackground` for **generic surfaces** that sit beneath glass (e.g. base canvas in simple screens).  
- Use **custom palette tokens** for branded surfaces (canvas behind your image editor, accent strokes, selection backgrounds, etc.), making sure light/dark variants keep enough contrast with glass overlays and tinted controls.
### `.tint()` propagation through glass
- `.tint` propagates through controls and surfaces; tint on a container like `NavigationStack` or `TabView` can affect nested controls, including glass buttons. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- Liquid Glass uses a **new tint mapping**; selected color produces tone ramps based on background brightness, so tinted glass behaves like colored glass rather than flat fills. [developer.apple](https://developer.apple.com/videos/play/wwdc2025/219/)

For clarity, keep a single source of truth:

```swift
@main
struct TattooStencilApp: App {
    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray3
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(AppColor.accent)   // Global accent for glass controls
        }
    }
}
```

Override tint locally only when you need distinct hierarchy (e.g. destructive buttons in red glass).
### Proposed slate‑blue / navy‑cyan palette
Here’s a concrete starting palette that works well over neutral content with Liquid Glass:

**Light theme (slate‑blue dashboard‑style)**

- `PrimaryBackground` – soft slate:  
  - RGB(20, 26, 33) → \(#141A21\) — for full‑bleed canvas behind content.  
- `SecondaryBackground` – slightly lighter slate:  
  - RGB(28, 36, 45) → \(#1C242D\).  
- `CanvasBackground` – dark‑on‑light editing area if you prefer higher contrast:  
  - RGB(242, 245, 249) → \(#F2F5F9\).  
- `Accent` – saturated blue‑cyan for primary glass buttons:  
  - RGB(43, 141, 222) → \(#2B8DDE\).  
- `AccentSecondary` – teal accent for secondary actions:  
  - RGB(18, 164, 181) → \(#12A4B5\).  
- `Danger` – rich red:  
  - RGB(217, 78, 92) → \(#D94E5C\).  

**Dark theme (navy‑cyan)**

- `PrimaryBackground` – deep navy:  
  - RGB(5, 10, 20) → \(#050A14\).  
- `SecondaryBackground` – slightly raised surface:  
  - RGB(12, 22, 35) → \(#0C1623\).  
- `CanvasBackground` – near‑black for image canvas:  
  - RGB(8, 12, 20) → \(#080C14\).  
- `Accent` – cyan leaning to blue:  
  - RGB(56, 182, 255) → \(#38B6FF\).  
- `AccentSecondary` – minty cyan:  
  - RGB(72, 205, 196) → \(#48CDC4\).  
- `Danger` – brighter red:  
  - RGB(242, 90, 100) → \(#F25A64\).  

Use:

- Canvas/content backgrounds mostly from `PrimaryBackground` / `CanvasBackground`.  
- Tint for glass buttons/controls from `Accent`.  
- Let Liquid Glass adapt tints/brightness over photos; if contrast issues appear on specific backgrounds, you can darken the canvas slightly or introduce a subtle content dimming layer.

***
## 5. Concrete components for your app (26 glass + 16 fallback)
Below I’ll show each component in two layers:

- A small helper for glass vs fallback.  
- A usage snippet.

All snippets assume iPadOS 16+ minimum; where I gate 26‑only APIs, I wrap them.
### 5.1 Image picker (PHPicker) with glass card preview
Helper for a **glass card**:

```swift
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                )
        }
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}
```

Image picker + preview:

```swift
struct ImagePickerView: View {
    @State private var item: PhotosPickerItem?
    @State private var uiImage: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            PhotosPicker(
                selection: $item,
                matching: .images
            ) {
                Label("Select Reference", systemImage: "photo.on.rectangle")
            }

            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .glassCard()
                    .padding(.horizontal)
            } else {
                Text("No image selected")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .padding(.horizontal)
            }
        }
        .padding()
        .task(id: item) {
            guard let item else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                uiImage = image
            }
        }
    }
}
```
### 5.2 Segmented tier selector (6 options with subtitle)
Use a custom segmented control shaped to match the new design:

```swift
struct TierOption: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
}

struct TierSelector: View {
    let options: [TierOption]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options) { option in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.headline)
                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 120)
                    .contentShape(Rectangle())
                    .background {
                        if #available(iOS 26, *) {
                            Color.clear.glassEffect(
                                selection == option.id
                                ? .regular.tint(.accentColor)
                                : .regular,
                                in: .rect(cornerRadius: 16)
                            )
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selection == option.id
                                      ? .thinMaterial
                                      : .ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(selection == option.id ? .accent : .clear, lineWidth: 1)
                                )
                        }
                    }
                    .onTapGesture { selection = option.id }
                }
            }
            .padding(.horizontal)
        }
    }
}
```
### 5.3 Style dropdown / menu picker
SwiftUI `Menu` works well; add subtle glass when 26+:

```swift
struct StylePicker: View {
    let styles: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(styles, id: \.self) { style in
                Button(style) { selection = style }
            }
        } label: {
            HStack {
                Text(selection)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: 220)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }
}
```
### 5.4 Vertical slider stack for retouching controls
Use `Slider` with labels and consistent glass‑ish track:

```swift
struct RetouchSlider: View {
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
        .padding(12)
        .background {
            if #available(iOS 26, *) {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
            }
        }
    }
}

struct RetouchPanel: View {
    @Binding var threshold: Double
    @Binding var dilation: Double
    @Binding var denoise: Double

    var body: some View {
        VStack(spacing: 12) {
            RetouchSlider(title: "Threshold", range: 0...1, value: $threshold)
            RetouchSlider(title: "Dilation", range: 0...5, value: $dilation)
            RetouchSlider(title: "Denoise", range: 0...1, value: $denoise)
        }
        .padding()
    }
}
```
### 5.5 Side‑by‑side image comparison with pinch‑zoom
Use `GeometryReader` + `MagnificationGesture` per image:

```swift
struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1, value)
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                scale = max(1, scale)
                            }
                        }
                )
        }
    }
}

struct ComparisonView: View {
    let original: UIImage
    let stencil: UIImage

    var body: some View {
        HStack(spacing: 0) {
            ZoomableImage(image: original)
            ZoomableImage(image: stencil)
        }
        .clipped()
    }
}
```

Wrap the comparison in a glass frame on 26:

```swift
ComparisonView(original: original, stencil: stencil)
    .glassCard()
    .padding()
```
### 5.6 Reference overlay with opacity/brightness sliders
Blend stencil over original with adjustable opacity & brightness:

```swift
struct OverlayCanvas: View {
    let base: UIImage
    let overlay: UIImage
    @Binding var opacity: Double
    @Binding var brightness: Double

    var body: some View {
        ZStack {
            Image(uiImage: base)
                .resizable()
                .scaledToFit()
                .brightness(brightness)

            Image(uiImage: overlay)
                .resizable()
                .scaledToFit()
                .opacity(opacity)
        }
    }
}

struct OverlayEditor: View {
    @State var opacity: Double = 0.7
    @State var brightness: Double = 0

    let base: UIImage
    let overlay: UIImage

    var body: some View {
        VStack(spacing: 16) {
            OverlayCanvas(base: base, overlay: overlay,
                          opacity: $opacity, brightness: $brightness)
                .glassCard()
                .padding(.horizontal)

            RetouchSlider(title: "Overlay Opacity", range: 0...1, value: $opacity)
            RetouchSlider(title: "Base Brightness", range: -0.4...0.4, value: $brightness)
        }
        .padding()
    }
}
```
### 5.7 Color swatch picker (black/red/blue)
Simple HStack of tappable swatches:

```swift
struct Swatch: View {
    let color: Color
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)

            if selected {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .shadow(radius: 3)
            }
        }
        .frame(width: 32, height: 32)
    }
}

struct SwatchPicker: View {
    enum InkColor: String, CaseIterable, Identifiable {
        case black, red, blue
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .black: return .black
            case .red:   return .red
            case .blue:  return .blue
            }
        }
    }

    @Binding var selection: InkColor

    var body: some View {
        HStack(spacing: 16) {
            ForEach(InkColor.allCases) { ink in
                Swatch(color: ink.color, selected: ink == selection)
                    .onTapGesture { selection = ink }
            }
        }
        .padding(10)
        .background {
            if #available(iOS 26, *) {
                Color.clear.glassEffect(.regular, in: .capsule)
            } else {
                Capsule().fill(.thinMaterial)
            }
        }
    }
}
```
### 5.8 Multi-select checkbox group for PSD layers
Basic SwiftUI multi‑select list:

```swift
struct LayerItem: Identifiable {
    let id: UUID
    let name: String
}

struct LayerSelectionView: View {
    let layers: [LayerItem]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        List(layers) { layer in
            HStack {
                Image(systemName: selectedIDs.contains(layer.id)
                      ? "checkmark.circle.fill"
                      : "circle")
                Text(layer.name)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedIDs.contains(layer.id) {
                    selectedIDs.remove(layer.id)
                } else {
                    selectedIDs.insert(layer.id)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
}
```

Wrap the list in a glass panel on 26 if it’s floating; otherwise keep it as content‑layer.
### 5.9 Sticky action bar (Generate / Export)
Use a bottom toolbar that becomes glass on 26 automatically, or a custom glass card pinned to bottom safe area:

```swift
struct ActionBar: View {
    var onGenerate: () -> Void
    var onExport: () -> Void
    var isBusy: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button("Generate") { onGenerate() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)

            Button("Export") { onExport() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background {
            if #available(iOS 26, *) {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 0))
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
```

Place at bottom:

```swift
VStack(spacing: 0) {
    EditorContent()
    ActionBar(onGenerate: generate, onExport: export, isBusy: isBusy)
}
.ignoresSafeArea(edges: .bottom)
```

On 26 toolbars, you can instead rely on `.toolbar` with `.glass` buttons.
### 5.10 Loading state with progress description
Use a glass panel overlay for 26, material card for 16:

```swift
struct LoadingOverlay: View {
    let message: String
    let progress: Double?   // 0...1 or nil for indeterminate

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
            .padding(40)
        }
    }
}
```
### 5.11 iPad sidebar + detail that collapses on iPhone
Use `NavigationSplitView` with adaptive behavior:

```swift
struct RootView: View {
    @State private var selection: Document.ID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            if let selection {
                DetailView(documentID: selection)
            } else {
                Text("Select a stencil")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

On iPad, you get a 2‑column layout with a Liquid Glass sidebar. On iPhone (compact width), this collapses to a standard push navigation stack automatically, no extra work needed. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

***
## 6. iPad specifics that port cleanly to iPhone
### Adaptive layouts: `NavigationSplitView`, size classes, `ViewThatFits`
Apple positions iPad as the “middle layer” between iPhone and Mac; Liquid Glass structures and NavigationSplitView are designed to scale across devices. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

Practical patterns:

- Use **`NavigationSplitView`** for iPad while relying on its compact‑width adaptation on iPhone; avoid separate code paths unless you need special behavior.  
- Use **`ViewThatFits`** to swap between one or two‑column layouts based on available width:

```swift
ViewThatFits {
    HStack {
        EditorSidebar()
        EditorCanvas()
    }
    EditorCanvas()
}
```

- Use `@Environment(\.horizontalSizeClass)` to tweak details like sidebar width or whether to show labels on buttons.
### Pencil/touch interactions on the canvas
You can keep the UI shared but specialize input:

- The main canvas view should support both **direct touch editing** and **Apple Pencil** by using gestures and the PencilKit canvas as needed.  
- Glass belongs in **UI overlays** (toolbars, sliders, floating palettes), not in the canvas itself; this ensures the canvas remains visually stable while controls float above. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
### Keyboard shortcuts & menus on iPad
Add keyboard shortcuts and command menus that co‑exist with your touch controls:

```swift
.commands {
    CommandMenu("Stencil") {
        Button("Generate", action: generate)
            .keyboardShortcut("g", modifiers: [.command])

        Button("Export", action: export)
            .keyboardShortcut("e", modifiers: [.command])
    }
}
```

Toolbars on iPad get Liquid Glass; keyboard shortcuts give power users parity with Mac‑style workflows. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
### Drag and drop for image input
Support drag‑and‑drop on iPad and iPhone:

```swift
struct DropTargetView: View {
    let handleImage: (UIImage) -> Void

    var body: some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash:  [developer.apple](https://developer.apple.com/documentation/swiftui/view)))
            .foregroundStyle(.secondary)
            .overlay(Text("Drop image here"))
            .onDrop(of: [.image], isTargeted: nil) { providers in
                providers.first?.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let image = UIImage(data: data) else { return }
                    Task { @MainActor in
                        handleImage(image)
                    }
                }
                return true
            }
            .glassCard()
    }
}
```

This maps naturally to iPhone (single‑pane) and iPad (multiwindow, Stage Manager) without rework.
### Stage Manager & multitasking
Design guidelines from the new design system:

- Sidebars, toolbars and floating elements should be **concentric and inset** so they look good in resizable iPad windows. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)
- Avoid full‑bleed custom backgrounds behind bars; let Liquid Glass/scroll‑edge effects do their work so your app looks clean in different window sizes and alongside other apps. [developer.apple](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

For your app:

- Keep the main canvas adaptable; don’t hard‑code aspect ratios tied to full‑screen. Use `GeometryReader` and flexible layouts.  
- Avoid huge fixed‑size panels that assume full‑screen; use Inspectors (on 17+) for advanced settings that can slide out in multi‑window contexts. [wwdcnotes](https://www.wwdcnotes.com/notes/wwdc23/10161/)

***
## 7. Project setup
### Xcode project structure
Given you want shared iPad/iPhone SwiftUI code with an iPad‑first layout, a solid structure is:

- Single **SwiftUI App target** (iOS/iPadOS universal).  
- Folders / groups by feature, not by MVC:  
  - `Core/` (models, networking, stencil pipeline abstractions)  
  - `Services/` (API client, PSD export, settings)  
  - `Features/`  
    - `Import/` (picker, drag‑drop)  
    - `Editor/` (canvas, sliders, overlay, comparison)  
    - `Export/` (formats, share sheet)  
    - `Settings/` (preferences, theme)  
  - `DesignSystem/` (colors, typography, radii, reusable glass modifiers/components).  

Encapsulate all Liquid Glass logic in `DesignSystem/Glass`, so it’s easy to tweak your strategy later.
### Swift Package Manager modules vs monolithic
Given the app is compute‑heavy and you likely have a separate backend microservice doing stencil generation, modularization via SPM is a win:

- **Core packages**  
  - `StencilCore` – types for jobs, parameters, local preview logic.  
  - `APIClient` – small package for networking (built on `URLSession` rather than big third‑party).  
  - `DesignSystem` – shared SwiftUI components, glass modifiers, color tokens.  

This lets you:

- Share logic with future CLI/tooling if you want.  
- Write focused tests around your stencil pipeline.  

Keep **platform‑specific glue** (PHPicker, drag‑and‑drop, Stage Manager behaviors) in the app target.
### Recommended dependencies
Given Apple’s general guidance to rely on system frameworks, you can keep third‑party dependencies minimal:

- **Networking**  
  - Native `URLSession` + `Codable` is enough for a microservice backend; you probably don’t need Alamofire.  
- **Image processing** (client‑side preview/adjustments)  
  - Use `CoreImage` and `Metal` where possible for GPU‑accelerated previews; third‑party is optional.  

For PSD/PNG export:

- **PNG export** is covered by UIKit: UIGraphics / CoreGraphics — no extra dependency needed.  
- **PSD**:  
  - Open‑source Swift libraries exist for **reading** PSD (e.g. `PhotoshopReader`). [github](https://github.com/hughbe/PhotoshopReader)
  - For **writing**, it’s usually easier to have your backend produce PSD (with proper layers, resolution, embedded previews). Keeping PSD export server‑side also simplifies IP concerns and keeps your client light.  

Vector/SVG if you later expand into plotter/Cricut support:

- `Macaw` (vector graphics with SVG) or `SwiftDraw` (SVG → PNG/PDF/SFSymbol) are well‑known Swift options. [github](https://github.com/exyte/Macaw)

My recommendation for v1:

- **No heavy third‑party dependencies** beyond a small PSD/SVG helper if you truly need them; lean on system frameworks for everything else.  
- Invest in a strong `DesignSystem` package that codifies your Liquid Glass usage, colors, and reusable components—this will pay off massively when you port to iPhone and later to macOS/iPad windowing variations. [youtube](https://www.youtube.com/watch?v=DS2ildqCrB0)

***

If you’d like, next step I can help you factor all of this into a small `DesignSystem` module (with `GlassButton`, `GlassCard`, `GlassToolbar`, etc.) and sketch the `NavigationSplitView`‑driven root shell for iPad and its automatic collapse to iPhone.