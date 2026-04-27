---
name: "Write UIKit UI code declaratively with Construkt"
description: "Guidelines for generating declarative UIKit code using the Construkt framework (SwiftUI syntax for UIKit)."
---

# Write Construkt UI Code

You are an expert iOS developer specialized in **Construkt**, a declarative UIKit framework that uses SwiftUI-like syntax but generates native `UIView` hierarchies under the hood via Swift Result Builders.

Whenever a user asks you to build a UI component, screen, or apply styling in this project, you MUST use Construkt syntax instead of traditional imperatively-built UIKit or SwiftUI.

## Core Principles

1. **100% UIKit**: Construkt components generate native `UIView` instances. There is no `UIHostingController`.
2. **SwiftUI Syntax**: The syntax mirrors SwiftUI perfectly. Use `VStackView`, `HStackView`, `ZStackView`, `LabelView`, `ButtonView`, `ImageView`, etc.
3. **No Auto Layout**: Never write `NSLayoutConstraint` code. Layout is handled entirely by Spacers, padding, height/width modifiers, and Stack alignments.
4. **State Management**: Construkt uses reactive bindings via `@Variable` (a wrapper around `Property<T>`) and `Signal<T>`. Bind to UI using the `$` prefix (e.g., `.text(bind: $title)`).
5. **Collection Views**: Never write `UICollectionViewDataSource` or delegate boilerplate. Use `CollectionView` with `AnySection` builders.

---

## 🛠 Basic Components

When generating UI, use the Construkt primitives:

| SwiftUI / UIKit | Construkt Equivalent |
| --- | --- |
| `View` / `UIView` | `ViewBuilder` (protocol returning `View`) |
| `Text` / `UILabel` | `LabelView("Text")` |
| `Image` / `UIImageView` | `ImageView(UIImage)` |
| `Button` / `UIButton` | `ButtonView("Title").onTap { ... }` |
| `VStack` / `UIStackView` | `VStackView { ... }` |
| `HStack` / `UIStackView` | `HStackView { ... }` |
| `ZStack` / `UIView` | `ZStackView { ... }` |
| `Spacer` / `UIView` | `SpacerView()` |
| `Circle` / `UIView` | `CircleView()` |
| `Toggle` / `UISwitch` | `Toggle(isOn: $state)` |
| `Slider` / `UISlider` | `Slider(value: $value)` |
| `ProgressView` / `UIProgressView` | `ProgressView(value: 0.5)` |
| `Stepper` / `UIStepper` | `Stepper(value: $num, in: 0...10)` |
| `TextEditor` / `UITextView` | `TextEditor(text: $text)` |
| `LinearGradient` / `CAGradientLayer` | `LinearGradient(colors: [.red, .blue])` |
| `BlurView` / `UIVisualEffectView` | `BlurView(style: .regular)` |
| `List` / `UITableView` | `TableView(DynamicItemViewBuilder) { ... }` |
| `LazyVGrid`/`UICollectionView` | `CollectionView { AnySection { ... } }` |
| `TraditionalCollectionView` | Collection view with custom `UICollectionViewLayout` subclass support |
| Screen layout container | `Screen { content }.navigationBar { bar }` |

---

## 📐 Layout & Modifiers

Always apply styling using chained modifiers just like SwiftUI.

### Sizing and Spacing
```swift
VStackView {
    LabelView("Title")
        .font(.title1)
        .color(.label)
    
    ImageView(image)
        .contentMode(.scaleAspectFill)
        .height(200) // Fixed height
        .clipsToBounds(true)
}
.spacing(16) // Spacing between stack items
.padding(h: 20, v: 24) // Horizontal and vertical padding
.backgroundColor(.systemBackground)
.cornerRadius(12)
```

### Alignment (ZStackView)
In `ZStackView`, you can position items using `.position()` + `.margins()` (from `Builder+Attributes`):
```swift
ZStackView {
    ImageView(backdrop)
        .contentMode(.scaleAspectFill)
    
    LabelView("Overlay Text")
        .color(.white)
        .position(.bottomLeft) // Positions to the bottom-left of the ZStack
        .margins(16)
}
```

---

### Screen Layout Container

