#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>

typedef void (*PreviewNavigation)(const char *, const char *, int, bool);
static PreviewNavigation navigation;

// Quick Look is shared by the application, but only its originating view may update it.
@interface TookiPreviewController : NSObject <QLPreviewPanelDataSource, QLPreviewPanelDelegate>
@property(nonatomic, copy) NSArray<NSURL *> *urls;
@property(nonatomic, copy) NSString *owner;
@property(nonatomic, copy) NSString *context;
@property(nonatomic) NSWindowLevel previousLevel;
@property(nonatomic) BOOL ownsLevel;
- (void)close:(QLPreviewPanel *)panel;
@end
@implementation TookiPreviewController
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel { return self.urls.count; }
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    return index >= 0 && (NSUInteger)index < self.urls.count ? self.urls[index] : nil;
}
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event {
    if (event.type != NSEventTypeKeyDown) return NO;
    if (event.keyCode == 53 || event.keyCode == 49 ||
        (event.keyCode == 16 && (event.modifierFlags & NSEventModifierFlagCommand))) {
        [self close:panel];
        return YES;
    }
    if (event.keyCode != 125 && event.keyCode != 126) return NO;
    if (!navigation || !self.owner.length || !self.context.length) return NO;
    navigation(self.owner.UTF8String, self.context.UTF8String, event.keyCode == 125 ? 1 : -1,
               (event.modifierFlags & NSEventModifierFlagShift) != 0);
    return YES;
}
- (void)close:(QLPreviewPanel *)panel {
    [panel orderOut:nil];
    if (self.ownsLevel) { panel.level = self.previousLevel; self.ownsLevel = NO; }
}
- (void)windowWillClose:(NSNotification *)notification {
    if (self.ownsLevel) {
        ((NSWindow *)notification.object).level = self.previousLevel;
        self.ownsLevel = NO;
    }
}
@end
static TookiPreviewController *controller;

void tooki_preview_initialize(PreviewNavigation callback) { navigation = callback; }

static BOOL matches(NSDictionary *args) {
    return controller && [controller.owner isEqual:args[@"owner"]] &&
        [controller.context isEqual:args[@"context"]];
}

static NSWindowLevel previewLevel(NSArray<NSWindow *> *windows, NSWindow *panel, NSWindowLevel original) {
    NSWindowLevel level = MAX(original, NSFloatingWindowLevel + 1);
    // Tao 0.37 uses level 5 for always-on-top windows; AppKit's floating level is 3.
    // Read actual levels so a framework upgrade cannot put shelves above the preview again.
    // Exclude menus and system overlays from this application's content-window ordering.
    for (NSWindow *window in windows) {
        if (window != panel && window.visible && window.level < NSMainMenuWindowLevel - 1)
            level = MAX(level, window.level + 1);
    }
    return level;
}

NSDictionary *tooki_preview(NSString *operation, NSDictionary *args) {
    BOOL exists = QLPreviewPanel.sharedPreviewPanelExists;
    QLPreviewPanel *panel = exists ? QLPreviewPanel.sharedPreviewPanel : nil;
    BOOL active = panel.visible && panel.dataSource == controller && matches(args);
    if ([operation isEqual:@"previewCloseOwner"]) {
        if (panel.visible && panel.dataSource == controller && [controller.owner isEqual:args[@"owner"]])
            [controller close:panel];
        return @{@"active":@NO};
    }
    if ([operation isEqual:@"previewActive"]) return @{@"active":@(active)};
    if ([operation isEqual:@"previewClose"]) {
        if (active) [controller close:panel];
        return @{@"active":@NO};
    }
    BOOL update = [operation isEqual:@"previewUpdate"];
    // Updating selection never opens a closed preview or takes over another view's preview.
    if (update && !active) return @{@"active":@NO};
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (id path in args[@"paths"]) {
        if ([path isKindOfClass:NSString.class] && [path length])
            [urls addObject:[NSURL fileURLWithPath:path]];
    }
    if (!update && active && [controller.urls isEqualToArray:urls]) {
        [controller close:panel]; return @{@"active":@NO};
    }
    if (!urls.count) {
        if (active) [controller close:panel];
        return @{@"active":@NO};
    }
    if (!controller) controller = [TookiPreviewController new];
    if (!panel) panel = QLPreviewPanel.sharedPreviewPanel;
    if (!controller.ownsLevel) {
        controller.previousLevel = panel.level;
        controller.ownsLevel = YES;
    }
    controller.owner = args[@"owner"] ?: @"";
    controller.context = args[@"context"] ?: @"";
    BOOL changed = ![controller.urls isEqualToArray:urls];
    controller.urls = urls;
    panel.dataSource = controller;
    panel.delegate = controller;
    if (!update) {
        [NSApp activateIgnoringOtherApps:YES];
        [panel makeKeyAndOrderFront:nil];
        panel.dataSource = controller;
        panel.delegate = controller;
    }
    if (changed || !update) { [panel reloadData]; panel.currentPreviewItemIndex = 0; }
    panel.level = previewLevel(NSApp.windows, panel, controller.previousLevel);
    return @{@"active":@YES};
}

bool tooki_preview_belongs_to_window(void *window, const char *owner) {
    if (![QLPreviewPanel sharedPreviewPanelExists] || !controller) return false;
    QLPreviewPanel *panel = [QLPreviewPanel sharedPreviewPanel];
    return window == (__bridge void *)panel && panel.visible && panel.dataSource == controller
        && [controller.owner isEqualToString:[NSString stringWithUTF8String:owner]];
}
