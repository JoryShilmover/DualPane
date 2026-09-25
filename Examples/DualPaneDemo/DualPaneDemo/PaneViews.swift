// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import DualPaneCore
import SwiftUI

enum PaneRole { case primary, secondary }

/// Stand-in content for a pane.
struct SamplePane: View {
    let role: PaneRole
    let preset: ConfigurationPreset

    var body: some View {
        let color: Color = role == .primary ? .blue : .purple
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.gradient.opacity(0.28))
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(color)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .minimumScaleFactor(0.5)
        }
    }

    private var title: String {
        switch (preset, role) {
        case (.plain, .primary): "Library"
        case (.plain, .secondary): "Detail"
        case (.ds, .primary): "Top screen"
        case (.ds, .secondary): "Touch screen"
        }
    }

    private var subtitle: String { role == .primary ? "Primary pane" : "Secondary pane" }

    private var symbol: String {
        switch (preset, role) {
        case (.plain, .primary): "list.bullet.rectangle"
        case (.plain, .secondary): "doc.richtext"
        case (.ds, .primary): "sparkles.tv"
        case (.ds, .secondary): "hand.tap"
        }
    }
}

/// Stand-in for on-screen controls in an accessory region.
struct AccessoryMock: View {
    let isLeading: Bool
    let overlapsPanes: Bool

    var body: some View {
        let color: Color = overlapsPanes ? .red : .orange
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.opacity(0.12))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            Image(systemName: isLeading ? "dpad" : "circle.grid.cross")
                .font(.system(size: 44))
                .foregroundStyle(color)
        }
    }
}

/// Outlines and size labels for the solver's panes.
struct SolutionOverlay: View {
    let solution: LayoutSolution

    var body: some View {
        ZStack(alignment: .topLeading) {
            outline(solution.primaryPane, label: "Primary", color: .blue)
            outline(solution.secondaryPane, label: "Secondary", color: .purple)
        }
        .allowsHitTesting(false)
    }

    private func outline(_ rect: CGRect, label: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(color, lineWidth: 2)
            .overlay(alignment: .topLeading) {
                Text("\(label) \(rect.size.pointsDescription)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
            .placed(in: rect)
    }
}

extension View {
    /// Places the view at `rect` inside a top-leading aligned ZStack.
    func placed(in rect: CGRect) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0)).offset(x: rect.minX, y: rect.minY)
    }
}

extension CGSize {
    var pointsDescription: String { "\(Int(width.rounded()))×\(Int(height.rounded()))" }
}

extension PaneArrangement {
    var title: String {
        switch self {
        case .stacked: "Stacked"
        case .sideBySide: "Side by side"
        case .split: "Split across the hinge"
        }
    }
}
