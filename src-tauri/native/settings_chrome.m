#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface TookiSettingsWindowActions : NSObject
@property(nonatomic, weak) NSWindow *window;
- (void)requestClose:(id)sender;
- (void)minimize:(id)sender;
@end

@implementation TookiSettingsWindowActions
- (void)requestClose:(id)sender {
  NSWindow *window = self.window;
  id<NSWindowDelegate> delegate = window.delegate;
  // Preserve Tauri's CloseRequested handling, which hides this reusable window.
  if (![delegate respondsToSelector:@selector(windowShouldClose:)] || [delegate windowShouldClose:window])
    [window close];
}
- (void)minimize:(id)sender {
  [self.window miniaturize:sender];
}
@end

static char settingsActionsKey;

// Borderless Settings owns its shape; AppKit still supplies real window buttons.
void tooki_settings_chrome(void *pointer) {
  NSWindow *window = (__bridge NSWindow *)pointer;
  window.opaque = NO;
  window.backgroundColor = NSColor.clearColor;
  window.hasShadow = YES;
  window.styleMask |= NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
  TookiSettingsWindowActions *actions = [TookiSettingsWindowActions new];
  actions.window = window;
  objc_setAssociatedObject(window, &settingsActionsKey, actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  NSView *content = window.contentView;
  for (NSUInteger index = 0; index < 3; index++) {
    NSWindowButton kind = index == 0 ? NSWindowCloseButton : index == 1 ? NSWindowMiniaturizeButton : NSWindowZoomButton;
    NSButton *button = [NSWindow standardWindowButton:kind forStyleMask:NSWindowStyleMaskTitled];
    button.frame = NSMakeRect(10 + index * 23, content.bounds.size.height - 23, 14, 14);
    button.autoresizingMask = NSViewMinYMargin;
    // performClose:/performMiniaturize: require the window's own titlebar buttons.
    // These AppKit buttons live in our borderless content view instead.
    button.target = actions;
    button.action = index == 0 ? @selector(requestClose:) : @selector(minimize:);
    button.enabled = index != 2;
    [content addSubview:button positioned:NSWindowAbove relativeTo:nil];
  }
}
