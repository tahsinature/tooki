import TookiDesignSystem
import AppKit
import SwiftUI
import Testing
@testable import Tooki

extension PanelRestorationTests {
    @Test func keyboardRevealsHeadersAndPaddingAtBothEdges() async throws {
        _ = NSApplication.shared
        let navigation = PanelKeyboardNavigation()
        let state = ScrollEdgeTestState()
        let hosting = NSHostingView(rootView: ScrollEdgeTestView(state: state, navigation: navigation))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 260, height: 160),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        await settleScroll()
        let scroll = try #require(findScrollView(in: hosting))

        state.selection = 19
        await settleScroll()
        // Content margins sit outside the document bounds.
        #expect(abs(scroll.documentVisibleRect.maxY - (scroll.documentView?.bounds.maxY ?? 0) - 8) < 2)
        state.selection = 0
        await settleScroll()
        #expect(abs(scroll.documentVisibleRect.minY + 8) < 2)

        // Scrolling away with the pointer does not change selection. Another Up must restore the edge.
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 150))
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(scroll.documentVisibleRect.minY > 100)
        navigation.moved(in: .results)
        await settleScroll()
        #expect(abs(scroll.documentVisibleRect.minY + 8) < 2)
        #expect(navigation.resultsPageSize == 4)
    }

    @Test func actionsPopupPreservesItsTitleAndBottomPadding() async throws {
        _ = NSApplication.shared
        let navigation = PanelKeyboardNavigation()
        let state = ScrollEdgeTestState()
        let hosting = NSHostingView(rootView: ScrollActionTestView(state: state, navigation: navigation))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 350, height: 244),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        await settleScroll()
        let scroll = try #require(findScrollView(in: hosting))
        state.selection = 19
        await settleScroll()
        #expect(abs(scroll.documentVisibleRect.maxY - (scroll.documentView?.bounds.maxY ?? 0) - 8) < 2)
        state.selection = 0
        await settleScroll()
        #expect(abs(scroll.documentVisibleRect.minY + 8) < 2)
        #expect(navigation.actionsPageSize == 5)
        #expect(navigation.resultsRevision == 0)
    }

    @Test func jumpingAcrossLongGroupedListRealizesTheSelectedRow() async throws {
        _ = NSApplication.shared
        let state = LongScrollTestState()
        let navigation = PanelKeyboardNavigation()
        let hosting = NSHostingView(rootView: LongScrollTestView(state: state, navigation: navigation))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 384),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        await settleScroll()

        for _ in 0..<3 {
            state.selection = 999
            navigation.moved(in: .results)
            await settleScroll()
            let frame = try #require(state.frames[999], "The selected final row must be laid out after the jump")
            #expect(frame.minY >= -1 && abs(frame.maxY - 376) < 2,
                    "The final row must render inside the viewport with 8pt below it: \(frame)")
            state.selection = 0
            navigation.moved(in: .results)
            await settleScroll()
            let firstFrame = try #require(state.frames[0])
            #expect(abs(firstFrame.minY - 32) < 2, "The first heading and 8pt top margin must remain visible")
        }
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }

    private func settleScroll() async {
        try? await Task.sleep(for: .milliseconds(150))
    }
}

@MainActor @Observable
private final class ScrollEdgeTestState {
    var selection = 0
}

private struct ScrollEdgeTestView: View {
    let state: ScrollEdgeTestState
    let navigation: PanelKeyboardNavigation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    SectionHeader(title: "Recent", isFirst: true)
                    ForEach(0..<20) { index in
                        Text("Row \(index)").frame(height: 38).id(index)
                    }
                }
                .padding(.horizontal, 8)
                .panelScrollContent()
            }
            .panelSelectionScrolling(proxy: proxy, selection: state.selection, first: 0, last: 19)
        }
        .environment(\.panelKeyboardNavigation, navigation)
    }
}

private struct ScrollActionTestView: View {
    let state: ScrollEdgeTestState
    let navigation: PanelKeyboardNavigation

    var body: some View {
        ActionsPopup(
            title: "Selected item",
            actions: (0..<20).map { SearchAction(id: String($0), title: "Action \($0)", icon: .symbol("star"), shortcut: "", run: {}) },
            selection: state.selection,
            query: .constant(""), searchPrompt: "Search for actions…",
            onKey: { _ in .ignored }, onRun: { _ in }
        )
        .environment(\.panelKeyboardNavigation, navigation)
    }
}

@MainActor @Observable
private final class LongScrollTestState {
    var selection = 0
    var frames: [Int: CGRect] = [:]
}

private struct LongScrollTestView: View {
    let state: LongScrollTestState
    let navigation: PanelKeyboardNavigation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<10) { section in
                        SectionHeader(title: "Section \(section)", isFirst: section == 0)
                        ForEach((section * 100)..<((section + 1) * 100), id: \.self) { index in
                            Text("Row \(index)")
                                .frame(height: index.isMultiple(of: 17) ? 80 : 38)
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("viewport")) } action: {
                                    state.frames[index] = $0
                                }
                                .id(index)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .panelScrollContent()
            }
            .coordinateSpace(name: "viewport")
            .panelSelectionScrolling(proxy: proxy, selection: state.selection, first: 0, last: 999)
        }
        .environment(\.panelKeyboardNavigation, navigation)
    }
}
