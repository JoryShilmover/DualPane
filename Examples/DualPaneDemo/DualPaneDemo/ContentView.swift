// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
import SwiftUI

struct ContentView: View {
    @Bindable var model: DemoModel
    @State private var showsControls = true
    #if os(iOS)
    @State private var showsLiveMode = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Regular widths (iPad, Mac) show the controls in a side panel; compact widths (iPhone) in a panel
    /// under the display, so the display always stays visible.
    private var usesSidePanel: Bool {
        #if os(iOS)
        horizontalSizeClass != .compact
        #else
        true
        #endif
    }

    var body: some View {
        if let tour = model.tour {
            TourStage(model: model, tour: tour)
        } else {
            interactive
        }
    }

    private var interactive: some View {
        NavigationStack {
            GeometryReader { proxy in
                if usesSidePanel {
                    HStack(spacing: 0) {
                        SimulatedDisplayView(model: model).padding()
                        if showsControls {
                            Divider()
                            ControlsForm(model: model)
                                .frame(width: 320)
                                .transition(.move(edge: .trailing))
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        SimulatedDisplayView(model: model).padding()
                        if showsControls {
                            Divider()
                            ControlsForm(model: model)
                                .frame(height: proxy.size.height * 0.45)
                                .transition(.move(edge: .bottom))
                        }
                    }
                }
            }
            .navigationTitle("DualPane")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Live", systemImage: "iphone.gen3") { showsLiveMode = true }
                        .help("Lay out this device's real display, including fold regions on iOS 27.1")
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button("Controls", systemImage: "slider.horizontal.3") {
                        withAnimation { showsControls.toggle() }
                    }
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsLiveMode) {
            LiveDisplayView(model: model)
        }
        #endif
    }
}
