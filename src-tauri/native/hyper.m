#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDParameter.h>
#import <IOKit/hidsystem/IOHIDShared.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
static CFMachPortRef hyperTap;
static CFRunLoopSourceRef hyperSource;
static BOOL held, used, modified[128];
static CFAbsoluteTime pressed;
static NSString *backupPath;
static const uint64_t capsUsage = 0x700000039, f18Usage = 0x70000006D;
static NSString *runHid(NSArray *arguments, NSString **error) {
  NSTask *task = [NSTask new];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/hidutil"];
  task.arguments = arguments;
  NSPipe *out = [NSPipe pipe];
  task.standardOutput = out;
  task.standardError = [NSFileHandle fileHandleWithNullDevice];
  NSError *failure = nil;
  if (![task launchAndReturnError:&failure]) {
    *error = failure.localizedDescription;
    return nil;
  }
  NSData *data = [out.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (task.terminationStatus) {
    *error = @"Could not update keyboard mapping.";
    return nil;
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
// hidutil's OpenStep plist decodes numbers as NSStrings. Normalize both
// live mappings and recovery JSON before using NSNumber-only accessors.
static NSArray *normalizeMapping(id value, NSString **error) {
  if (![value isKindOfClass:NSArray.class]) {
    *error = @"Invalid keyboard mapping array.";
    return nil;
  }
  NSMutableArray *result = [NSMutableArray array];
  for (id entry in value) {
    if (![entry isKindOfClass:NSDictionary.class]) {
      *error = @"Invalid keyboard mapping entry.";
      return nil;
    }
    NSMutableDictionary *normalized = [entry mutableCopy];
    for (NSString *key in @[ @"HIDKeyboardModifierMappingSrc", @"HIDKeyboardModifierMappingDst" ]) {
      id number = entry[key];
      if (![number isKindOfClass:NSString.class] && ![number isKindOfClass:NSNumber.class]) {
        *error = @"Invalid keyboard mapping usage.";
        return nil;
      }
      NSString *text = [number isKindOfClass:NSString.class] ? number : [number stringValue];
      unsigned long long usage = 0;
      NSScanner *scanner = [NSScanner scannerWithString:text];
      scanner.charactersToBeSkipped = nil;
      BOOL valid = [text hasPrefix:@"0x"] ? [scanner scanHexLongLong:&usage] : [scanner scanUnsignedLongLong:&usage];
      if (!valid || !scanner.isAtEnd || [text hasPrefix:@"-"]) {
        *error = @"Invalid keyboard mapping usage.";
        return nil;
      }
      normalized[key] = @(usage);
    }
    [result addObject:normalized];
  }
  return result;
}
static NSArray *parseMapping(NSString *raw, NSString **error) {
  // Recent macOS versions return a table of service mappings, not a single
  // plist.
  NSRegularExpression *pattern = [NSRegularExpression
      regularExpressionWithPattern:@"\\([^)]*\\)"
                           options:NSRegularExpressionDotMatchesLineSeparators
                             error:nil];
  NSArray *mapping = nil;
  for (NSTextCheckingResult *match in
       [pattern matchesInString:raw
                        options:0
                          range:NSMakeRange(0, raw.length)]) {
    NSString *part = [raw substringWithRange:match.range];
    if ([part isEqualToString:@"(null)"])
      continue;
    id value = [NSPropertyListSerialization
        propertyListWithData:[part dataUsingEncoding:NSUTF8StringEncoding]
                     options:NSPropertyListImmutable
                      format:nil
                       error:nil];
    NSArray *normalized = normalizeMapping(value, error);
    if (!normalized) return nil;
    if (mapping && ![mapping isEqual:normalized]) {
      *error = @"Keyboard devices have different mappings. Disable other "
               @"remappers before enabling Hyper Key.";
      return nil;
    }
    mapping = normalized;
  }
  if (mapping)
    return mapping;
  if ([raw containsString:@"(null)"])
    return @[];
  *error =
      @"Could not read existing keyboard mappings; no mapping was changed.";
  return nil;
}
static NSArray *readMapping(NSString **error) {
  NSString *raw = runHid(@[ @"property", @"--get", @"UserKeyMapping" ], error);
  return raw ? parseMapping(raw, error) : nil;
}
static BOOL writeMapping(NSArray *mapping, NSString **error) {
  NSData *data =
      [NSJSONSerialization dataWithJSONObject:@{@"UserKeyMapping" : mapping}
                                      options:0
                                        error:nil];
  return runHid(
             @[
               @"property", @"--set",
               [[NSString alloc] initWithData:data
                                     encoding:NSUTF8StringEncoding]
             ],
             error) != nil;
}
static BOOL restoreMapping(NSString **error) {
  if (![[NSFileManager defaultManager] fileExistsAtPath:backupPath])
    return YES;
  NSData *data = [NSData dataWithContentsOfFile:backupPath];
  NSArray *previous = data ? normalizeMapping([NSJSONSerialization JSONObjectWithData:data options:0 error:nil], error) : nil;
  if (!previous) {
    *error = @"Could not read the Hyper Key recovery file.";
    return NO;
  }
  NSArray *current = readMapping(error);
  if (!current)
    return NO;
  NSMutableArray *next = [NSMutableArray array];
  BOOL owns = NO;
  for (NSDictionary *entry in current) {
    if ([entry[@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] ==
            capsUsage &&
        [entry[@"HIDKeyboardModifierMappingDst"] unsignedLongLongValue] ==
            f18Usage)
      owns = YES;
    else
      [next addObject:entry];
  }
  // Preserve modifications made by another remapper while Tooki was running.
  if (owns) {
    for (NSDictionary *entry in previous)
      if ([entry[@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] ==
          capsUsage)
        [next addObject:entry];
    if (!writeMapping(next, error))
      return NO;
  }
  [[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil];
  return YES;
}
static void toggleCaps(void) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    io_service_t service = IOServiceGetMatchingService(
        kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass));
    if (!service)
      return;
    io_connect_t connection = 0;
    if (IOServiceOpen(service, mach_task_self_, kIOHIDParamConnectType,
                      &connection) == KERN_SUCCESS) {
      bool value = false;
      IOHIDGetModifierLockState(connection, kIOHIDCapsLockState, &value);
      IOHIDSetModifierLockState(connection, kIOHIDCapsLockState, !value);
      IOServiceClose(connection);
    }
    IOObjectRelease(service);
  });
}
static CGEventRef handle(CGEventTapProxy proxy, CGEventType type,
                         CGEventRef event, void *context) {
  (void)proxy;
  (void)context;
  if (type == kCGEventTapDisabledByTimeout ||
      type == kCGEventTapDisabledByUserInput) {
    held = NO;
    memset(modified, 0, sizeof(modified));
    CGEventTapEnable(hyperTap, true);
    return event;
  }
  int key = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
  if (key == 79) { // F18, reserved for the physical Caps Lock mapping.
    if (type == kCGEventKeyDown &&
        !CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat)) {
      held = YES;
      used = NO;
      pressed = CFAbsoluteTimeGetCurrent();
    }
    if (type == kCGEventKeyUp) {
      BOOL tap = held && !used && CFAbsoluteTimeGetCurrent() - pressed < .3;
      held = NO;
      if (tap)
        toggleCaps();
    }
    return NULL;
  }
  if (held || (key >= 0 && key < 128 && modified[key])) {
    used = YES;
    CGEventSetFlags(event, CGEventGetFlags(event) | kCGEventFlagMaskCommand |
                               kCGEventFlagMaskControl |
                               kCGEventFlagMaskAlternate |
                               kCGEventFlagMaskShift);
    if (key >= 0 && key < 128)
      modified[key] = type != kCGEventKeyUp;
  }
  return event;
}
// Called on the AppKit main thread. Returns an owned error string, or NULL.
static char *applyHyper(bool enabled, const char *recovery) {
  @autoreleasepool {
    backupPath = [NSString stringWithUTF8String:recovery];
    NSString *error = nil;
    if (!enabled) {
      if (!restoreMapping(&error))
        return strdup(error.UTF8String);
      if (hyperSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), hyperSource,
                              kCFRunLoopCommonModes);
        CFRelease(hyperSource);
        hyperSource = NULL;
      }
      if (hyperTap) {
        CFMachPortInvalidate(hyperTap);
        CFRelease(hyperTap);
        hyperTap = NULL;
      }
      held = NO;
      memset(modified, 0, sizeof(modified));
      return NULL;
    }
    if (hyperTap)
      return NULL;
    if (!AXIsProcessTrusted())
      return strdup("Enable Accessibility permission for Tooki before enabling "
                    "Hyper Key.");
    if (!restoreMapping(&error))
      return strdup(error.UTF8String);
    NSArray *previous = readMapping(&error);
    if (!previous)
      return strdup(error.UTF8String);
    for (NSDictionary *entry in previous)
      if ([entry[@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] ==
          capsUsage)
        return strdup("Caps Lock already has a mapping. Disable the other "
                      "remapper first.");
    hyperTap = CGEventTapCreate(
        kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp), handle,
        NULL);
    if (!hyperTap)
      return strdup("Could not start Hyper Key keyboard monitoring.");
    hyperSource =
        CFMachPortCreateRunLoopSource(kCFAllocatorDefault, hyperTap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), hyperSource, kCFRunLoopCommonModes);
    CGEventTapEnable(hyperTap, true);
    NSData *backup = [NSJSONSerialization dataWithJSONObject:previous
                                                     options:0
                                                       error:nil];
    if (![backup writeToFile:backupPath atomically:YES])
      error = @"Could not save keyboard mapping recovery data.";
    NSMutableArray *next = [previous mutableCopy];
    [next addObject:@{
      @"HIDKeyboardModifierMappingSrc" : @(capsUsage),
      @"HIDKeyboardModifierMappingDst" : @(f18Usage)
    }];
    if (error || !writeMapping(next, &error)) {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), hyperSource,
                            kCFRunLoopCommonModes);
      CFRelease(hyperSource);
      hyperSource = NULL;
      CFMachPortInvalidate(hyperTap);
      CFRelease(hyperTap);
      hyperTap = NULL;
      return strdup(error.UTF8String);
    }
    return NULL;
  }
}

