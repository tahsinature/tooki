#pragma once
#import <ApplicationServices/ApplicationServices.h>

// All native guards read the grant for this process, never a saved preference.
static inline bool tooki_accessibility_granted(void) {
    return AXIsProcessTrusted();
}
