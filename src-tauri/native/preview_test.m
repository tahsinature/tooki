#import "preview.m"
#define CHECK(test) if (!(test)) { fprintf(stderr,"Failed at line %d: %s\n",__LINE__,#test); return 1; }
static NSString *lastOwner, *lastContext;
@interface VisibleTestWindow : NSWindow
@end
@implementation VisibleTestWindow
- (BOOL)isVisible { return YES; }
@end
static int lastDirection;
static bool lastExtend;
static void recordNavigation(const char *owner, const char *context, int direction, bool extend) {
    lastOwner = @(owner); lastContext = @(context); lastDirection = direction; lastExtend = extend;
}
static NSEvent *key(unsigned short code, NSEventModifierFlags flags) {
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
        timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:code];
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        CHECK(!QLPreviewPanel.sharedPreviewPanelExists);
        NSDictionary *scope = @{@"owner":@"shelf-a", @"context":@"shelf:one"};
        CHECK(![tooki_preview(@"previewUpdate", scope)[@"active"] boolValue]);
        CHECK(!QLPreviewPanel.sharedPreviewPanelExists); // Selection updates must not create a preview.
        controller = [TookiPreviewController new]; controller.owner = @"shelf-a"; controller.context = @"shelf:one";
        CHECK(matches(scope));
        CHECK(!matches(@{@"owner":@"shelf-b", @"context":@"shelf:one"}));
        CHECK(!matches(@{@"owner":@"shelf-a", @"context":@"conversion:one"}));
        tooki_preview_initialize(recordNavigation);
        CHECK([controller previewPanel:nil handleEvent:key(125, 0)]);
        CHECK(lastDirection == 1 && !lastExtend);
        CHECK([lastOwner isEqual:@"shelf-a"] && [lastContext isEqual:@"shelf:one"]);
        CHECK([controller previewPanel:nil handleEvent:key(126, NSEventModifierFlagShift)]);
        CHECK(lastDirection == -1 && lastExtend);
        CHECK(![controller previewPanel:nil handleEvent:key(124, 0)]); // Left/Right remain Quick Look's controls.
        CHECK(![controller previewPanel:nil handleEvent:key(0, 0)]);
        tooki_preview_initialize(NULL);
        CHECK(![controller previewPanel:nil handleEvent:key(125, 0)]);
        controller.urls = @[[NSURL fileURLWithPath:@"/tmp/one"], [NSURL fileURLWithPath:@"/tmp/two"]];
        CHECK([controller numberOfPreviewItemsInPreviewPanel:nil] == 2);
        CHECK([[controller previewPanel:nil previewItemAtIndex:1] isEqual:controller.urls[1]]);
        CHECK([controller previewPanel:nil previewItemAtIndex:2] == nil);
        NSWindow *shelf = [VisibleTestWindow new];
        NSWindow *preview = [VisibleTestWindow new];
        NSWindow *menu = [VisibleTestWindow new];
        NSWindow *hidden = [NSWindow new];
        shelf.level = 5; preview.level = 6; menu.level = NSMainMenuWindowLevel; hidden.level = 12;
        CHECK(previewLevel(@[shelf, preview, menu, hidden], preview, 0) == 6);
        shelf.level = 8;
        CHECK(previewLevel(@[shelf, preview], preview, 0) == 9);
        CHECK(previewLevel(@[], preview, 10) == 10);
        puts("Quick Look stacking, ownership, navigation, and closed-preview tests passed");
    }
}
