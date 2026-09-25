// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
import DualPaneCore

/// The default configuration: two panes that fill their slots, no accessory regions.
@Suite struct DefaultConfigurationTests {
    private func solve(_ width: CGFloat, _ height: CGFloat, exclusions: [ExclusionRegion] = [],
                       configuration: DualPaneConfiguration = DualPaneConfiguration(),
                       swapPanes: Bool = false) -> LayoutSolution {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        return DualPaneSolver.solve(environment: DisplayEnvironment(bounds: bounds, safeBounds: bounds,
                                                                    exclusionRegions: exclusions),
                                    configuration: configuration, swapPanes: swapPanes)
    }

    @Test func portraitStacksFullWidthPanes() {
        let result = solve(400, 800)
        #expect(result.arrangement == .stacked)
        #expect(result.primaryPane == CGRect(x: 0, y: 0, width: 400, height: 396))
        #expect(result.secondaryPane == CGRect(x: 0, y: 404, width: 400, height: 396))
        #expect(result.accessoryRegions.isEmpty)
        #expect(!result.accessoriesOverlapPanes)
        #expect(!result.isCompact)
    }

    @Test func landscapePlacesPanesSideBySide() {
        let result = solve(1000, 600)
        #expect(result.arrangement == .sideBySide)
        #expect(result.primaryPane == CGRect(x: 0, y: 0, width: 496, height: 600))
        #expect(result.secondaryPane == CGRect(x: 504, y: 0, width: 496, height: 600))
    }

    @Test func hingeSplitsPanesAndStaysClear() {
        let hinge = CGRect(x: 490, y: 0, width: 20, height: 700)
        let result = solve(1000, 700, exclusions: [ExclusionRegion(frame: hinge, kind: .division)])
        #expect(result.arrangement == .split)
        #expect(result.primaryPane == CGRect(x: 0, y: 0, width: 490, height: 700))
        #expect(result.secondaryPane == CGRect(x: 510, y: 0, width: 490, height: 700))
    }

    @Test func swappingKeepsEachPaneItsOwnSizing() {
        let configuration = DualPaneConfiguration(primarySizing: .aspectRatio(16.0 / 9.0), secondarySizing: .fill)
        for swap in [false, true] {
            let result = solve(400, 800, configuration: configuration, swapPanes: swap)
            #expect(abs(result.primaryPane.width / result.primaryPane.height - 16.0 / 9.0) < 0.001, "swap=\(swap)")
            #expect(result.secondaryPane.width == 400, "swap=\(swap)")
            #expect((result.primaryPane.midY < result.secondaryPane.midY) == !swap, "swap=\(swap)")
        }
    }

    @Test func smallDisplayIsCompact() {
        #expect(solve(300, 300).isCompact)
    }
}