Use `Screen` to establish a standard page architecture with content and navigation bar "slots". This replaces manual `ZStackView` + `.position(.top)` boilerplate:

```swift
Screen {
    CollectionView {
        heroSection
        popularSection
    }
    .onScroll { scrollView in
        scrollBinding.offset = scrollView.contentOffset.y
    }
}
.navigationBar {
    HomeNavigationBar(
        scrollOffset: scrollBinding.$offset.eraseToAnyViewBinding()
    )
}
.backgroundColor(UIColor("#0A0A0A"))
```

The `Screen` handles Z-stacking automatically. Each screen provides its own distinct navigation bar.

---

## ⚡️ Reactive State (Binding)

Instead of manually updating UI elements when data changes, use Construkt's binding modifiers. The ViewModel exposes `@Variable`, and the View binds to `$variable`.

**ViewModel:**
```swift
class ProfileViewModel {
    @Variable var name: String = "John Doe"
    @Variable var isSaving: Bool = false
    let onSaveTapped = Signal<Void>()
}
```

**View:**
```swift
VStackView {
    LabelView($viewModel.name) // Automatically updates when `name` changes
        .font(.body)

    ButtonView("Save")
        .hidden(bind: $viewModel.isSaving) // Hides when saving is true
        .onTap { [weak viewModel] _ in
            viewModel?.onSaveTapped.send()
        }
    
    ActivityIndicator()
        .hidden(bind: $viewModel.isSaving.map { !$0 }) // Inverse mapping
}
```

> **Note:** Do NOT write `.map { !$0 }` unless you are mapping a Boolean. Always import `Construkt` to ensure modifiers are available.

---

## 🗂 Lists and Collections

For lists, **always** use Construkt's declarative `CollectionView`. Never manually create Data Sources.

### 1. Dynamic Collections
When binding to an array or an Rx `@Variable` array, provide the `items:` parameter to a `AnySection` constructor, and yield `Cell(...)` instances.

```swift
CollectionView {
    AnySection(
        id: "movies_section", 
        items: viewModel.movies, // or $viewModel.movies
        header: Header { LabelView("Trending Now").font(.title1).padding(h: 16) }
    ) { movie in
        AnyCell(movie, id: movie.id) { movieData in
            MoviePosterCell(movie: movieData)
        }
    }
    .onSelect { movie in
        // Direct strongly-typed model access
        print("Selected \(movie)") 
    }
    .layout { environment in
        // Return NSCollectionLayoutSection
    }
}
```

### 2. Static Collections
You can build statically-defined declarative collections (e.g., Settings menus) by listing explicit `AnyCell` components within a `AnySection`:

```swift
CollectionView {
    AnySection(id: "settings_section", header: Header { LabelView("General") }) {
        AnyCell("Notifications", id: "notifications") { title in
            SettingsRowView(title: title)
        }
        AnyCell("Privacy", id: "privacy") { title in
            SettingsRowView(title: title)
        }
    }
    .onSelect { title in
        print("Tapped on \(title)")
    }
}
```

### 3. Shimmer Loading States
Construkt supports natively swapping an entire `AnySection` with shimmer placeholders during load times. Use the `.shimmer(count:when:...)` modifier directly on the Section:

```swift
AnySection(id: "popular", items: viewModel.popularMovies) { movie in
    AnyCell(movie, id: movie.id) { movie in 
        MoviePosterCell(movie: movie)
    }
}
.shimmer(count: 5, when: $viewModel.isLoading) {
    MoviePosterCell(movie: .placeholder) // Create geometry for shimmer
}
```

---

## 🏗 View Composition (Creating custom views)

When a UI becomes complex, you **MUST** extract it into separate, context-specific structs adopting `ViewBuilder`. **Never** generate a massive, single `body` with dozens of nested stacks. 

For instance, if building a user profile screen, separate it into `ProfileHeaderView`, `StatsRowView`, and `RecentActivityView`. Then assemble them inside the root view.

