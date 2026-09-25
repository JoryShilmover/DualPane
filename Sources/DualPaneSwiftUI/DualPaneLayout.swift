// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import SwiftUI
import DualPaneCore

/// Places exactly two subviews in the panes chosen by ``DualPaneSolver``: the first in the primary pane,
/// the second in the secondary pane. Pass exclusion regions (in this layout's coordinate space) to keep
/// panes clear of a hinge or cutout.
public struct DualPaneLayout: Layout {
    public var configuration: DualPaneConfiguration
    public var preference: ArrangementPreference
    public var swapPanes: Bool
    public var exclusionRegions: [ExclusionRegion]

    public init(configuration: DualPaneConfiguration = DualPaneConfiguration(),
                preference: ArrangementPreference = .automatic, swapPanes: Bool = false,
                exclusionRegions: [ExclusionRegion] = []) {
        self.configuration = configuration
        self.preference = preference
        self.swapPanes = swapPanes
        self.exclusionRegions = exclusionRegions
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let local = CGRect(origin: .zero, size: bounds.size)
        let solution = DualPaneSolver.solve(
            environment: DisplayEnvironment(bounds: local, safeBounds: local, exclusionRegions: exclusionRegions),
            configuration: configuration, preference: preference, swapPanes: swapPanes)
        for (subview, frame) in zip(subviews, [solution.primaryPane, solution.secondaryPane]) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }
}
