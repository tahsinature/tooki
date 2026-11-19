#import "permissions.h"
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
// Remove only the exact pair installed by Tooki. Other current mappings win.
static NSArray *restoredMapping(NSArray *previous, NSArray *current, BOOL *owns) {
  NSMutableArray *next = [NSMutableArray array];
  *owns = NO;
  for (NSDictionary *entry in current) {
    if ([entry[@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] ==
            capsUsage &&
        [entry[@"HIDKeyboardModifierMappingDst"] unsignedLongLongValue] ==
            f18Usage)
      *owns = YES;
    else
      [next addObject:entry];
  }
  if (*owns) {
    for (NSDictionary *entry in previous)
      if ([entry[@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] == capsUsage)
        [next addObject:entry];
  }
  return next;
}
static BOOL restoreMappingAtPath(NSString *path, NSString **error) {
  if (![[NSFileManager defaultManager] fileExistsAtPath:path])
    return YES;
  NSData *data = [NSData dataWithContentsOfFile:path];
  NSArray *previous = data ? normalizeMapping([NSJSONSerialization JSONObjectWithData:data options:0 error:nil], error) : nil;
  if (!previous) {
    *error = @"Could not read the Hyper Key recovery file.";
    return NO;
  }
  NSArray *current = readMapping(error);
  if (!current)
    return NO;
  BOOL owns = NO;
  NSArray *next = restoredMapping(previous, current, &owns);
  if (owns && !writeMapping(next, error)) return NO;
  NSError *removalError = nil;
  if (![NSFileManager.defaultManager removeItemAtPath:path error:&removalError]) {
    *error = @"Could not remove the restored Hyper Key recovery record.";
    return NO;
  }
  return YES;
}
// Compatibility with builds before shared ownership. Both legacy locks must be
// held before reading recovery records, so a live old build is never disturbed.
static NSArray<NSString *> *legacyRecoveryPaths(void) {
  NSString *support = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
  return @[
    [support stringByAppendingPathComponent:@"us.tahsin.tooki/hyper/mapping-recovery.json"],
    [support stringByAppendingPathComponent:@"us.tahsin.tooki.dev/hyper/mapping-recovery.json"]
  ];
}
static BOOL restoreMapping(NSString **error) {
  if (!restoreMappingAtPath(backupPath, error)) return NO;
  for (NSString *path in legacyRecoveryPaths()) {
    if (![path isEqualToString:backupPath] && !restoreMappingAtPath(path, error)) return NO;
  }
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
    if (!tooki_accessibility_granted())
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

// Every build owns the shared lock and the old per-build locks for its entire
// Hyper session. OS locks release on a crash; recovery data survives for startup.
static NSMutableArray<NSNumber *> *mappingLocks;
static void releaseMappingLocks(void) {
  for (NSNumber *descriptor in mappingLocks) close(descriptor.intValue);
  mappingLocks = nil;
}
static BOOL acquireMappingLock(NSString *path) {
  int descriptor = open(path.fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0600);
  if (descriptor < 0) return NO;
  if (flock(descriptor, LOCK_EX | LOCK_NB) != 0) { close(descriptor); return NO; }
  [mappingLocks addObject:@(descriptor)];
  return YES;
}
char *tooki_hyper_set(bool enabled, const char *recovery) {
  if (!mappingLocks) {
    mappingLocks = [NSMutableArray array];
    NSString *shared = [NSString stringWithUTF8String:recovery];
    NSMutableArray *paths = [NSMutableArray arrayWithObject:shared];
    for (NSString *path in legacyRecoveryPaths()) {
      if (![path isEqualToString:shared]) {
        NSError *directoryError = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&directoryError]) {
          releaseMappingLocks();
          return strdup("Could not prepare the Hyper Key ownership directory. No keyboard mapping was changed.");
        }
        [paths addObject:path];
      }
    }
    for (NSString *path in paths) {
      if (!acquireMappingLock([path stringByAppendingString:@".lock"])) {
        releaseMappingLocks();
        return strdup("Another Tooki version owns Hyper Key, or its ownership lock is unavailable. Quit that version normally, then try again. No keyboard mapping was changed.");
      }
    }
  }
  char *error = NULL;
  @try {
    error = applyHyper(enabled, recovery);
  } @catch (NSException *exception) {
    // Never let an Objective-C exception unwind through Rust and abort app setup.
    error = strdup([[NSString stringWithFormat:@"Hyper Key could not update its mapping: %@", exception.reason] UTF8String]);
  }
  if (!hyperTap) {
    releaseMappingLocks();
  }
  return error;
}

void tooki_hyper_free(char *value) { free(value); }

bool tooki_hyper_active(void) {
  return hyperTap && CFMachPortIsValid(hyperTap) && CGEventTapIsEnabled(hyperTap)
      && tooki_accessibility_granted();
}
