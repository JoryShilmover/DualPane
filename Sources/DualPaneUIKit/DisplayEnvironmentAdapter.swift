// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jory Shilmover
#if canImport(UIKit)
import UIKit
import DualPaneCore

// The fold APIs ship in the iOS 27.1 SDK (UIKit 9127.0.85). Built with an older SDK, the adapter
// reports the safe area only and never observes the hinge.

/// The only module that names iOS 27.1 fold APIs. The solver itself sees plain rectangles.
@MainActor
public enum DisplayEnvironmentAdapter {
    public static func capture(in view: UIView) -> DisplayEnvironment {
        let safe = view.safeAreaLayoutGuide.layoutFrame
        var regions: [ExclusionRegion] = []
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            regions += view.reservedRegions(kind: .division).filter(\.isActive).map {
                ExclusionRegion(frame: $0.frame, kind: .division)
            }
            regions += view.reservedRegions(kind: .occlusion).filter(\.isActive).map {
                ExclusionRegion(frame: $0.frame, kind: .occlusion)
            }
        }
        #endif
        return DisplayEnvironment(bounds: view.bounds, safeBounds: safe, exclusionRegions: regions)
    }

    /// A hinge callback requests a fresh geometry query.
    @discardableResult
    public static func observeHinge(on view: UIView, geometryChanged: @escaping () -> Void) -> UIInteraction? {
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { _, _ in geometryChanged() }
            view.addInteraction(interaction)
            return interaction
        }
        #endif
        return nil
    }
}
#endif
