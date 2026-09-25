// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import DualPaneCore
import SwiftUI

struct ControlsForm: View {
    @Bindable var model: DemoModel

    var body: some View {
        Form {
            Section {
                Picker("Size", selection: $model.displayPreset) {
                    ForEach(DisplayPreset.allCases) { Text($0.rawValue).tag($0) }
                }
            } header: {
                Text("Display")
            } footer: {
                if model.displayPreset == .freeform {
                    Text("Fills the space available. Resize the window to watch the solver react.")
                }
            }

            Section {
                Toggle("Hinge", isOn: $model.showsHinge.animation())
                if model.showsHinge {
                    Picker("Orientation", selection: $model.hingeOrientation) {
                        ForEach(HingeOrientation.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledSlider("Thickness", value: $model.hingeThickness, in: 2...80)
                }
                Toggle("Camera housing", isOn: $model.showsCamera.animation())
            } header: {
                Text("Exclusion regions")
            } footer: {
                if model.showsHinge || model.showsCamera {
                    Text("Drag the hinge or camera on the display to move it.")
                }
            }

            Section("Configuration") {
                Picker("Preset", selection: $model.configurationPreset) {
                    ForEach(ConfigurationPreset.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Primary pane", selection: sizing(\.primarySizing)) {
                    ForEach(SizingOption.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Secondary pane", selection: sizing(\.secondarySizing)) {
                    ForEach(SizingOption.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Measure", selection: $model.configuration.measure) {
                    Text("Width").tag(PaneMeasure.width)
                    Text("Short side").tag(PaneMeasure.shortSide)
                }
                LabeledSlider("Gutter", value: $model.configuration.gutter, in: 0...48)
                LabeledSlider("Legible size", value: $model.configuration.minimumLegibleSize, in: 60...400)
            }

            Section("Solve") {
                Picker("Arrangement", selection: $model.preference) {
                    Text("Auto").tag(ArrangementPreference.automatic)
                    Text("Stacked").tag(ArrangementPreference.stacked)
                    Text("Side by side").tag(ArrangementPreference.sideBySide)
                }
                Toggle("Swap panes", isOn: $model.swapPanes)
            }

            Section("Overlay") {
                Toggle("Outlines and labels", isOn: $model.showsOutlines)
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: model.configuration)
    }

    private func sizing(_ keyPath: WritableKeyPath<DualPaneConfiguration, PaneSizing>) -> Binding<SizingOption> {
        Binding(get: { SizingOption(model.configuration[keyPath: keyPath]) },
                set: { model.configuration[keyPath: keyPath] = $0.sizing })
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    init(_ title: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        LabeledContent {
            Slider(value: $value, in: range, step: 1)
        } label: {
            Text(title)
            Text("\(Int(value)) pt").monospacedDigit()
        }
    }
}
