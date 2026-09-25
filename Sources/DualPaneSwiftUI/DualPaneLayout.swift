// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import SwiftUI
import DualPaneCore

/// Places exactly two subviews in the panes chosen by ``ScreenLayoutSolver``.
/// The first subview goes in the upper (or leading) pane, the second in the lower (or trailing) pane.
/// Pass reserved regions (in this layout's coordinate space) to keep panes clear of a hinge or cutout.
public struct DualPaneLayout: Layout {
    public var preference: ScreenLayoutPreference
    public var swapPanes: Bool
    public var reservedRegions: [DualPaneCore.ReservedRegion]

    public init(preference: ScreenLayoutPreference = .automatic, swapPanes: Bool = false,
                reservedRegions: [DualPaneCore.ReservedRegion] = []) {
        self.preference = preference
        self.swapPanes = swapPanes
        self.reservedRegions = reservedRegions
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let local = CGRect(origin: .zero, size: bounds.size)
        let solution = ScreenLayoutSolver.solve(
            environment: DisplayEnvironment(bounds: local, safeBounds: local, reservedRegions: reservedRegions),
            preference: preference, swapScreens: swapPanes)
        for (subview, frame) in zip(subviews, [solution.upperScreen, solution.lowerScreen]) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }
}
