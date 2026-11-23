#import <AppKit/AppKit.h>

@interface TookiToastPanel : NSPanel
@end
@implementation TookiToastPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

static TookiToastPanel *toastPanel;
static NSUInteger toastGeneration;

static NSRect toastFrame(NSRect visible, NSSize size) {
    return NSMakeRect(NSMidX(visible) - size.width / 2,
        NSMinY(visible) + MIN(72, MAX(16, visible.size.height - size.height - 16)),
        size.width, size.height);
}

static TookiToastPanel *makeToast(NSString *message, BOOL failed, NSRect visible) {
    NSTextField *label = [NSTextField wrappingLabelWithString:message];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    label.textColor = NSColor.labelColor;
    label.maximumNumberOfLines = 3;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    CGFloat naturalWidth = ceil([message sizeWithAttributes:@{NSFontAttributeName: label.font}].width) + 68;
    CGFloat width = MIN(MIN(380, visible.size.width - 32), MAX(200, naturalWidth));
    CGFloat textWidth = width - 68;
    NSSize textSize = [label.cell cellSizeForBounds:NSMakeRect(0, 0, textWidth, 1000)];
    CGFloat textHeight = MIN(54, MAX(18, ceil(textSize.height)));
    CGFloat height = textHeight + 28;
    TookiToastPanel *panel = [[TookiToastPanel alloc]
        initWithContentRect:toastFrame(visible, NSMakeSize(width, height))
        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
        backing:NSBackingStoreBuffered defer:NO];
    panel.releasedWhenClosed = NO;
    panel.opaque = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = YES;
    panel.level = NSStatusWindowLevel;
    panel.hidesOnDeactivate = NO;
    panel.ignoresMouseEvents = YES;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
        | NSWindowCollectionBehaviorFullScreenAuxiliary
        | NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorIgnoresCycle;
    panel.accessibilityLabel = message;
    NSVisualEffectView *surface = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    surface.material = NSVisualEffectMaterialHUDWindow;
    surface.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    surface.state = NSVisualEffectStateActive;
    surface.wantsLayer = YES;
    surface.layer.cornerRadius = 14;
    surface.layer.masksToBounds = YES;
    surface.layer.borderWidth = 0.5;
    surface.layer.borderColor = [NSColor.separatorColor CGColor];
    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(16, (height - 20) / 2, 20, 20)];
    icon.image = [NSImage imageWithSystemSymbolName:failed ? @"exclamationmark.circle.fill" : @"checkmark.circle.fill"
        accessibilityDescription:failed ? @"Failed" : @"Completed"];
    icon.contentTintColor = failed ? NSColor.systemOrangeColor : NSColor.systemGreenColor;
    label.frame = NSMakeRect(46, (height - textHeight) / 2, textWidth, textHeight);
    [surface addSubview:icon];
    [surface addSubview:label];
    panel.contentView = surface;
    return panel;
}

// Runs on the main thread. This HUD never becomes key or activates Tooki.
void tooki_toast_show(void *source, const char *text, bool failed) {
    NSString *message = text ? [NSString stringWithUTF8String:text] : nil;
    if (!message.length) return;
    NSWindow *window = (__bridge NSWindow *)source;
    NSScreen *screen = window.screen;
    if (!screen) {
        for (NSScreen *candidate in NSScreen.screens)
            if (NSMouseInRect(NSEvent.mouseLocation, candidate.frame, NO)) { screen = candidate; break; }
    }
    if (!screen) screen = NSScreen.mainScreen;
    if (!screen) return;
    NSUInteger generation = ++toastGeneration;
    [toastPanel orderOut:nil];
    toastPanel = makeToast(message, failed, screen.visibleFrame);
    [toastPanel orderFrontRegardless];
    NSAccessibilityPostNotificationWithUserInfo(toastPanel,
        NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey: message, NSAccessibilityPriorityKey: @(NSAccessibilityPriorityMedium)});
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((failed ? 6 : 3) * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            if (generation != toastGeneration) return;
            [toastPanel orderOut:nil];
            toastPanel = nil;
        });
}
