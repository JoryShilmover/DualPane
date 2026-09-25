# ``DualPaneCore``

Solve two-pane layouts around hinges, folds, cutouts and safe areas.

## Overview

`DualPaneCore` is platform-independent geometry. Describe the display with a ``DisplayEnvironment``
(bounds, safe area and any ``ExclusionRegion``s such as a hinge or camera), then call
``DualPaneSolver/solve(environment:configuration:preference:swapPanes:)`` to get a ``LayoutSolution``.

The solver considers stacked, side-by-side and split arrangements in every free area of the display
and keeps the one whose smaller pane is largest. A ``DualPaneConfiguration`` controls how panes are
sized, what counts as legible, and whether to reserve two accessory regions, such as on-screen
controls, next to the secondary pane.

## Topics

### Describing the display

- ``DisplayEnvironment``
- ``ExclusionRegion``

### Configuring

- ``DualPaneConfiguration``
- ``PaneSizing``
- ``PaneMeasure``
- ``AccessoryConfiguration``
- ``AccessoryStyle``

### Solving

- ``DualPaneSolver``
- ``ArrangementPreference``
- ``LayoutSolution``
- ``PaneArrangement``
