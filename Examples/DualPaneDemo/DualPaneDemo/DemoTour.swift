// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import CoreGraphics
import Foundation
import SwiftUI

/// Scripted, looping animations for recording the README GIFs. Start one with `-tour <name>`.
enum DemoTour: String, CaseIterable {
    /// DS preset on the Duo's inner display, with the fold moving a little around the centre. Much further and
    /// the solver stacks both screens on the larger side, which a real Duo never needs.
    case fold
    /// Plain panes on an iPad-sized display, with a vertical hinge moving around the centre.
    case hinge
    /// Plain panes on a display that narrows and widens, flipping between side by side and stacked.
    case resize

    /// Seconds for one full loop.
    static let period: Double = 8

    @MainActor
    func setUp(_ model: DemoModel) {
        model.showsOutlines = true
        model.animatesArrangementChanges = false
        switch self {
        case .fold:
            model.configurationPreset = .ds
            model.displayPreset = .duoInnerPortrait
            model.showsHinge = true
            model.hingeOrientation = .horizontal
            model.hingeThickness = 24
        case .hinge:
            model.configurationPreset = .plain
            model.displayPreset = .iPadLandscape
            model.showsHinge = true
            model.hingeOrientation = .vertical
            model.hingeThickness = 24
        case .resize:
            model.configurationPreset = .plain
            model.sizeOverride = CGSize(width: 780, height: 560)
        }
    }

    /// Applies the state at `time` seconds into the tour.
    @MainActor
    func step(_ model: DemoModel, time: Double) {
        // Eases 0 → 1 → 0 over one period.
        let phase = CGFloat((1 - cos(2 * .pi * time / Self.period)) / 2)
        switch self {
        // Hinge sweeps stay near the centre: further out, one side gets too small and the solver puts both
        // panes on the other side, leaving the small side empty.
        case .fold: model.hingePosition = 0.5 + 0.08 * (phase * 2 - 1)
        case .hinge: model.hingePosition = 0.5 + 0.1 * (phase * 2 - 1)
        case .resize: model.sizeOverride = CGSize(width: 780 - 400 * phase, height: 560)
        }
    }
}

/// Full-screen stage for a tour: the simulated display centred in a fixed frame, with no other UI, so
/// recordings can be cropped to a known rectangle.
struct TourStage: View {
    let model: DemoModel
    let tour: DemoTour

    static let size = CGSize(width: 800, height: 700)

    var body: some View {
        SimulatedDisplayView(model: model)
            .frame(width: Self.size.width, height: Self.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .ignoresSafeArea()
            .task {
                tour.setUp(model)
                let start = Date()
                while !Task.isCancelled {
                    tour.step(model, time: Date().timeIntervalSince(start))
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
    }
}
