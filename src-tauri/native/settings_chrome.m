#import <AppKit/AppKit.h>

// Borderless Settings owns its shape; AppKit still supplies real window buttons.
void tooki_settings_chrome(void *pointer) {
  NSWindow *window = (__bridge NSWindow *)pointer;
  window.opaque = NO;
  window.backgroundColor = NSColor.clearColor;
  window.hasShadow = YES;
  window.styleMask |= NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
  NSView *content = window.contentView;
  for (NSUInteger index = 0; index < 3; index++) {
    NSWindowButton kind = index == 0 ? NSWindowCloseButton : index == 1 ? NSWindowMiniaturizeButton : NSWindowZoomButton;
    NSButton *button = [NSWindow standardWindowButton:kind forStyleMask:NSWindowStyleMaskTitled];
    button.frame = NSMakeRect(10 + index * 23, content.bounds.size.height - 23, 14, 14);
    button.autoresizingMask = NSViewMinYMargin;
    button.target = window;
    button.action = index == 0 ? @selector(performClose:) : @selector(performMiniaturize:);
    button.enabled = index != 2;
    [content addSubview:button positioned:NSWindowAbove relativeTo:nil];
  }
}
