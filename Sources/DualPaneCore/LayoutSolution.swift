// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum ArrangementPreference: Equatable, Sendable { case automatic, stacked, sideBySide }

public enum PaneArrangement: Equatable, Sendable {
    /// One pane above the other.
    case stacked
    /// Panes next to each other.
    case sideBySide
    /// Panes on either side of a division, such as a hinge.
    case split
}

public struct LayoutSolution: Equatable, Sendable {
    public let primaryPane: CGRect
    public let secondaryPane: CGRect
    public let arrangement: PaneArrangement
    /// Exactly two regions when non-empty: [leading, trailing].
    public let accessoryRegions: [CGRect]
    /// True when the smaller pane is below the configuration's minimum legible size.
    public let isCompact: Bool
    /// True only in the last-resort fallback where accessory regions are overlaid on the panes.
    public let accessoriesOverlapPanes: Bool

    public init(primaryPane: CGRect, secondaryPane: CGRect, arrangement: PaneArrangement,
                accessoryRegions: [CGRect], isCompact: Bool, accessoriesOverlapPanes: Bool = false) {
        self.primaryPane = primaryPane
        self.secondaryPane = secondaryPane
        self.arrangement = arrangement
        self.accessoryRegions = accessoryRegions
        self.isCompact = isCompact
        self.accessoriesOverlapPanes = accessoriesOverlapPanes
    }
}