```swift
import UIKit
import Construkt

struct UserProfileCard: ViewBuilder {
    let user: User
    
    var body: View { // Must return Construkt's `View` type
        HStackView {
            ImageView(user.avatar)
                .size(width: 50, height: 50)
                .cornerRadius(25)
            
            VStackView {
                LabelView(user.name).font(.headline)
                LabelView(user.role).font(.subheadline).color(.secondaryLabel)
            }
            .spacing(4)
            
            SpacerView()
        }
        .padding(16)
        .backgroundColor(.secondarySystemBackground)
        .cornerRadius(12)
    }
}
```

To instantiate this into a raw UIKit `UIView`, call `.build()`:
```swift
let customView: UIView = UserProfileCard(user: currentUser).build()
```

### Component Parameterization & Reusability

If you are building a layout containing multiple identical UI blocks (e.g., a row of feature highlights, three pricing cards, or identical buttons), **you MUST** extract the structural boilerplate into a dynamically parameterized `ViewBuilder` component. Pass unique text, images, or configurations as immutable properties (`let`).

**Example: Extracting identical statistics cards**
```swift
// 1. Define the reusable parameterized struct
struct StatCard: ViewBuilder {
    let title: String
    let value: String

    var body: View {
        VStackView {
            LabelView(value).font(.title1)
            LabelView(title).font(.caption1).color(.secondaryLabel)
        }
        .padding(16)
        .backgroundColor(.secondarySystemBackground)
        .cornerRadius(12)
    }
}

// 2. Instantiate multiple times in the parent scope rather than duplicating raw views
struct DashboardStatsView: ViewBuilder {
    var body: View {
        HStackView {
            StatCard(title: "Followers", value: "1.2k")
            StatCard(title: "Following", value: "400")
            StatCard(title: "Posts", value: "32")
        }
        .spacing(12)
        .distribution(.fillEqually)
    }
}
```

---

## 7. Comprehensive View Modifiers Reference

You **must exclusively use** these native Construkt modifiers. Do not invent SwiftUI names (e.g., use `.backgroundColor` not `.background`, `.alpha` not `.opacity`, `.frame(height:width:)` not `.frame(maxWidth:)`).

### Layout & Sizing (from `Builder+Constraints`)
- `.frame(height:width:)` — set explicit dimensions (both optional)
- `.size(width:height:)` — shorthand for `.width().height()`
- `.height(CGFloat)` / `.height(CGFloat, priority:)` — constrain height
- `.height(min:)` / `.height(max:)` — min/max height constraints
- `.width(CGFloat)` / `.width(CGFloat, priority:)` — constrain width
- `.width(min:)` / `.width(max:)` — min/max width constraints
- `.contentCompressionResistancePriority(UILayoutPriority, for: .horizontal/.vertical)`
- `.contentHuggingPriority(UILayoutPriority, for: .horizontal/.vertical)`
- `.zIndex(CGFloat)` — set layer z-position

### Padding (from `Builder+Padding`, only on Paddable views: Stacks, Labels, Buttons)
- `.padding(CGFloat)` — uniform all edges
- `.padding(h:v:)` — horizontal + vertical
- `.padding(top:left:bottom:right:)` — per-edge
- `.padding(insets: UIEdgeInsets)` — raw insets

### Container Embedding (from `Builder+Attributes`)
- `.margins(CGFloat)` / `.margins(h:v:)` / `.margins(top: 12, bottom: 12)` — embed margins (parameters can be partial: `top:left:bottom:right:`)
  > ⚠️ **CRITICAL**: The modifier is `.margins` (with an 's'). NEVER use `.margin` without the 's' — it does not exist.
- `.position(.center)` / `.position(.top)` / `.position(.fill)` — embed alignment
- `.safeArea(Bool)` — respect safe area when embedded
- `.customConstraints { view in }` — raw AutoLayout access

### Appearance & Styling (from `Builder+View`)
- `.backgroundColor(UIColor)`
- `.alpha(CGFloat)`
- `.cornerRadius(CGFloat)` / `.roundedCorners(radius:corners:)`
- `.border(color:lineWidth:)`
- `.shadow(color:radius:opacity:offset:)`
- `.tintColor(UIColor)`
- `.clipsToBounds(Bool)`
- `.contentMode(UIView.ContentMode)`
- `.hidden(Bool)` / `.hidden(bind: $variable)`
- `.isOpaque(Bool)`
- `.isUserInteractionEnabled(Bool)` / `.userInteractionEnabled(bind: $variable)`

