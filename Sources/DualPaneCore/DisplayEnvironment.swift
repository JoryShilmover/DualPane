// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Part of the display that panes must stay clear of.
public struct ExclusionRegion: Equatable, Sendable {
    public enum Kind: Hashable, CaseIterable, Sendable {
        /// A physical or logical split, such as a hinge. May leave two separate usable areas.
        case division
        /// Something covering the display, such as a camera housing.
        case occlusion
    }
    public let frame: CGRect
    public let kind: Kind
    public init(frame: CGRect, kind: Kind) { self.frame = frame; self.kind = kind }
}

/// The display a layout is solved for. All rectangles use the coordinate system of the view being laid out.
public struct DisplayEnvironment: Equatable, Sendable {
    public let bounds: CGRect
    public let safeBounds: CGRect
    public let exclusionRegions: [ExclusionRegion]
    public init(bounds: CGRect, safeBounds: CGRect, exclusionRegions: [ExclusionRegion] = []) {
        self.bounds = bounds
        self.safeBounds = safeBounds
        self.exclusionRegions = exclusionRegions
    }
}
