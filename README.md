# DualPane

Lay out two panes on foldable, dual-screen and ordinary displays. DualPane finds the best stacked,
side-by-side or split arrangement around hinges, camera cutouts and safe areas.

Extracted from the screen-layout solver in the Duo DS emulator.

> **Status:** early (0.x). The solver still carries its original DS-oriented defaults (4:3 panes,
> optional thumb-control regions). Generalizing them is the next milestone. Expect breaking changes.

## Modules

| Product | Platforms | What it does |
|---|---|---|
| `DualPaneCore` | all | Platform-independent solver: `DisplayEnvironment` in, `LayoutSolution` out. |
| `DualPaneUIKit` | iOS | Captures a `DisplayEnvironment` from a `UIView`, including iOS 27.1 fold regions and hinge changes. |
| `DualPaneSwiftUI` | iOS, macOS, tvOS, visionOS | `DualPaneLayout`, a SwiftUI `Layout` that places two views. |

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/JoryShilmover/DualPane.git", from: "0.1.0"),
]
```

## Usage

```swift
import DualPaneCore

let environment = DisplayEnvironment(
    bounds: CGRect(x: 0, y: 0, width: 900, height: 700),
    safeBounds: CGRect(x: 0, y: 0, width: 900, height: 700),
    reservedRegions: [ReservedRegion(frame: CGRect(x: 440, y: 0, width: 20, height: 700), kind: .division)]
)
let solution = ScreenLayoutSolver.solve(environment: environment)
// solution.upperScreen, solution.lowerScreen, solution.effectiveMode == .split
```

```swift
import SwiftUI
import DualPaneSwiftUI

DualPaneLayout {
    MapView()
    DetailView()
}
```

Fold regions come from the iOS 27.1 SDK. If you build with an older SDK, `DualPaneUIKit` reports
the safe area only.

## License

MIT. See [LICENSE](LICENSE).