### Reactive Bindings (from `Builder+Bindings`)
- `.bind(keyPath, to: binding)` — bind any writable keypath to a reactive stream
- `.onReceive(binding) { context in }` — react to any value change
- `.hidden(when: $isHidden)` — reactively show/hide
- `.userInteractionEnabled(when: $binding)` — reactively enable/disable interaction
- `.eraseToAnyViewBinding()` — type-erase any `ViewBinding` into `AnyViewBinding<T>`

### Typography (LabelView modifiers)
- `.font(UIFont)` / `.font(.headline)` — set font
- `.color(UIColor)` / `.color(bind: $variable)` — set text color
- `.text(bind: $variable)` — reactively update text
- `.alignment(NSTextAlignment)` — text alignment
- `.numberOfLines(Int)` — line count
- `.lineBreakMode(NSLineBreakMode)` — truncation mode

### StackView (HStackView / VStackView)
- `.spacing(CGFloat)` / `.customSpacing(CGFloat, after: View)` — inter-item spacing
- `.alignment(UIStackView.Alignment)` — cross-axis alignment
- `.distribution(UIStackView.Distribution)` — main-axis distribution
- `.layoutMarginsRelativeArrangement(Bool)` — use layout margins

### ButtonView modifiers
- `.onTap { context in }` — handle tap
- `.font(UIFont)` / `.font(.headline)` — title font
- `.color(UIColor, for: .normal)` — title color
- `.backgroundColor(UIColor, for: .highlighted)` — per-state background
- `.alignment(UIControl.ContentHorizontalAlignment)` — content alignment
- `.enabled(Bool)` / `.enabled(bind: $variable)` — enable/disable

### ImageView modifiers
- `.tintColor(UIColor)` — template image tint
- `.image(bind: $variable)` — reactively update image

### SwitchView modifiers
- `.isOn(bind: $variable)` / `.isOn(bidirectionalBind: $variable)` — bind toggle state
- `.onTintColor(UIColor)` — on-state color
- `.onChange { context in }` — react to toggle changes

### Gestures (from `Builder+Gestures`)
- `.onTapGesture { context in }` / `.onTapGesture(numberOfTaps: 2) { context in }`
- `.onSwipeRight { context in }` / `.onSwipeLeft { context in }`
- `.hideKeyboardOnBackgroundTap()`

### Lifecycle (from `Builder+Attributes`, on `ViewBuilderEventHandling` views)
- `.onAppear { context in }` — fires each time view enters window
- `.onAppearOnce { context in }` — fires only the first time
- `.onDisappear { context in }` — fires when leaving window

### Utility Components
- `SpacerView()` — flexible space (pushes siblings apart)
- `SpacerView(h: 16)` — minimum-height spacer / `SpacerView(w: 8)` — minimum-width spacer
- `FixedSpacerView(8)` — rigid height spacer / `FixedSpacerView(width: 8)` — rigid width spacer
- `DividerView()` — 1px separator line with `.color(UIColor)` modifier
- `ContainerView { ... }` — single-child host view (also aliased as `ZStackView`)
- `DynamicContainerView($binding) { value in ... }` — reactively swaps child view
- `ForEach(array) { element in ... }` — iterate over an array to produce views
- `ForEach(count) { index in ... }` — iterate N times to produce views
- `CGFloat.scrollProgress(over: CGFloat) -> CGFloat` — normalize scroll offset into 0…1 range

## 8. Advanced Capabilities

Construkt supports full application features declaratively.

### Navigation and Routing
Construkt provides multiple ways to navigate between screens.

**Declarative Routing** — attach navigation intent directly to sections:
```swift
AnySection(id: "popular", items: movies) { movie in
    AnyCell(movie, id: movie.id) { movie in PosterCell(movie: movie) }
}
.onRoute { (movie: Movie) in
    AppRoute.movieDetail(movieId: String(movie.id))
}
```

**Sender-Based Routing** — route from the tapped view's responder chain:
```swift
.onTapGesture { context in
    context.view.route(HomeRoute.search, sender: nil)
}
```

