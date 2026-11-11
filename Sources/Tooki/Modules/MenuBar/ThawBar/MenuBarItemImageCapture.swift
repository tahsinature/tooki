import AppKit

/// Pictures of menu bar icons, taken from their windows even while they're pushed off screen.
/// Ported from Thaw 2 (Shared/Bridging/Shims.swift `SLWindowListCreateImageFromArray`,
/// https://github.com/thaw-app/Thaw, GPLv3). Needs the Screen Recording permission.
@MainActor
enum MenuBarItemImageCapture {
    private typealias CreateImageFromArray = @convention(c) (CGRect, CFArray, CGWindowImageOption) -> Unmanaged<CGImage>?

    /// Loaded at runtime, so a macOS without it only loses the pictures.
    private static let createImage: CreateImageFromArray? = {
        guard let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let symbol = dlsym(skyLight, "SLWindowListCreateImageFromArray")
        else { return nil }
        return unsafeBitCast(symbol, to: CreateImageFromArray.self)
    }()

    /// Checks without asking.
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt. Only call this when the user turns on a feature that needs it.
    static func requestAccess() {
        CGRequestScreenCaptureAccess()
    }

    /// The icon as drawn in the menu bar, or `nil` without permission or a window.
    static func image(of item: MenuBarItem) -> NSImage? {
        guard isAllowed, let createImage, let windowID = item.windowID,
              let windows = WindowServer.windowArray([windowID]),
              // A null rectangle captures exactly the window, wherever it is.
              let image = createImage(.null, windows, [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue(),
              image.width > 0, image.height > 0
        else { return nil }
        let frame = item.currentFrame
        return NSImage(cgImage: image, size: frame.size)
    }
}
