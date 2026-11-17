#import <AppKit/AppKit.h>
#import <objc/runtime.h>

// Match Sources/Tooki/App/MenuBarIcon.swift: an 18-point folded T and DEV pill.
static NSImage *TookiMenuBarImage(BOOL development, BOOL dark) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:YES
        drawingHandler:^BOOL(NSRect rect) {
        (void)rect;
        [(dark ? NSColor.whiteColor : NSColor.blackColor) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(2, 2.5, 14, 4.5)
                                        xRadius:1.2 yRadius:1.2] fill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(6.5, 6, 5, 10)
                                        xRadius:1.2 yRadius:1.2] fill];
        NSGraphicsContext.currentContext.compositingOperation = NSCompositingOperationClear;
        NSBezierPath *crease = NSBezierPath.bezierPath;
        [crease moveToPoint:NSMakePoint(6, 11.5)];
        [crease lineToPoint:NSMakePoint(12, 7.5)];
        crease.lineWidth = 1;
        [crease stroke];
        NSGraphicsContext.currentContext.compositingOperation = NSCompositingOperationSourceOver;
        if (development) {
            NSRect badge = NSMakeRect(3, 10.5, 15, 7.5);
            [[NSColor colorWithCalibratedRed:1 green:0.62 blue:0.16 alpha:1] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:badge xRadius:3.75 yRadius:3.75] fill];
            NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"DEV" attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:5.5 weight:NSFontWeightBlack],
                NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.07 alpha:1]
            }];
            NSSize size = title.size;
            [title drawInRect:NSMakeRect(NSMidX(badge) - size.width / 2,
                NSMidY(badge) - size.height / 2, size.width, size.height)];
        }
        return YES;
    }];
    image.template = !development;
    return image;
}

// Observe the status button, rather than an app window: the menu bar may use a
// different appearance. Association with its status item bounds observer lifetime.
@interface TookiMenuBarAppearance : NSObject
@property(nonatomic, weak) NSStatusBarButton *button;
@end
@implementation TookiMenuBarAppearance
- (instancetype)initWithButton:(NSStatusBarButton *)button {
    if ((self = [super init])) {
        _button = button;
        [button addObserver:self forKeyPath:@"effectiveAppearance"
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:NULL];
    }
    return self;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                      change:(NSDictionary *)change context:(void *)context {
    NSStatusBarButton *button = self.button;
    NSAppearanceName match = [button.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    button.image = TookiMenuBarImage(YES, [match isEqualToString:NSAppearanceNameDarkAqua]);
}
- (void)dealloc {
    [self.button removeObserver:self forKeyPath:@"effectiveAppearance"];
}
@end

bool tooki_set_menu_bar_icon(void *pointer, bool development) {
    NSStatusItem *item = (__bridge NSStatusItem *)pointer;
    NSStatusBarButton *button = item.button;
    if (!button) return false;
    static char observerKey;
    objc_setAssociatedObject(item, &observerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (development) {
        TookiMenuBarAppearance *observer = [[TookiMenuBarAppearance alloc] initWithButton:button];
        objc_setAssociatedObject(item, &observerKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        button.image = TookiMenuBarImage(NO, NO);
    }
    return true;
}
