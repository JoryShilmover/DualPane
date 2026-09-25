// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// Platform-independent rectangle checks for expectations. CGRect.intersects counts shared edges as an
// intersection on Linux but not on Apple platforms, and panes legitimately touch hinges and each other.
extension CGRect {
    func sharesArea(with other: CGRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    func surrounds(_ other: CGRect) -> Bool {
        minX <= other.minX && other.maxX <= maxX && minY <= other.minY && other.maxY <= maxY
    }
}
