// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
#if os(iOS)
import DualPaneCore
import DualPaneUIKit
import SwiftUI
import UIKit

/// Lays out this device's real display: safe area, plus fold regions and hinge changes on iOS 27.1.
struct LiveDisplayView: View {
    let model: DemoModel
    @Environment(\.dismiss) private var dismiss
    @State private var environment: DisplayEnvironment?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topLeading) {
                EnvironmentProbe { environment = $0 }
                if let environment {
                    let solution = model.solve(environment)
                    SamplePane(role: .primary, preset: model.configurationPreset).placed(in: solution.primaryPane)
                    SamplePane(role: .secondary, preset: model.configurationPreset).placed(in: solution.secondaryPane)
                    ForEach(Array(solution.accessoryRegions.enumerated()), id: \.offset) { index, region in
                        AccessoryMock(isLeading: index == 0, overlapsPanes: solution.accessoriesOverlapPanes)
                            .placed(in: region)
                    }
                    ForEach(Array(environment.exclusionRegions.enumerated()), id: \.offset) { _, region in
                        Rectangle().fill(.red.opacity(0.35)).placed(in: region.frame)
                    }
                    if model.showsOutlines { SolutionOverlay(solution: solution) }
                }
            }
            .ignoresSafeArea()
            .animation(.snappy, value: environment.map { model.solve($0).arrangement })

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

/// Reports the display environment whenever layout, safe area or hinge state changes.
private struct EnvironmentProbe: UIViewRepresentable {
    let onChange: (DisplayEnvironment) -> Void

    func makeUIView(context: Context) -> ProbeView { ProbeView() }

    func updateUIView(_ view: ProbeView, context: Context) { view.onChange = onChange }

    final class ProbeView: UIView {
        var onChange: (DisplayEnvironment) -> Void = { _ in }
        private var last: DisplayEnvironment?
        private var hinge: UIInteraction?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil, hinge == nil {
                hinge = DisplayEnvironmentAdapter.observeHinge(on: self) { [weak self] in self?.report() }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        private func report() {
            let environment = DisplayEnvironmentAdapter.capture(in: self)
            guard environment != last else { return }
            last = environment
            // Defer so SwiftUI state is not changed during a view update.
            Task { @MainActor [onChange] in onChange(environment) }
        }
    }
}
#endif