**Inline Route Handling** — attach handlers when constructing screens:
```swift
HomeView()
    .onReceiveRoute(HomeRoute.self) { route in
        switch route {
        case .movieDetail(let id): open(.movieDetail(movieId: id))
        case .search: open(.search)
        }
        return true
    }
    .toPresentable()
```

**Coordinator Pattern** — for complex navigation hierarchies with parent-child relationships:
```swift
final class HomeCoordinator: BaseCoordinator, RouteHandlingCoordinator {
    typealias Event = HomeRoute
    let router: ConstruktRouter

    init(router: ConstruktRouter) {
        self.router = router
    }

    override func start() {
        let homeVC = HomeView(viewModel: viewModel).toPresentable()
        router.setRoot(homeVC, hideBar: true, animated: false, receiver: self)
    }

    func canReceive(_ event: HomeRoute, sender: Any?) -> Bool {
        switch event {
        case .movieDetail(let id):
            router.push(MovieDetailView(movie: movie).toPresentable(), animated: true, receiver: self)
            return true
        case .search:
            router.push(SearchViewController(), animated: true, receiver: self)
            return true
        }
    }
}
```

Key types:
- `BaseCoordinator` — base class with `children`, `store()`, `free()`, and `start()`
- `RouteHandlingCoordinator` — protocol requiring `router` + `canReceive()` to handle route events
- `ConstruktRouter` / `DefaultRouter` — `push`, `pop`, `present`, `dismiss`, `setRoot`
- `receiver: self` — binds the coordinator to the VC so events route back correctly

### Scroll-Driven Reactive Patterns

For scroll-driven UI (e.g., stretchy headers, fading nav bars), separate reactive data from imperative UIKit handles:

```swift
// Pure reactive data — observable, testable
private class ScrollBinding {
    @Variable var offset: CGFloat = 0
    @Variable var scrollToTopTrigger: UInt = 0
}

// Imperative UIKit handles — needed for constraint manipulation
private class ViewHandles {
    weak var heroHeightConstraint: NSLayoutConstraint?
    weak var scrollView: UIScrollView?
}
```

Bind scroll events to `ScrollBinding`, then use `.onReceive` to drive UI:
```swift
.onScroll { scrollView in
    scrollBinding.offset = scrollView.contentOffset.y
}

// In the nav bar:
.onReceive(scrollBinding.$offset) { context in
    context.view.alpha = context.value.scrollProgress(over: 100)
}
```

### Scroll Views
Do not build custom layouts on raw `UIScrollView` constraints. Use `ScrollView` and `VerticalScrollView`.

```swift
VerticalScrollView(safeArea: true) { // Automatically fills width
    VStackView {
        LabelView("Top")
        SpacerView()
        LabelView("Bottom")
    }
}
.automaticallyAdjustForKeyboard()
```

### Forms & TextFields
`TextField` supports bidirectional binding to a `@Variable` string.

```swift
TextField(bidirectionalBind: $viewModel.username)
    .placeholder("Enter Username")
    .autocapitalizationType(.none)
    .keyboardType(.emailAddress)
    .onChange { context in
        let text = context.value // The string inside the textfield
    }
```

### Gestures
Any Construkt view can respond to gestures via chained modifiers:

```swift
ImageView(headerImage)
    .onTapGesture(numberOfTaps: 2) { context in
        print("Double Tapped!")
    }
    .onSwipeRight { context in
        context.navigationController?.popViewController(animated: true)
    }

// Hide keyboard globally on a root ZStackView
ZStackView { ... }.hideKeyboardOnBackgroundTap()
```

---

## ⚠️ Anti-Patterns (What NOT to do)
1. **Never use SwiftUI `Text`, `Image`, or `VStack`.** Always use the Construkt equivalents (`LabelView`, `ImageView`, `VStackView`).
2. **Never import SwiftUI.** Only import `UIKit` and `Construkt`.
3. **Never write `setupConstraints()` or use `translatesAutoresizingMaskIntoConstraints = false`.**
4. **Never create generic constraint arrays.** 
5. **Never write `UICollectionViewDataSource` logic.** Use `CollectionView` ResultBuilders.

