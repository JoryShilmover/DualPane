# ``DualPaneCore``

Solve two-pane layouts around hinges, folds, cutouts and safe areas.

## Overview

`DualPaneCore` is platform-independent geometry. Describe the display with a ``DisplayEnvironment``
(bounds, safe area and any ``ReservedRegion``s such as a hinge or camera), then call
``ScreenLayoutSolver/solve(environment:preference:swapScreens:)`` to get a ``LayoutSolution``.

## Topics

### Describing the display

- ``DisplayEnvironment``
- ``ReservedRegion``

### Solving

- ``ScreenLayoutSolver``
- ``ScreenLayoutPreference``
- ``LayoutSolution``
- ``ScreenLayoutMode``
