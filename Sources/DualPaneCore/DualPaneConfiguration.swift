// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How a pane fills the slot the solver gives it.
public enum PaneSizing: Hashable, Sendable {
    /// Take the whole slot.
    case fill
    /// The largest rectangle of this width-to-height ratio, centred in the slot.
    case aspectRatio(CGFloat)
}

/// Which dimension counts as a pane's size when layouts are compared.
public enum PaneMeasure: Hashable, CaseIterable, Sendable {
    case width
    /// The smaller of width and height, which suits panes that fill their slot.
    case shortSide
}

/// Where accessory regions (for example on-screen controls) go relative to the panes.
public enum AccessoryStyle: Hashable, Sendable {
    /// A strip of this height below the panes, with one region at each end.
    case band(height: CGFloat)
    /// A column of this width on each side of the panes, level with the secondary pane.
    case flank(width: CGFloat)
}

/// Two accessory regions (leading and trailing) that the solver keeps clear of both panes.
public struct AccessoryConfiguration: Equatable, Sendable {
    /// Smallest usable region. Band styles need room for two regions this wide; flank styles this tall.
    public var minimumSize: CGSize
    /// Regions never grow past this size.
    public var maximumSize: CGSize
    /// Styles to try. Layouts without accessory regions are always considered too.
    public var styles: [AccessoryStyle]

    public init(minimumSize: CGSize, maximumSize: CGSize, styles: [AccessoryStyle]) {
        self.minimumSize = minimumSize
        self.maximumSize = maximumSize
        self.styles = styles
    }
}

/// What the solver optimises for.
public struct DualPaneConfiguration: Equatable, Sendable {
    public var primarySizing: PaneSizing
    public var secondarySizing: PaneSizing
    /// Space between panes in stacked and side-by-side layouts.
    public var gutter: CGFloat
    public var measure: PaneMeasure
    /// Smallest pane size (in ``measure``) that is still usable. Layouts that keep both panes at least
    /// this size and place accessory regions always win; below it, the solution is compact.
    public var minimumLegibleSize: CGFloat
    /// `nil` for layouts with panes only.
    public var accessories: AccessoryConfiguration?

    public init(primarySizing: PaneSizing = .fill, secondarySizing: PaneSizing = .fill, gutter: CGFloat = 8,
                measure: PaneMeasure = .shortSide, minimumLegibleSize: CGFloat = 170,
                accessories: AccessoryConfiguration? = nil) {
        self.primarySizing = primarySizing
        self.secondarySizing = secondarySizing
        self.gutter = gutter
        self.measure = measure
        self.minimumLegibleSize = minimumLegibleSize
        self.accessories = accessories
    }

    /// Two 4:3 screens with DS-style thumb-control regions, as in the Duo DS emulator. The leading region
    /// holds a shoulder button, a D-pad and a row of small buttons, so it needs at least 120 × 170 pt.
    public static let ds = DualPaneConfiguration(
        primarySizing: .aspectRatio(4.0 / 3.0), secondarySizing: .aspectRatio(4.0 / 3.0),
        gutter: 8, measure: .width, minimumLegibleSize: 170,
        accessories: AccessoryConfiguration(
            minimumSize: CGSize(width: 120, height: 170), maximumSize: CGSize(width: 220, height: 250),
            styles: [.band(height: 200), .band(height: 170), .flank(width: 170), .flank(width: 130)]))
}
