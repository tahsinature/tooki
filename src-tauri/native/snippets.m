#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

extern pid_t tooki_clipboard_target_pid(void);
static CFMachPortRef snippetTap;
static CFRunLoopSourceRef snippetSource;
static NSDictionary *spaceTriggers = @{}, *instantTriggers = @{};
static NSSet *excludedApps;
static NSMutableString *typed;
static pid_t typingPID;
static unsigned long generation;
static void (*snippetCallback)(const char *);

static id SnippetFailure(NSString *message) { return @{ @"error":message }; }
static id Attribute(AXUIElementRef element, CFStringRef name) {
    CFTypeRef value = NULL;
    if (!element || AXUIElementCopyAttributeValue(element, name, &value) != kAXErrorSuccess) return nil;
    return CFBridgingRelease(value);
}
static AXUIElementRef FocusedElement(pid_t pid) {
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    AXUIElementSetMessagingTimeout(app, 0.15);
    AXUIElementRef focused = NULL;
    AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute, (CFTypeRef *)&focused);
    CFRelease(app);
    return focused;
}
static BOOL SafeField(AXUIElementRef element) {
    if (IsSecureEventInputEnabled() || !element) return NO;
    NSString *role = Attribute(element, kAXRoleAttribute);
    NSString *subrole = Attribute(element, kAXSubroleAttribute);
    if ([subrole isEqualToString:@"AXSecureTextField"] || [role isEqualToString:@"AXSecureTextField"]) return NO;
    return [role isEqualToString:(__bridge NSString *)kAXTextFieldRole] || [role isEqualToString:(__bridge NSString *)kAXTextAreaRole] || [role isEqualToString:@"AXComboBox"];
}
static BOOL Selection(AXUIElementRef element, CFRange *range) {
    id value = Attribute(element, kAXSelectedTextRangeAttribute);
    return value && CFGetTypeID((__bridge CFTypeRef)value) == AXValueGetTypeID() && AXValueGetValue((__bridge AXValueRef)value, kAXValueCFRangeType, range);
}
@interface TookiSnippetTarget : NSObject
@property AXUIElementRef element;
@property pid_t pid;
@property (copy) NSString *token;
@property (copy) NSString *original;
@property (copy) NSString *suffix;
@property CFRange selection;
@end
@implementation TookiSnippetTarget
- (void)dealloc { if (_element) CFRelease(_element); }
@end
static TookiSnippetTarget *pendingTarget;

