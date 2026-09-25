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

@Suite struct ScreenLayoutSolverTests {
    @Test func safeAreaAndCameraOcclusion() {
        let safe = rect(12, 42, 366, 760)
        let camera = rect(160, 42, 70, 40)
        let environment = DisplayEnvironment(bounds: rect(0, 0, 390, 844), safeBounds: safe,
            reservedRegions: [ReservedRegion(frame: camera, kind: .occlusion)])
        let result = ScreenLayoutSolver.solve(environment: environment)
        expectScreen(result.upperScreen, inside: safe, avoiding: [camera])
        expectScreen(result.lowerScreen, inside: safe, avoiding: [camera])
        #expect(!result.upperScreen.intersects(result.lowerScreen))
        for controls in result.controlRegions {
            #expect(safe.contains(controls))
            #expect(!controls.intersects(camera))
            #expect(!controls.intersects(result.upperScreen))
            #expect(!controls.intersects(result.lowerScreen))
        }
    }

    @Test func divisionAndSwapKeepPanesDistinct() {
        let safe = rect(0, 0, 900, 700)
        let division = rect(440, 0, 20, 700)
        let environment = DisplayEnvironment(bounds: safe, safeBounds: safe,
            reservedRegions: [ReservedRegion(frame: division, kind: .division)])
        let standard = ScreenLayoutSolver.solve(environment: environment)
        let swapped = ScreenLayoutSolver.solve(environment: environment, swapScreens: true)
        expectScreen(standard.upperScreen, inside: safe, avoiding: [division])
        expectScreen(standard.lowerScreen, inside: safe, avoiding: [division])
        #expect(standard.effectiveMode == .split)
        #expect(standard.upperScreen.duoEquals(swapped.lowerScreen))
        #expect(standard.lowerScreen.duoEquals(swapped.upperScreen))
    }

    @Test func manualModesAndCompactFallback() {
        let safe = rect(0, 0, 320, 470)
        let environment = DisplayEnvironment(bounds: safe, safeBounds: safe)
        let stacked = ScreenLayoutSolver.solve(environment: environment, preference: .stacked)
        let side = ScreenLayoutSolver.solve(environment: environment, preference: .sideBySide)
        #expect(stacked.effectiveMode == .stacked)
        #expect(side.effectiveMode == .sideBySide)
        for screen in [stacked.upperScreen, stacked.lowerScreen, side.upperScreen, side.lowerScreen] {
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
        let min = ScreenLayoutSolver.clusterMinimum
        let safe = rect(0, 0, size.width, size.height)
        let result = ScreenLayoutSolver.solve(environment: DisplayEnvironment(bounds: safe, safeBounds: safe))
        try #require(result.controlRegions.count == 2, "\(name)")
        #expect(!result.controlsOverlapScreens, "\(name)")
        #expect(!result.isCompact, "\(name)")
        let (left, right) = (result.controlRegions[0], result.controlRegions[1])
        #expect(left.midX < right.midX, "\(name): D-pad cluster must be on the left")
        for cluster in result.controlRegions {
            #expect(cluster.width >= min.width, "\(name)")
            #expect(cluster.height >= min.height, "\(name)")
            #expect(safe.contains(cluster), "\(name)")
            #expect(!(cluster.intersects(result.upperScreen) || cluster.intersects(result.lowerScreen)), "\(name)")
        }
        #expect(!left.intersects(right), "\(name)")
    }

    @Test func halfFoldPutsControlsWithLowerScreenClearOfHinge() {
        let safe = rect(0, 0, 867, 523)
        let division = rect(456, -82, 40, 669)
        let result = ScreenLayoutSolver.solve(environment: DisplayEnvironment(bounds: safe, safeBounds: safe,
            reservedRegions: [ReservedRegion(frame: division, kind: .division)]))
        #expect(result.effectiveMode == .split)
        #expect(result.controlRegions.count == 2)
        for cluster in result.controlRegions {
            #expect(!cluster.intersects(division))
            #expect(!(cluster.intersects(result.lowerScreen) || cluster.intersects(result.upperScreen)))
        }
    }
}
