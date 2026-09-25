// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
import DualPaneCore

/// The DS preset must lay out every display exactly as the solver extracted from Duo DS did.
@Suite struct LegacyParityTests {
    struct Scenario: CustomStringConvertible {
        let size: CGSize
        let exclusion: String
        var description: String { "\(Int(size.width))x\(Int(size.height)) \(exclusion)" }
    }

    static let scenarios: [Scenario] = {
        var result: [Scenario] = []
        for width in stride(from: 200.0, through: 1100, by: 53) {
            for height in stride(from: 200.0, through: 1100, by: 53) {
                for exclusion in ["none", "vertical hinge", "horizontal hinge", "camera", "notch + inset"] {
                    result.append(Scenario(size: CGSize(width: width, height: height), exclusion: exclusion))
                }
            }
        }
        return result
    }()

    private static func regions(_ scenario: Scenario) -> (bounds: CGRect, safe: CGRect, [(CGRect, Bool)]) {
        let bounds = CGRect(origin: .zero, size: scenario.size)
        let (w, h) = (scenario.size.width, scenario.size.height)
        switch scenario.exclusion {
        case "vertical hinge": return (bounds, bounds, [(CGRect(x: w / 2 - 10, y: 0, width: 20, height: h), true)])
        case "horizontal hinge": return (bounds, bounds, [(CGRect(x: 0, y: h / 2 - 12, width: w, height: 24), true)])
        case "camera": return (bounds, bounds, [(CGRect(x: w / 2 - 35, y: 0, width: 70, height: 40), false)])
        case "notch + inset":
            let safe = bounds.insetBy(dx: 12, dy: 30)
            return (bounds, safe, [(CGRect(x: w * 0.3, y: 30, width: w * 0.2, height: 36), false)])
        default: return (bounds, bounds, [])
        }
    }

    @Test(arguments: scenarios)
    func dsPresetMatchesLegacySolver(_ scenario: Scenario) {
        let (bounds, safe, raw) = Self.regions(scenario)
        let current = DisplayEnvironment(bounds: bounds, safeBounds: safe, exclusionRegions: raw.map {
            ExclusionRegion(frame: $0.0, kind: $0.1 ? .division : .occlusion)
        })
        let legacy = Legacy.DisplayEnvironment(bounds: bounds, safeBounds: safe, exclusionRegions: raw.map {
            Legacy.ExclusionRegion(frame: $0.0, kind: $0.1 ? .division : .occlusion)
        })
        let preferences: [(ArrangementPreference, Legacy.ScreenLayoutPreference)] =
            [(.automatic, .automatic), (.stacked, .stacked), (.sideBySide, .sideBySide)]
        for (preference, legacyPreference) in preferences {
            for swap in [false, true] {
                let new = DualPaneSolver.solve(environment: current, configuration: .ds,
                                               preference: preference, swapPanes: swap)
                let old = Legacy.ScreenLayoutSolver.solve(environment: legacy, preference: legacyPreference, swapScreens: swap)
                let context = "\(scenario) \(preference) swap=\(swap)"
                #expect(new.primaryPane == old.upperScreen, "\(context)")
                #expect(new.secondaryPane == old.lowerScreen, "\(context)")
                #expect("\(new.arrangement)" == "\(old.effectiveMode)", "\(context)")
                #expect(new.accessoryRegions == old.controlRegions, "\(context)")
                #expect(new.isCompact == old.isCompact, "\(context)")
                #expect(new.accessoriesOverlapPanes == old.controlsOverlapScreens, "\(context)")
            }
        }
    }
}
