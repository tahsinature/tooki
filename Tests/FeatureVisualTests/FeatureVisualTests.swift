import AppKit
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import Testing
import TookiDesignSystem
@testable import Tooki

@MainActor
@Suite(.serialized)
struct FeatureVisualTests {
    @Test(arguments: VisualScenario.allCases)
    func panelStates(_ scenario: VisualScenario) async throws {
        _ = NSApplication.shared
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let fixtures = try VisualFixtures()
            defer { fixtures.cleanUp() }
            let content = withDependencies {
                $0.uuid = .incrementing
                $0.date.now = fixtures.now
            } operation: {
                fixtures.view(for: scenario)
            }
            let hosting = NSHostingView(rootView: content
                .environment(\.colorScheme, appearance == .aqua ? .light : .dark)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.controlActiveState, .key))
            hosting.appearance = NSAppearance(named: appearance)
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: scenario.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            // Keep desktop pointer movement and clicks out of deterministic, unhovered fixtures.
            window.ignoresMouseEvents = true
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            window.backgroundColor = NSColor.windowBackgroundColor
            window.contentView = hosting
            window.orderFront(nil)
            defer { window.orderOut(nil) }
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            if scenario == .conversionReview {
                try await waitForPreview(in: hosting)
            }
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            hosting.displayIfNeeded()
            assertSnapshot(of: hosting, as: .image, named: "\(scenario.rawValue)-\(appearance.rawValue)-\(Int(window.backingScaleFactor))x")
        }
    }

    /// Wait for actual image readiness rather than recording a spinner or sleeping a fixed interval.
    private func waitForPreview(in view: NSView) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while hasLoadingIndicator(view) {
            guard ContinuousClock.now < deadline else {
                Issue.record("Conversion preview did not finish loading before snapshot")
                throw PreviewTimeout()
            }
            await Task.yield()
            view.layoutSubtreeIfNeeded()
        }
    }

    private func hasLoadingIndicator(_ view: NSView) -> Bool {
        view is NSProgressIndicator || view.subviews.contains { hasLoadingIndicator($0) }
    }

    private struct PreviewTimeout: Error {}
}
