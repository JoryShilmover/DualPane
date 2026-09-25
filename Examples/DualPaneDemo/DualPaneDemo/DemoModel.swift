// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import CoreGraphics
import DualPaneCore
import Foundation
import Observation

enum DisplayPreset: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case duoInnerPortrait = "Duo inner, portrait"
    case duoInnerLandscape = "Duo inner, landscape"
    case duoOuter = "Duo outer"
    case iPhonePortrait = "iPhone, portrait"
    case iPhoneLandscape = "iPhone, landscape"
    case iPadLandscape = "iPad, landscape"

    var id: Self { self }

    /// Display size in points; `nil` fills the space available.
    var size: CGSize? {
        switch self {
        case .freeform: nil
        case .duoInnerPortrait: CGSize(width: 669, height: 805)
        case .duoInnerLandscape: CGSize(width: 867, height: 523)
        case .duoOuter: CGSize(width: 382, height: 532)
        case .iPhonePortrait: CGSize(width: 430, height: 747)
        case .iPhoneLandscape: CGSize(width: 814, height: 350)
        case .iPadLandscape: CGSize(width: 1194, height: 834)
        }
    }
}

enum ConfigurationPreset: String, CaseIterable, Identifiable {
    case plain = "Plain panes"
    case ds = "DS screens + controls"

    var id: Self { self }

    var configuration: DualPaneConfiguration {
        switch self {
        case .plain: DualPaneConfiguration()
        case .ds: .ds
        }
    }
}

enum SizingOption: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case square = "1:1"
    case fourByThree = "4:3"
    case sixteenByNine = "16:9"

    var id: Self { self }

    var sizing: PaneSizing {
        switch self {
        case .fill: .fill
        case .square: .aspectRatio(1)
        case .fourByThree: .aspectRatio(4.0 / 3.0)
        case .sixteenByNine: .aspectRatio(16.0 / 9.0)
        }
    }

    init(_ sizing: PaneSizing) {
        self = Self.allCases.first { $0.sizing == sizing } ?? .fill
    }
}

enum HingeOrientation: String, CaseIterable, Identifiable {
    case vertical = "Vertical"
    case horizontal = "Horizontal"
    var id: Self { self }
}

@MainActor @Observable
final class DemoModel {
    var displayPreset: DisplayPreset = .freeform
    var configurationPreset: ConfigurationPreset = .plain {
        didSet { configuration = configurationPreset.configuration }
    }
    var configuration = DualPaneConfiguration()
    var preference: ArrangementPreference = .automatic
    var swapPanes = false

    var showsHinge = false
    var hingeOrientation: HingeOrientation = .vertical
    /// Hinge centre as a fraction of the display's width (vertical) or height (horizontal).
    var hingePosition: CGFloat = 0.5
    var hingeThickness: CGFloat = 20

    var showsCamera = false
    /// Camera centre as fractions of the display size.
    var cameraCenter = CGPoint(x: 0.5, y: 0.03)
    static let cameraSize = CGSize(width: 70, height: 40)

    var showsOutlines = true

    /// Starting state from launch arguments, for scripted screenshots, for example
    /// `-display duoInnerLandscape -configuration ds -hinge vertical -camera YES`.
    func applyLaunchArguments(_ defaults: UserDefaults = .standard) {
        func match<T: CaseIterable>(_ key: String, _: T.Type) -> T? {
            guard let name = defaults.string(forKey: key) else { return nil }
            return T.allCases.first { "\($0)" == name }
        }
        if let preset = match("display", DisplayPreset.self) { displayPreset = preset }
        if let preset = match("configuration", ConfigurationPreset.self) { configurationPreset = preset }
        if let orientation = match("hinge", HingeOrientation.self) {
            showsHinge = true
            hingeOrientation = orientation
        }
        if defaults.bool(forKey: "camera") { showsCamera = true }
    }

    func hingeFrame(in size: CGSize) -> CGRect {
        switch hingeOrientation {
        case .vertical:
            CGRect(x: size.width * hingePosition - hingeThickness / 2, y: 0, width: hingeThickness, height: size.height)
        case .horizontal:
            CGRect(x: 0, y: size.height * hingePosition - hingeThickness / 2, width: size.width, height: hingeThickness)
        }
    }

    func cameraFrame(in size: CGSize) -> CGRect {
        let s = Self.cameraSize
        return CGRect(x: size.width * cameraCenter.x - s.width / 2, y: size.height * cameraCenter.y - s.height / 2,
                      width: s.width, height: s.height)
    }

    func exclusionRegions(in size: CGSize) -> [ExclusionRegion] {
        var regions: [ExclusionRegion] = []
        if showsHinge { regions.append(ExclusionRegion(frame: hingeFrame(in: size), kind: .division)) }
        if showsCamera { regions.append(ExclusionRegion(frame: cameraFrame(in: size), kind: .occlusion)) }
        return regions
    }

    func environment(for size: CGSize) -> DisplayEnvironment {
        let bounds = CGRect(origin: .zero, size: size)
        return DisplayEnvironment(bounds: bounds, safeBounds: bounds, exclusionRegions: exclusionRegions(in: size))
    }

    func solve(_ environment: DisplayEnvironment) -> LayoutSolution {
        DualPaneSolver.solve(environment: environment, configuration: configuration,
                             preference: preference, swapPanes: swapPanes)
    }
}
