// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import CoreGraphics
import Testing
import DualPaneCore

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}

private func expectScreen(_ screen: CGRect, inside safe: CGRect, avoiding barriers: [CGRect],
                          sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(screen.width > 0, sourceLocation: sourceLocation)
    #expect(safe.contains(screen), sourceLocation: sourceLocation)
    #expect(abs(screen.width / screen.height - 4.0 / 3.0) < 0.001, sourceLocation: sourceLocation)
    for barrier in barriers { #expect(!screen.intersects(barrier), sourceLocation: sourceLocation) }
}

@Suite struct DSPresetTests {
    @Test func safeAreaAndCameraOcclusion() {
        let safe = rect(12, 42, 366, 760)
        let camera = rect(160, 42, 70, 40)
        let environment = DisplayEnvironment(bounds: rect(0, 0, 390, 844), safeBounds: safe,
            exclusionRegions: [ExclusionRegion(frame: camera, kind: .occlusion)])
        let result = DualPaneSolver.solve(environment: environment, configuration: .ds)
        expectScreen(result.primaryPane, inside: safe, avoiding: [camera])
        expectScreen(result.secondaryPane, inside: safe, avoiding: [camera])
        #expect(!result.primaryPane.intersects(result.secondaryPane))
        for controls in result.accessoryRegions {
            #expect(safe.contains(controls))
            #expect(!controls.intersects(camera))
            #expect(!controls.intersects(result.primaryPane))
            #expect(!controls.intersects(result.secondaryPane))
        }
    }

    @Test func divisionAndSwapKeepPanesDistinct() {
        let safe = rect(0, 0, 900, 700)
        let division = rect(440, 0, 20, 700)
        let environment = DisplayEnvironment(bounds: safe, safeBounds: safe,
            exclusionRegions: [ExclusionRegion(frame: division, kind: .division)])
        let standard = DualPaneSolver.solve(environment: environment, configuration: .ds)
        let swapped = DualPaneSolver.solve(environment: environment, configuration: .ds, swapPanes: true)
        expectScreen(standard.primaryPane, inside: safe, avoiding: [division])
        expectScreen(standard.secondaryPane, inside: safe, avoiding: [division])
        #expect(standard.arrangement == .split)
        #expect(standard.primaryPane == swapped.secondaryPane)
        #expect(standard.secondaryPane == swapped.primaryPane)
    }

    @Test func manualModesAndCompactFallback() {
        let safe = rect(0, 0, 320, 470)
        let environment = DisplayEnvironment(bounds: safe, safeBounds: safe)
        let stacked = DualPaneSolver.solve(environment: environment, configuration: .ds, preference: .stacked)
        let side = DualPaneSolver.solve(environment: environment, configuration: .ds, preference: .sideBySide)
        #expect(stacked.arrangement == .stacked)
        #expect(side.arrangement == .sideBySide)
        for screen in [stacked.primaryPane, stacked.secondaryPane, side.primaryPane, side.secondaryPane] {
            expectScreen(screen, inside: safe, avoiding: [])
        }
    }

    /// Geometries observed on the iPhone Duo simulator and the iPhone 15 Pro Max (2026-09-23), plus an
    /// estimated iPhone landscape canvas. Every pose must give two thumb clusters that are large enough,
    /// inside the safe area, and clear of both screens.
    @Test(arguments: [("Duo inner portrait", CGSize(width: 669, height: 805)),
                      ("Duo outer display", CGSize(width: 382, height: 532)),
                      ("Duo outer landscape", CGSize(width: 594, height: 320)),
                      ("Duo inner landscape", CGSize(width: 867, height: 523)),
                      ("iPhone 15 Pro Max portrait", CGSize(width: 430, height: 747)),
                      ("iPhone landscape (estimate)", CGSize(width: 814, height: 350))])
    func observedGeometriesGetThumbClusters(name: String, size: CGSize) throws {
        let min = DualPaneConfiguration.ds.accessories!.minimumSize
        let safe = rect(0, 0, size.width, size.height)
        let result = DualPaneSolver.solve(environment: DisplayEnvironment(bounds: safe, safeBounds: safe),
                                          configuration: .ds)
        try #require(result.accessoryRegions.count == 2, "\(name)")
        #expect(!result.accessoriesOverlapPanes, "\(name)")
        #expect(!result.isCompact, "\(name)")
        let (left, right) = (result.accessoryRegions[0], result.accessoryRegions[1])
        #expect(left.midX < right.midX, "\(name): D-pad cluster must be on the left")
        for cluster in result.accessoryRegions {
            #expect(cluster.width >= min.width, "\(name)")
            #expect(cluster.height >= min.height, "\(name)")
            #expect(safe.contains(cluster), "\(name)")
            #expect(!(cluster.intersects(result.primaryPane) || cluster.intersects(result.secondaryPane)), "\(name)")
        }
        #expect(!left.intersects(right), "\(name)")
    }

    @Test func halfFoldPutsControlsWithLowerScreenClearOfHinge() {
        let safe = rect(0, 0, 867, 523)
        let division = rect(456, -82, 40, 669)
        let result = DualPaneSolver.solve(environment: DisplayEnvironment(bounds: safe, safeBounds: safe,
            exclusionRegions: [ExclusionRegion(frame: division, kind: .division)]), configuration: .ds)
        #expect(result.arrangement == .split)
        #expect(result.accessoryRegions.count == 2)
        for cluster in result.accessoryRegions {
            #expect(!cluster.intersects(division))
            #expect(!(cluster.intersects(result.secondaryPane) || cluster.intersects(result.primaryPane)))
        }
    }
}
