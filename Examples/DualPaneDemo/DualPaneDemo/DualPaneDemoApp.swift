// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import SwiftUI

@main
struct DualPaneDemoApp: App {
    @State private var model: DemoModel = {
        let model = DemoModel()
        model.applyLaunchArguments()
        return model
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
