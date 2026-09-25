// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum DualPaneSolver {
    /// Accessory regions either sit in a band below the panes (one at each end) or flank the panes level
    /// with the secondary pane. `.none` leaves them out.
    private enum Style: Equatable { case none, band(CGFloat), flank(CGFloat) }

    private struct Candidate {
        let first: CGRect
        let second: CGRect
        let arrangement: PaneArrangement
        let accessories: [CGRect]
        let score: CGFloat
    }

    /// The solver works in two slots: the first (upper or leading) and the second (lower or trailing).
    /// Accessory regions follow the second slot. `swapPanes` puts the primary pane in the second slot.
    private struct Context {
        let configuration: DualPaneConfiguration
        let firstSizing: PaneSizing
        let secondSizing: PaneSizing
        var gutter: CGFloat { configuration.gutter }
        var accessories: AccessoryConfiguration? { configuration.accessories }
    }

    public static func solve(environment: DisplayEnvironment,
                             configuration: DualPaneConfiguration = DualPaneConfiguration(),
                             preference: ArrangementPreference = .automatic,
                             swapPanes: Bool = false) -> LayoutSolution {
        let safe = environment.safeBounds.standardized.intersection(environment.bounds.standardized)
        guard safe.width > 0, safe.height > 0 else {
            return LayoutSolution(primaryPane: CGRect(x: 0, y: 0, width: 0, height: 0),
                                  secondaryPane: CGRect(x: 0, y: 0, width: 0, height: 0),
                                  arrangement: .stacked, accessoryRegions: [], isCompact: true)
        }
        let context = Context(configuration: configuration,
                              firstSizing: swapPanes ? configuration.secondarySizing : configuration.primarySizing,
                              secondSizing: swapPanes ? configuration.primarySizing : configuration.secondarySizing)
        let styles = (configuration.accessories?.styles ?? []).map { style -> Style in
            switch style {
            case .band(let height): return .band(height)
            case .flank(let width): return .flank(width)
            }
        } + [.none]
        let barriers = environment.exclusionRegions.map { $0.frame.standardized.intersection(safe) }
            .filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        let free = maximalFreeRects(in: safe, avoiding: barriers)
        var candidates: [Candidate] = []
        for cell in free {
            for arrangement in [PaneArrangement.stacked, .sideBySide] {
                if preference == .stacked && arrangement != .stacked { continue }
                if preference == .sideBySide && arrangement != .sideBySide { continue }
                for style in styles {
                    if let candidate = fitPair(in: cell, arrangement: arrangement, style: style, context) {
                        candidates.append(candidate)
                    }
                }
            }
        }
        // A division or occlusion may split the usable display into two separate cells.
        if preference == .automatic {
            for i in free.indices {
                for j in free.indices where j > i {
                    for style in styles {
                        if let candidate = fitSplit(free[i], free[j], safe: safe, style: style, context) {
                            candidates.append(candidate)
                        }
                    }
                }
            }
        }
        let selected = candidates.max { $0.score < $1.score }
            ?? Candidate(first: CGRect(x: 0, y: 0, width: 0, height: 0),
                         second: CGRect(x: 0, y: 0, width: 0, height: 0),
                         arrangement: .stacked, accessories: [], score: 0)
        var accessories = selected.accessories
        var overlap = false
        if accessories.isEmpty, let config = configuration.accessories {
            // Last resort: keep the accessories reachable by overlaying them on the bottom corners.
            let size = CGSize(width: min(config.minimumSize.width, safe.width / 2),
                              height: min(config.minimumSize.height, safe.height))
            accessories = [CGRect(x: safe.minX, y: safe.maxY - size.height, width: size.width, height: size.height),
                           CGRect(x: safe.maxX - size.width, y: safe.maxY - size.height,
                                  width: size.width, height: size.height)]
            overlap = true
        }
        let smallest = min(measure(selected.first, configuration), measure(selected.second, configuration))
        return LayoutSolution(primaryPane: swapPanes ? selected.second : selected.first,
                              secondaryPane: swapPanes ? selected.first : selected.second,
                              arrangement: selected.arrangement, accessoryRegions: accessories,
                              isCompact: smallest < configuration.minimumLegibleSize,
                              accessoriesOverlapPanes: overlap)
    }

    private static func measure(_ pane: CGRect, _ configuration: DualPaneConfiguration) -> CGFloat {
        switch configuration.measure {
        case .width: return pane.width
        case .shortSide: return min(pane.width, pane.height)
        }
    }

    /// Accessories outrank larger panes while both panes stay legible; within a tier, the larger
    /// smallest pane wins, then the roomier accessory style.
    private static func score(first: CGRect, second: CGRect, accessories: [CGRect], _ context: Context) -> CGFloat {
        let smallest = min(measure(first, context.configuration), measure(second, context.configuration))
        guard !accessories.isEmpty else { return smallest }
        let roomy = accessories.map { min($0.width, $0.height) }.min() ?? 0
        return smallest + (smallest >= context.configuration.minimumLegibleSize ? 10_000 : 0) + roomy / 100
    }

    private static func fit(_ area: CGRect, _ sizing: PaneSizing) -> CGRect {
        guard area.width > 0, area.height > 0 else { return CGRect(x: 0, y: 0, width: 0, height: 0) }
        switch sizing {
        case .fill:
            return area
        case .aspectRatio(let aspect):
            let width = min(area.width, area.height * aspect)
            let height = width / aspect
            return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
        }
    }

    /// Space left for panes after reserving room for the accessories.
    private static func usable(_ cell: CGRect, _ style: Style, _ context: Context) -> CGRect? {
        guard let minimum = context.accessories?.minimumSize else { return style == .none ? cell : nil }
        switch style {
        case .none: return cell
        case .band(let height):
            guard cell.height > height, cell.width >= minimum.width * 2 + context.gutter else { return nil }
            return CGRect(x: cell.minX, y: cell.minY, width: cell.width, height: cell.height - height)
        case .flank(let width):
            guard cell.width > width * 2, cell.height >= minimum.height else { return nil }
            return CGRect(x: cell.minX + width, y: cell.minY, width: cell.width - width * 2, height: cell.height)
        }
    }

    /// Accessory rectangles for a style, anchored to the pane in the second slot.
    private static func accessories(_ cell: CGRect, _ style: Style, anchor: CGRect, _ context: Context) -> [CGRect] {
        guard let maximum = context.accessories?.maximumSize else { return [] }
        switch style {
        case .none: return []
        case .band(let height):
            let band = CGRect(x: cell.minX, y: cell.maxY - height, width: cell.width, height: height)
            let width = min(maximum.width, (band.width - context.gutter) / 2)
            let h = min(maximum.height, band.height)
            let y = band.midY - h / 2
            return [CGRect(x: band.minX, y: y, width: width, height: h),
                    CGRect(x: band.maxX - width, y: y, width: width, height: h)]
        case .flank(let width):
            let h = min(maximum.height, cell.height)
            let y = min(max(anchor.midY - h / 2, cell.minY), cell.maxY - h)
            return [CGRect(x: cell.minX, y: y, width: width, height: h),
                    CGRect(x: cell.maxX - width, y: y, width: width, height: h)]
        }
    }

    private static func fitPair(in cell: CGRect, arrangement: PaneArrangement, style: Style,
                                _ context: Context) -> Candidate? {
        guard let area = usable(cell, style, context) else { return nil }
        let gutter = context.gutter
        let slots: (CGRect, CGRect)
        switch arrangement {
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
        var first = fit(slots.0, context.firstSizing), second = fit(slots.1, context.secondSizing)
        guard first.width > 0, second.width > 0 else { return nil }
        if case .band = style {
            // Sit panes directly above the band so thumbs stay close to the secondary pane.
            let drop = area.maxY - max(first.maxY, second.maxY)
            first = first.offsetBy(dx: 0, dy: drop); second = second.offsetBy(dx: 0, dy: drop)
        }
        let found = accessories(cell, style, anchor: second, context)
        return Candidate(first: first, second: second, arrangement: arrangement, accessories: found,
                         score: score(first: first, second: second, accessories: found, context))
    }

    private static func fitSplit(_ a: CGRect, _ b: CGRect, safe: CGRect, style: Style,
                                 _ context: Context) -> Candidate? {
        let horizontal = abs(a.midX - b.midX) > abs(a.midY - b.midY)
        let (firstCell, secondCell) = horizontal
            ? (a.midX < b.midX ? a : b, a.midX < b.midX ? b : a)
            : (a.midY < b.midY ? a : b, a.midY < b.midY ? b : a)
        // The lower or trailing cell hosts the second slot and the accessories.
        guard let secondArea = usable(secondCell, style, context) else { return nil }
        let first = fit(firstCell, context.firstSizing)
        var second = fit(secondArea, context.secondSizing)
        if case .band = style { second = second.offsetBy(dx: 0, dy: secondArea.maxY - second.maxY) }
        guard first.width > 0, second.width > 0, !first.overlaps(second) else { return nil }
        let separated = horizontal ? first.maxX <= second.minX : first.maxY <= second.minY
        guard separated else { return nil }
        let smallest = min(measure(first, context.configuration), measure(second, context.configuration))
        // A split should win automatically only if each pane remains legible.
        guard smallest >= min(context.configuration.minimumLegibleSize, safe.width * 0.38) else { return nil }
        let found = accessories(secondCell, style, anchor: second, context)
        return Candidate(first: first, second: second, arrangement: .split, accessories: found,
                         score: score(first: first, second: second, accessories: found, context) + 1) // split wins ties
    }

    private static func maximalFreeRects(in safe: CGRect, avoiding barriers: [CGRect]) -> [CGRect] {
        let xs = Array(Set(([safe.minX, safe.maxX] + barriers.flatMap { [$0.minX, $0.maxX] }))).sorted()
        let ys = Array(Set(([safe.minY, safe.maxY] + barriers.flatMap { [$0.minY, $0.maxY] }))).sorted()
        var result: [CGRect] = []
        for left in 0..<(xs.count - 1) {
            for right in (left + 1)..<xs.count {
                for top in 0..<(ys.count - 1) {
                    for bottom in (top + 1)..<ys.count {
                        let rect = CGRect(x: xs[left], y: ys[top], width: xs[right] - xs[left],
                                          height: ys[bottom] - ys[top])
                        guard rect.width > 0, rect.height > 0,
                              !barriers.contains(where: { $0.overlaps(rect) }) else { continue }
                        result.append(rect)
                    }
                }
            }
        }
        return result.filter { rect in !result.contains { other in other != rect && other.encloses(rect) } }
    }
}