static TookiSnippetTarget *Capture(pid_t pid, NSString *suffix) {
    AXUIElementRef element = FocusedElement(pid);
    if (!element) return nil;
    if (!SafeField(element)) { CFRelease(element); return nil; }
    CFRange selection;
    NSString *value = Attribute(element, kAXValueAttribute);
    BOOL valid = SafeField(element) && [value isKindOfClass:NSString.class] && value.length <= 1048576 && Selection(element, &selection)
        && selection.length == 0 && selection.location >= (CFIndex)suffix.length && selection.location <= (CFIndex)value.length;
    if (valid) valid = [[value substringWithRange:NSMakeRange(selection.location-suffix.length,suffix.length)] isEqualToString:suffix];
    if (!valid) { CFRelease(element); return nil; }
    TookiSnippetTarget *target = [TookiSnippetTarget new];
    target.element = element; target.pid = pid; target.token = NSUUID.UUID.UUIDString;
    target.original = value; target.suffix = suffix; target.selection = selection;
    return target;
}
static void NotifyMatch(NSDictionary *invocation, NSString *suffix, pid_t pid, unsigned long version, int attempt) {
    if (version != generation || NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier != pid || IsSecureEventInputEnabled()) return;
    TookiSnippetTarget *target = Capture(pid, suffix);
    // Key-down notification precedes the destination consuming the key. Wait for
    // the actual AX suffix, never delete based on a guessed processing delay.
    if (!target && attempt < 8) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ NotifyMatch(invocation,suffix,pid,version,attempt+1); });
        return;
    }
    if (!target) return; // Unsupported/secure fields remain completely untouched.
    pendingTarget = target;
    NSMutableDictionary *payload = [invocation mutableCopy]; payload[@"context"] = target.token;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (snippetCallback) snippetCallback([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
}
static CGEventRef ObserveTyping(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    (void)proxy; (void)context;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) { if (snippetTap) CGEventTapEnable(snippetTap,true); [typed setString:@""]; generation++; return event; }
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (front.processIdentifier == NSProcessInfo.processInfo.processIdentifier) { [typed setString:@""]; return event; }
    generation++;
    if (IsSecureEventInputEnabled() || [excludedApps containsObject:front.bundleIdentifier ?: @""]) { [typed setString:@""]; return event; }
    if (front.processIdentifier != typingPID) { [typed setString:@""]; typingPID = front.processIdentifier; }
    if (type != kCGEventKeyDown) { [typed setString:@""]; return event; }
    CGEventFlags flags = CGEventGetFlags(event);
    if (flags & (kCGEventFlagMaskCommand|kCGEventFlagMaskControl)) { [typed setString:@""]; return event; }
    int code = (int)CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode);
    if (code == 51) { if (typed.length) [typed deleteCharactersInRange:[typed rangeOfComposedCharacterSequenceAtIndex:typed.length-1]]; return event; }
    UniChar chars[16]; UniCharCount length=0;
    CGEventKeyboardGetUnicodeString(event,16,&length,chars);
    NSString *text = [NSString stringWithCharacters:chars length:length];
    NSDictionary *invocation = nil;
    NSString *suffix = nil;
    if ([text isEqualToString:@" "]) { invocation=spaceTriggers[typed]; suffix=[typed stringByAppendingString:@" "]; [typed setString:@""]; }
    else if (text.length && [text rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location == NSNotFound && [text rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound) {
        [typed appendString:text];
        if (typed.length > 128) [typed setString:@""];
        invocation=instantTriggers[typed]; suffix=[typed copy];
        if (invocation) [typed setString:@""];
    } else { [typed setString:@""]; }
    if (invocation) { unsigned long version=generation; pid_t pid=front.processIdentifier; dispatch_async(dispatch_get_main_queue(), ^{ NotifyMatch(invocation,suffix,pid,version,0); }); }
    return event;
}
static void StopExpansion(void) {
    if (snippetTap) { CGEventTapEnable(snippetTap,false); CFMachPortInvalidate(snippetTap); CFRelease(snippetTap); snippetTap=NULL; }
    if (snippetSource) { CFRunLoopRemoveSource(CFRunLoopGetMain(),snippetSource,kCFRunLoopCommonModes); CFRelease(snippetSource); snippetSource=NULL; }
    pendingTarget=nil; typed=[NSMutableString new]; generation++;
}
static id Configure(NSDictionary *args) {
    StopExpansion();
    NSMutableDictionary *space=[NSMutableDictionary new], *instant=[NSMutableDictionary new];
    for (NSDictionary *entry in args[@"triggers"]) { if ([entry[@"instant"] boolValue]) instant[entry[@"trigger"]]=entry; else space[entry[@"trigger"]]=entry; }
    spaceTriggers=space; instantTriggers=instant;
    excludedApps=[NSSet setWithArray:args[@"excludedApps"] ?: @[]];
    if ([args[@"enabled"] boolValue] && AXIsProcessTrusted()) {
        CGEventMask mask=CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventRightMouseDown);
        snippetTap=CGEventTapCreate(kCGSessionEventTap,kCGTailAppendEventTap,kCGEventTapOptionListenOnly,mask,ObserveTyping,NULL);
        if (snippetTap) { snippetSource=CFMachPortCreateRunLoopSource(NULL,snippetTap,0); CFRunLoopAddSource(CFRunLoopGetMain(),snippetSource,kCFRunLoopCommonModes); CGEventTapEnable(snippetTap,true); }
    }
    return @{ @"supported":@YES, @"permission":@(AXIsProcessTrusted()), @"active":@(snippetTap && CGEventTapIsEnabled(snippetTap)) };
}
static BOOL TargetUnchanged(TookiSnippetTarget *target) {
    if (!target) return NO;
    NSRunningApplication *front=NSWorkspace.sharedWorkspace.frontmostApplication;
    if (front.processIdentifier != target.pid) return NO;
    AXUIElementRef focused=FocusedElement(target.pid);
    CFRange selection;
    BOOL valid=focused && CFEqual(focused,target.element) && SafeField(focused) && Selection(focused,&selection) && selection.location==target.selection.location && selection.length==0 && [Attribute(focused,kAXValueAttribute) isEqual:target.original];
    if (focused) CFRelease(focused);
    return valid;
}
static id Commit(NSDictionary *args) {
    TookiSnippetTarget *target=pendingTarget;
    if (!target || ![target.token isEqualToString:args[@"context"]]) return SnippetFailure(@"The expansion has expired. Your typed text was not changed.");
    if (!TargetUnchanged(target)) return SnippetFailure(@"The original app, text, or cursor changed. Your trigger was not replaced. Copy the result instead.");
    Boolean writable=false;
    if (AXUIElementIsAttributeSettable(target.element,kAXSelectedTextAttribute,&writable)!=kAXErrorSuccess || !writable) return SnippetFailure(@"This app does not support safe text replacement. Copy the result instead.");
    CFRange replacement=CFRangeMake(target.selection.location-target.suffix.length,target.suffix.length);
    AXValueRef range=AXValueCreate(kAXValueCFRangeType,&replacement);
    AXError error=AXUIElementSetAttributeValue(target.element,kAXSelectedTextRangeAttribute,range); CFRelease(range);
    if (error!=kAXErrorSuccess) return SnippetFailure(@"Could not select the trigger. Copy the result instead.");
    NSString *output=args[@"text"] ?: @"";
    if ([target.suffix hasSuffix:@" "]) output=[output stringByAppendingString:@" "];
    error=AXUIElementSetAttributeValue(target.element,kAXSelectedTextAttribute,(__bridge CFTypeRef)output);
    if (error!=kAXErrorSuccess) { CFRange originalRange=target.selection; range=AXValueCreate(kAXValueCFRangeType,&originalRange); AXUIElementSetAttributeValue(target.element,kAXSelectedTextRangeAttribute,range); CFRelease(range); return SnippetFailure(@"This app could not insert the snippet. Your trigger is unchanged; copy the result instead."); }
    pendingTarget=nil; [typed setString:@""]; return @YES;
}
static id Perform(NSString *operation, NSDictionary *args) {
    if ([operation isEqual:@"configure"]) return Configure(args);
    if ([operation isEqual:@"permission"]) { AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt:@YES}); }
    if ([operation isEqual:@"status"] || [operation isEqual:@"permission"]) return @{ @"supported":@YES,@"permission":@(AXIsProcessTrusted()),@"active":@(snippetTap && CGEventTapIsEnabled(snippetTap)) };
    if ([operation isEqual:@"target"]) return @(tooki_clipboard_target_pid());
    if ([operation isEqual:@"current"]) return @(pendingTarget && [pendingTarget.token isEqual:args[@"context"]] && TargetUnchanged(pendingTarget));
    if ([operation isEqual:@"cancel"]) { pendingTarget=nil; generation++; return @YES; }
    if ([operation isEqual:@"activate"]) {
        if (!pendingTarget || ![pendingTarget.token isEqual:args[@"context"]]) return SnippetFailure(@"The expansion has expired.");
        pid_t front=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
        if (front!=NSProcessInfo.processInfo.processIdentifier && front!=pendingTarget.pid) return SnippetFailure(@"Another app is now active. Copy the result instead.");
        NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pendingTarget.pid];
        if (!app || app.terminated || ![app activateWithOptions:0]) return SnippetFailure(@"The original app is no longer available.");
        return @YES;
    }
    if ([operation isEqual:@"ready"]) return @(pendingTarget && NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==pendingTarget.pid);
    if ([operation isEqual:@"commit"]) return Commit(args);
    return SnippetFailure(@"Unknown snippet operation.");
}
char *tooki_snippets(const char *operation, const char *input, void (*callback)(const char *)) {
    @autoreleasepool { @try {
        snippetCallback=callback;
        NSDictionary *args=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:input] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] ?: @{};
        id result=Perform([NSString stringWithUTF8String:operation],args);
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingFragmentsAllowed error:nil];
        return strdup([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
    } @catch(NSException *e) {
        NSData *data=[NSJSONSerialization dataWithJSONObject:SnippetFailure(e.reason ?: @"Native snippet failure") options:0 error:nil];
        return strdup([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
    } }
}