// A dev process and a packaged build may share the same app-data directory.
// Hold an OS lock while enabled so a second instance cannot restore our
// mapping.
static int mappingLock = -1;
char *tooki_hyper_set(bool enabled, const char *recovery) {
  if (mappingLock < 0) {
    NSString *lockPath = [[NSString stringWithUTF8String:recovery]
        stringByAppendingString:@".lock"];
    int descriptor =
        open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
    if (descriptor < 0)
      return strdup("Could not open the Hyper Key ownership lock.");
    if (flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
      close(descriptor);
      return strdup("Hyper Key is active in another Tooki instance. Disable it "
                    "there first.");
    }
    mappingLock = descriptor;
  }
  char *error = NULL;
  @try {
    error = applyHyper(enabled, recovery);
  } @catch (NSException *exception) {
    // Never let an Objective-C exception unwind through Rust and abort app setup.
    error = strdup([[NSString stringWithFormat:@"Hyper Key could not update its mapping: %@", exception.reason] UTF8String]);
  }
  if (!hyperTap) {
    flock(mappingLock, LOCK_UN);
    close(mappingLock);
    mappingLock = -1;
  }
  return error;
}

void tooki_hyper_free(char *value) { free(value); }

bool tooki_hyper_active(void) {
  return hyperTap && CFMachPortIsValid(hyperTap) && CGEventTapIsEnabled(hyperTap)
      && AXIsProcessTrusted();
}

// Prompt only after an explicit user action, never during startup/status reads.
bool tooki_hyper_accessibility(bool prompt) {
  NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @(prompt)};
  return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}
bool tooki_hyper_open_accessibility(void) {
  return [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