---

## 🐛 Troubleshooting & Debugging Compiler Errors

Because ConstruktKit relies heavily on Swift Result Builders (`@ViewBuilder`), certain compilation errors can be opaque and misleading. When the Swift compiler fails to type-check a large nested view hierarchy, it usually points to the parent container instead of the exact line causing the issue.

### 1. Handling "Opaque" Error Messages
If you see either of the following errors pointing to a `VStackView`, `HStackView`, `ZStackView`, or `CollectionView`:
*   `"extra trailing closure passed in call"`
*   `"initializer 'init(_:)' requires the types '(() -> ()).Value' and '[any View]' be equivalent"`

**DO NOT** assume the structure itself is wrong. This almost always means there is a **type mismatch** or an **invalid modifier** deeply nested inside that container block. The Swift compiler ran out of time or inference capabilities and gave up at the top level.

### 2. Isolation Strategy (How to find the real error)
To find the actual line causing the bug, you **MUST isolate the components**.

Extract inner views from the failing stack into local `let` variables or separate computed properties (`var myView: View { ... }`). By doing this, you force the Swift compiler to evaluate each piece independently. The compiler will immediately highlight the exact variable definition that contains the typo or invalid modifier.

**Example of an obscure error:**
```swift
var body: View {
    VStackView { // ERROR: "extra trailing closure passed in call"
        LabelView("Title")
        ImageView(myImage)
            .clipShape(.circle) // This is the real bug (SwiftUI modifier, not Construkt)
    }
}
```

**How to isolate it:**
```swift
var body: View {
    let titleLab = LabelView("Title")
    
    // The compiler will now correctly flag THIS exact line:
    let image = ImageView(myImage).clipShape(.circle) 
    
    return VStackView {
        titleLab
        image
    }
}
```

### 3. Common AI Hallucinations
When generating ConstruktKit code, AI often hallucinates SwiftUI equivalents. If a file fails to build, check for these common mistakes first:

1. Non-existent components (e.g. using `Text` instead of `LabelView` or `Spacer` instead of `SpacerView`)
2. Non-existent modifiers (e.g. using `.clipShape()` instead of `.cornerRadius().clipsToBounds(true)`)
3. Wrong modifier signatures (e.g. wrong padding parameters or `.border` arguments)
4. Wrong component initializer signatures (e.g. `SpacerView(width:)` instead of `FixedSpacerView(width:)`)
5. Using `ZStackView` + `.position(.top)` for nav bars instead of `Screen { ... }.navigationBar { ... }`

---

### Feature Composition

**Pattern: Parent-child reducer delegation**
```swift
case .child(let childIntent):
    let childResult = ChildFeature.reduce(state: &state.child, intent: childIntent)
    return childResult.map(
        effect: { Effect.child($0) },
        output: { Output.child($0) }
    )
```

**Pattern: Effect executor delegation**
```swift
case .child(let childEffect):
    let childFeedback = try await childExecutor(childEffect, deps.childDeps)
    return childFeedback.map(intent: { .child($0) }, output: { .child($0) })
```

**Pattern: Policy delegation**
```swift
case .child(let childEffect):
    return ChildFeature.policy(for: childEffect)
```

**Anti-pattern: Forgetting to map child types**
```swift
// WRONG: Returns ReduceResult<ChildEffect, ChildOutput> — type mismatch
case .child(let childIntent):
    return ChildFeature.reduce(state: &state.child, intent: childIntent)

// RIGHT: Map to parent types
case .child(let childIntent):
    return ChildFeature.reduce(state: &state.child, intent: childIntent)
        .map(effect: { .child($0) }, output: { .child($0) })
```

**Anti-pattern: Creating separate FeatureStore for child**
```swift
// WRONG: Child runs in its own runtime — no composition
let childStore = FeatureStore<ChildFeature>(...)
let parentStore = FeatureStore<ParentFeature>(...)

// RIGHT: Single parent store, child state embedded
let store = FeatureStore<ParentFeature>(...)
store.dispatch(.child(.loadProfile))
store.state.map(\.child.username)  // observe child state through parent
```
