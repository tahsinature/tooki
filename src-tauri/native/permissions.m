#import <AppKit/AppKit.h>
#import "permissions.h"

bool tooki_permissions_accessibility(void) {
    return tooki_accessibility_granted();
}
bool tooki_permissions_open_accessibility(void) {
    // Only called after the user chooses Open Accessibility Settings.
    return [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
