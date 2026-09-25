// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// The solver's rectangle tests, spelled out rather than taken from CGRect: CoreGraphics does not count
// rectangles that only share an edge as intersecting, but swift-corelibs-foundation (Linux) does. Panes
// routinely sit edge to edge with a hinge, so the difference changes layouts.
extension CGRect {
    /// True when the two rectangles share interior area. Touching edges do not count.
    func overlaps(_ other: CGRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    /// True when `other` lies entirely within this rectangle, edges included.
    func encloses(_ other: CGRect) -> Bool {
        minX <= other.minX && other.maxX <= maxX && minY <= other.minY && other.maxY <= maxY
    }
}
