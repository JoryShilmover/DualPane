// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// Frozen copy of the solver as extracted from Duo DS (ScreenLayoutSolver at 8acef0b). The DS preset of
// the current solver must reproduce these results exactly. Do not edit.

private extension CGRect {
    func legacyEquals(_ other: CGRect) -> Bool {
        minX == other.minX && minY == other.minY && width == other.width && height == other.height
    }
}

enum Legacy {
    struct ExclusionRegion: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case division, occlusion }
        let frame: CGRect
        let kind: Kind
        init(frame: CGRect, kind: Kind) { self.frame = frame; self.kind = kind }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.kind == rhs.kind && lhs.frame.legacyEquals(rhs.frame)
        }
    }

    /// All rectangles use the coordinate system of the view being laid out.
    struct DisplayEnvironment: Equatable, Sendable {
        let bounds: CGRect
        let safeBounds: CGRect
        let exclusionRegions: [ExclusionRegion]
        init(bounds: CGRect, safeBounds: CGRect, exclusionRegions: [ExclusionRegion] = []) {
            self.bounds = bounds
            self.safeBounds = safeBounds
            self.exclusionRegions = exclusionRegions
        }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.bounds.legacyEquals(rhs.bounds) && lhs.safeBounds.legacyEquals(rhs.safeBounds)
                && lhs.exclusionRegions == rhs.exclusionRegions
        }
    }

    enum ScreenLayoutPreference: Equatable, Sendable { case automatic, stacked, sideBySide }
    enum ScreenLayoutMode: Equatable, Sendable { case stacked, sideBySide, split }

    struct LayoutSolution: Equatable, Sendable {
        let upperScreen: CGRect
        let lowerScreen: CGRect
        let effectiveMode: ScreenLayoutMode
        /// Exactly two thumb clusters when non-empty: [left (D-pad side), right (face-button side)].
        let controlRegions: [CGRect]
        let isCompact: Bool
        /// True only in the last-resort fallback where clusters are overlaid on the screens.
        let controlsOverlapScreens: Bool
        init(upperScreen: CGRect, lowerScreen: CGRect, effectiveMode: ScreenLayoutMode,
                    controlRegions: [CGRect], isCompact: Bool, controlsOverlapScreens: Bool = false) {
            self.upperScreen = upperScreen
            self.lowerScreen = lowerScreen
            self.effectiveMode = effectiveMode
            self.controlRegions = controlRegions
            self.isCompact = isCompact
            self.controlsOverlapScreens = controlsOverlapScreens
        }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.upperScreen.legacyEquals(rhs.upperScreen) && lhs.lowerScreen.legacyEquals(rhs.lowerScreen)
                && lhs.effectiveMode == rhs.effectiveMode && lhs.isCompact == rhs.isCompact
                && lhs.controlsOverlapScreens == rhs.controlsOverlapScreens
                && lhs.controlRegions.count == rhs.controlRegions.count
                && zip(lhs.controlRegions, rhs.controlRegions).allSatisfy { $0.legacyEquals($1) }
        }
    }

    enum ScreenLayoutSolver {
        private static let aspect: CGFloat = 4.0 / 3.0
        private static let gutter: CGFloat = 8
        /// Smallest cluster that fits a shoulder pill, a ~100 pt D-pad/face diamond and a row of small pills.
        static let clusterMinimum = CGSize(width: 120, height: 170)
        private static let clusterMaximum = CGSize(width: 220, height: 250)

        /// DS-style thumb clusters either sit in a band below the screens (D-pad bottom-left, face buttons
        /// bottom-right) or flank the screens level with the lower screen, like the DS Lite.
        private enum ControlStyle: Equatable { case none, band(CGFloat), flank(CGFloat) }
        private static let styles: [ControlStyle] = [.band(200), .band(170), .flank(170), .flank(130), .none]

        private struct Candidate {
            let first: CGRect
            let second: CGRect
            let mode: ScreenLayoutMode
            let clusters: [CGRect]
            let score: CGFloat
        }

        static func solve(environment: DisplayEnvironment,
                                 preference: ScreenLayoutPreference = .automatic,
                                 swapScreens: Bool = false) -> LayoutSolution {
            let safe = environment.safeBounds.standardized.intersection(environment.bounds.standardized)
            guard safe.width > 0, safe.height > 0 else {
                return LayoutSolution(upperScreen: CGRect(x: 0, y: 0, width: 0, height: 0),
                                      lowerScreen: CGRect(x: 0, y: 0, width: 0, height: 0),
                                      effectiveMode: .stacked, controlRegions: [], isCompact: true)
            }
            let barriers = environment.exclusionRegions.map { $0.frame.standardized.intersection(safe) }
                .filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
            let free = maximalFreeRects(in: safe, avoiding: barriers)
            var candidates: [Candidate] = []
            for cell in free {
                for mode in [ScreenLayoutMode.stacked, .sideBySide] {
                    if preference == .stacked && mode != .stacked { continue }
                    if preference == .sideBySide && mode != .sideBySide { continue }
                    for style in styles {
                        if let candidate = fitPair(in: cell, mode: mode, style: style) { candidates.append(candidate) }
                    }
                }
            }
            // A division or occlusion may split the usable display into two separate cells.
            if preference == .automatic {
                for i in free.indices {
                    for j in free.indices where j > i {
                        for style in styles {
                            if let candidate = fitSplit(free[i], free[j], safe: safe, style: style) {
                                candidates.append(candidate)
                            }
                        }
                    }
                }
            }
            let selected = candidates.max { $0.score < $1.score }
                ?? Candidate(first: CGRect(x: 0, y: 0, width: 0, height: 0),
                             second: CGRect(x: 0, y: 0, width: 0, height: 0), mode: .stacked, clusters: [], score: 0)
            let top = swapScreens ? selected.second : selected.first
            let bottom = swapScreens ? selected.first : selected.second
            var clusters = selected.clusters
            var overlap = false
            if clusters.isEmpty {
                // Last resort: keep the game controllable by overlaying clusters on the bottom corners.
                let size = CGSize(width: min(clusterMinimum.width, safe.width / 2), height: min(clusterMinimum.height, safe.height))
                clusters = [CGRect(x: safe.minX, y: safe.maxY - size.height, width: size.width, height: size.height),
                            CGRect(x: safe.maxX - size.width, y: safe.maxY - size.height, width: size.width, height: size.height)]
                overlap = true
            }
            return LayoutSolution(upperScreen: top, lowerScreen: bottom,
                                  effectiveMode: selected.mode, controlRegions: clusters,
                                  isCompact: min(top.width, bottom.width) < 170, controlsOverlapScreens: overlap)
        }

        /// Controls outrank larger screens while both screens stay legible (D11); within a tier, the
        /// larger smallest screen wins, then the roomier control style.
        private static func score(minWidth: CGFloat, clusters: [CGRect]) -> CGFloat {
            guard !clusters.isEmpty else { return minWidth }
            let roomy = clusters.map { min($0.width, $0.height) }.min() ?? 0
            return minWidth + (minWidth >= 170 ? 10_000 : 0) + roomy / 100
        }

        private static func fit(_ area: CGRect) -> CGRect {
            guard area.width > 0, area.height > 0 else { return CGRect(x: 0, y: 0, width: 0, height: 0) }
            let width = min(area.width, area.height * aspect)
            let height = width / aspect
            return CGRect(x: area.midX - width / 2, y: area.midY - height / 2,
                          width: width, height: height)
        }

        /// Space left for screens after reserving room for the thumb clusters.
        private static func usable(_ cell: CGRect, _ style: ControlStyle) -> CGRect? {
            switch style {
            case .none: return cell
            case .band(let height):
                guard cell.height > height, cell.width >= clusterMinimum.width * 2 + gutter else { return nil }
                return CGRect(x: cell.minX, y: cell.minY, width: cell.width, height: cell.height - height)
            case .flank(let width):
                guard cell.width > width * 2, cell.height >= clusterMinimum.height else { return nil }
                return CGRect(x: cell.minX + width, y: cell.minY, width: cell.width - width * 2, height: cell.height)
            }
        }

        /// Cluster rectangles for a style, anchored to the touch (lower) screen as on the DS Lite.
        private static func clusters(_ cell: CGRect, _ style: ControlStyle, anchor: CGRect) -> [CGRect] {
            switch style {
            case .none: return []
            case .band(let height):
                let band = CGRect(x: cell.minX, y: cell.maxY - height, width: cell.width, height: height)
                let width = min(clusterMaximum.width, (band.width - gutter) / 2)
                let h = min(clusterMaximum.height, band.height)
                let y = band.midY - h / 2
                return [CGRect(x: band.minX, y: y, width: width, height: h),
                        CGRect(x: band.maxX - width, y: y, width: width, height: h)]
            case .flank(let width):
                let h = min(clusterMaximum.height, cell.height)
                let y = min(max(anchor.midY - h / 2, cell.minY), cell.maxY - h)
                return [CGRect(x: cell.minX, y: y, width: width, height: h),
                        CGRect(x: cell.maxX - width, y: y, width: width, height: h)]
            }
        }

        private static func fitPair(in cell: CGRect, mode: ScreenLayoutMode, style: ControlStyle) -> Candidate? {
            guard let area = usable(cell, style) else { return nil }
            let slots: (CGRect, CGRect)
            switch mode {
            case .stacked:
                guard area.height > gutter else { return nil }
                let height = (area.height - gutter) / 2
                slots = (CGRect(x: area.minX, y: area.minY, width: area.width, height: height),
                         CGRect(x: area.minX, y: area.minY + height + gutter, width: area.width, height: height))
            case .sideBySide:
                guard area.width > gutter else { return nil }
                let width = (area.width - gutter) / 2
                slots = (CGRect(x: area.minX, y: area.minY, width: width, height: area.height),
                         CGRect(x: area.minX + width + gutter, y: area.minY, width: width, height: area.height))
            case .split: return nil
            }
            var first = fit(slots.0), second = fit(slots.1)
            guard first.width > 0, second.width > 0 else { return nil }
            if case .band = style {
                // Sit screens directly above the band so the thumbs stay close to the touch screen.
                let drop = area.maxY - max(first.maxY, second.maxY)
                first = first.offsetBy(dx: 0, dy: drop); second = second.offsetBy(dx: 0, dy: drop)
            }
            let found = clusters(cell, style, anchor: second)
            return Candidate(first: first, second: second, mode: mode, clusters: found,
                             score: score(minWidth: min(first.width, second.width), clusters: found))
        }

        private static func fitSplit(_ a: CGRect, _ b: CGRect, safe: CGRect, style: ControlStyle) -> Candidate? {
            let horizontal = abs(a.midX - b.midX) > abs(a.midY - b.midY)
            let (firstCell, secondCell) = horizontal
                ? (a.midX < b.midX ? a : b, a.midX < b.midX ? b : a)
                : (a.midY < b.midY ? a : b, a.midY < b.midY ? b : a)
            // The lower or trailing pane hosts the touch screen and the controls.
            guard let secondArea = usable(secondCell, style) else { return nil }
            let first = fit(firstCell)
            var second = fit(secondArea)
            if case .band = style { second = second.offsetBy(dx: 0, dy: secondArea.maxY - second.maxY) }
            guard first.width > 0, second.width > 0, !first.intersects(second) else { return nil }
            let separated = horizontal ? first.maxX <= second.minX : first.maxY <= second.minY
            guard separated else { return nil }
            let minWidth = min(first.width, second.width)
            // A split should win automatically only if each screen remains legible.
            guard minWidth >= min(170, safe.width * 0.38) else { return nil }
            let found = clusters(secondCell, style, anchor: second)
            return Candidate(first: first, second: second, mode: .split, clusters: found,
                             score: score(minWidth: minWidth, clusters: found) + 1) // split wins ties
        }

        private static func maximalFreeRects(in safe: CGRect, avoiding barriers: [CGRect]) -> [CGRect] {
            let xs = Array(Set(([safe.minX, safe.maxX] + barriers.flatMap { [$0.minX, $0.maxX] }))).sorted()
            let ys = Array(Set(([safe.minY, safe.maxY] + barriers.flatMap { [$0.minY, $0.maxY] }))).sorted()
            var result: [CGRect] = []
            for left in 0..<(xs.count - 1) {
                for right in (left + 1)..<xs.count {
                    for top in 0..<(ys.count - 1) {
                        for bottom in (top + 1)..<ys.count {
                            let rect = CGRect(x: xs[left], y: ys[top], width: xs[right] - xs[left], height: ys[bottom] - ys[top])
                            guard rect.width > 0, rect.height > 0,
                                  !barriers.contains(where: { $0.intersects(rect) }) else { continue }
                            result.append(rect)
                        }
                    }
                }
            }
            return result.filter { rect in
                !result.contains { other in !other.legacyEquals(rect) && other.contains(rect) }
            }
        }
    }
}
