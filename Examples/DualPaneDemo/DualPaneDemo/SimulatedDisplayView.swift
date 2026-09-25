// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import DualPaneCore
import DualPaneSwiftUI
import SwiftUI

/// A pretend display, scaled to fit, with draggable exclusion regions.
struct SimulatedDisplayView: View {
    @Bindable var model: DemoModel

    var body: some View {
        GeometryReader { proxy in
            let available = CGSize(width: proxy.size.width, height: max(1, proxy.size.height - 56))
            let size = model.sizeOverride ?? model.displayPreset.size ?? available
            let scale = min(1, available.width / size.width, available.height / size.height)
            let solution = model.solve(model.environment(for: size))
            VStack(spacing: 16) {
                DisplayCanvas(model: model, size: size, solution: solution)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .frame(width: size.width * scale, height: size.height * scale)
                StatusLine(solution: solution, size: size, scale: scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DisplayCanvas: View {
    @Bindable var model: DemoModel
    let size: CGSize
    let solution: LayoutSolution

    private static let space = "display"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.background.secondary)

            // Pane content is placed by the SwiftUI layout, and the size labels come from the solver.
            // They agree because DualPaneLayout runs the same solve. Outlines ride on the content so the
            // two move together when a layout change animates.
            DualPaneLayout(configuration: model.configuration, preference: model.preference,
                           swapPanes: model.swapPanes, exclusionRegions: model.exclusionRegions(in: size)) {
                SamplePane(role: .primary, preset: model.configurationPreset)
                    .overlay { if model.showsOutlines { PaneOutline.primary(solution) } }
                SamplePane(role: .secondary, preset: model.configurationPreset)
                    .overlay { if model.showsOutlines { PaneOutline.secondary(solution) } }
            }

            ForEach(Array(solution.accessoryRegions.enumerated()), id: \.offset) { index, region in
                AccessoryMock(isLeading: index == 0, overlapsPanes: solution.accessoriesOverlapPanes)
                    .placed(in: region)
            }

            if model.showsHinge { hinge }
            if model.showsCamera { camera }

        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.separator, lineWidth: 2))
        .coordinateSpace(.named(Self.space))
        // Animate only arrangement flips; continuous changes (dragging, resizing) track the solver exactly.
        .animation(model.animatesArrangementChanges ? .snappy : nil, value: solution.arrangement)
    }

    private var hinge: some View {
        let frame = model.hingeFrame(in: size)
        return Rectangle()
            .fill(.black.opacity(0.8))
            .overlay(Rectangle().stroke(.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .placed(in: frame)
            .contentShape(Rectangle().inset(by: -14))
            .gesture(DragGesture(coordinateSpace: .named(Self.space)).onChanged { drag in
                let fraction = model.hingeOrientation == .vertical
                    ? drag.location.x / size.width : drag.location.y / size.height
                model.hingePosition = min(max(fraction, 0.05), 0.95)
            })
            .help("Drag to move the hinge")
    }

    private var camera: some View {
        Capsule()
            .fill(.black)
            .overlay(Circle().fill(.gray.opacity(0.5)).padding(12))
            .placed(in: model.cameraFrame(in: size))
            .gesture(DragGesture(coordinateSpace: .named(Self.space)).onChanged { drag in
                model.cameraCenter = CGPoint(x: min(max(drag.location.x / size.width, 0), 1),
                                             y: min(max(drag.location.y / size.height, 0), 1))
            })
            .help("Drag to move the camera housing")
    }
}

private struct StatusLine: View {
    let solution: LayoutSolution
    let size: CGSize
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(solution.arrangement.title).fontWeight(.semibold)
                if solution.isCompact { Badge(text: "Compact", color: .orange) }
                if solution.accessoriesOverlapPanes { Badge(text: "Accessories overlap", color: .red) }
            }
            Text("Display \(size.pointsDescription)  ·  primary \(solution.primaryPane.size.pointsDescription)"
                 + "  ·  secondary \(solution.secondaryPane.size.pointsDescription)"
                 + (scale < 1 ? "  ·  shown at \(Int((scale * 100).rounded()))%" : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}
