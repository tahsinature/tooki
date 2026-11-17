#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

// All listener state belongs to the dedicated Rust worker's run loop.
typedef struct { uint64_t timestamp; int code, mods, pid, stage; } Press;
static _Thread_local Press queue[256];
static _Thread_local int count;
static _Thread_local BOOL blockPresses;
static _Thread_local BOOL swallowed[256];
static _Thread_local CFMachPortRef earlyTap, lateTap;
static _Thread_local CFRunLoopSourceRef earlySource, lateSource;
static _Thread_local BOOL interrupted;
static int modifiers(CGEventFlags flags) {
    return ((flags & kCGEventFlagMaskControl)?1:0) | ((flags & kCGEventFlagMaskAlternate)?2:0)
        | ((flags & kCGEventFlagMaskShift)?4:0) | ((flags & kCGEventFlagMaskCommand)?8:0);
}
static BOOL functionKey(int code) {
    switch(code) { case 122: case 120: case 99: case 118: case 96: case 97: case 98: case 100:
        case 101: case 109: case 103: case 111: case 105: case 107: case 113: case 106: case 64: case 79: case 80: case 90: return YES; default:return NO; }
}
static CGEventRef observe(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    (void)proxy;
    BOOL late = context != NULL;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        interrupted = YES; // Stop instead of quietly claiming an uninterrupted delivery test.
        return event;
    }
    int code = (int)CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode);
    if (code<0 || code>=256) return event;
    if (!late && type==kCGEventKeyUp && swallowed[code]) { swallowed[code]=NO; return NULL; }
    if(type!=kCGEventKeyDown) return event;
    if(CGEventGetIntegerValueField(event,kCGKeyboardEventAutorepeat)) return (!late && swallowed[code])?NULL:event;
    int mods=modifiers(CGEventGetFlags(event));
    if (!(mods & 11) && !functionKey(code)) return event;
    if(count<256) queue[count++] = (Press){CGEventGetTimestamp(event),code,mods,
        late ? (int)CGEventGetIntegerValueField(event,kCGEventTargetUnixProcessID) : NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier,late?1:0};
    else interrupted=YES;
    if(!late && blockPresses) { swallowed[code]=YES; return NULL; }
    return event;
}
static void stop(void) {
    if(earlyTap) { CGEventTapEnable(earlyTap,false); if(earlySource) CFRunLoopRemoveSource(CFRunLoopGetCurrent(),earlySource,kCFRunLoopDefaultMode); CFMachPortInvalidate(earlyTap); CFRelease(earlyTap); earlyTap=NULL; }
    if(lateTap) { CGEventTapEnable(lateTap,false); if(lateSource) CFRunLoopRemoveSource(CFRunLoopGetCurrent(),lateSource,kCFRunLoopDefaultMode); CFMachPortInvalidate(lateTap); CFRelease(lateTap); lateTap=NULL; }
    if(earlySource) { CFRelease(earlySource); earlySource=NULL; }
    if(lateSource) { CFRelease(lateSource); lateSource=NULL; }
    count=0; memset(swallowed,0,sizeof(swallowed));
}
static id attribute(AXUIElementRef element, CFStringRef name) {
    CFTypeRef value=NULL;
    if(AXUIElementCopyAttributeValue(element,name,&value)!=kAXErrorSuccess) return nil;
    return CFBridgingRelease(value);
}
static NSString *menuMatch(AXUIElementRef item, NSString *key, int mods, int depth, int *budget, NSTimeInterval deadline, NSString *path) {
    if(depth>5 || --*budget<=0 || NSDate.timeIntervalSinceReferenceDate>deadline) return nil;
    NSString *title=attribute(item,kAXTitleAttribute);
    NSString *next = title.length ? (path.length ? [path stringByAppendingFormat:@" › %@",title] : title) : path;
    NSString *character=attribute(item,kAXMenuItemCmdCharAttribute);
    NSNumber *raw=attribute(item,kAXMenuItemCmdModifiersAttribute);
    if([character isKindOfClass:NSString.class] && [raw isKindOfClass:NSNumber.class]) {
        int value=raw.intValue;
        int actual=((value&4)?1:0)|((value&2)?2:0)|((value&1)?4:0)|((value&8)?0:8);
        if(actual==mods && [character.lowercaseString isEqual:key]) return next;
    }
    NSArray *children=attribute(item,kAXChildrenAttribute);
    if(![children isKindOfClass:NSArray.class]) return nil;
    for(id child in children) {
        NSString *found=menuMatch((__bridge AXUIElementRef)child,key,mods,depth+1,budget,deadline,next);
        if(found) return found;
        if(*budget<=0 || NSDate.timeIntervalSinceReferenceDate>deadline) break;
    }
    return nil;
}
char *tooki_detective(const char *operation, const char *input) {
    @autoreleasepool { @try {
        NSString *op=@(operation);
        NSDictionary *args=[NSJSONSerialization JSONObjectWithData:[@(input) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        id result=@{};
        if([op isEqual:@"start"]) {
            stop(); interrupted=NO;
            if(!AXIsProcessTrusted()) result=@{@"error":@"Allow Tooki in System Settings → Privacy & Security → Accessibility, then start listening again."};
            else {
                blockPresses=[args[@"block"] boolValue];
                earlyTap=CGEventTapCreate(kCGHIDEventTap,kCGHeadInsertEventTap,blockPresses?kCGEventTapOptionDefault:kCGEventTapOptionListenOnly,
                    CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventKeyUp),observe,NULL);
                lateTap=CGEventTapCreate(kCGAnnotatedSessionEventTap,kCGTailAppendEventTap,kCGEventTapOptionListenOnly,CGEventMaskBit(kCGEventKeyDown),observe,(void *)1);
                if(!earlyTap || !lateTap) { stop(); result=@{@"error":@"macOS could not install keyboard monitoring. Check Accessibility and Input Monitoring permissions, then restart Tooki."}; }
                else {
                    earlySource=CFMachPortCreateRunLoopSource(NULL,earlyTap,0); lateSource=CFMachPortCreateRunLoopSource(NULL,lateTap,0);
                    CFRunLoopAddSource(CFRunLoopGetCurrent(),earlySource,kCFRunLoopDefaultMode); CFRunLoopAddSource(CFRunLoopGetCurrent(),lateSource,kCFRunLoopDefaultMode);
                    CGEventTapEnable(earlyTap,true); CGEventTapEnable(lateTap,true);
                }
            }
        } else if([op isEqual:@"poll"]) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.04,false);
            if(interrupted) result=@{@"error":@"macOS interrupted keyboard monitoring. Stop and restart listening."};
            else {
                NSMutableArray *events=[NSMutableArray array];
                for(int i=0;i<count;i++) { Press p=queue[i]; [events addObject:@{@"timestamp":@(p.timestamp),@"code":@(p.code),@"modifiers":@(p.mods),@"pid":@(p.pid),@"stage":@(p.stage)}]; }
                count=0; result=events;
            }
        } else if([op isEqual:@"stop"]) { stop(); }
        else if([op isEqual:@"describe"]) {
            pid_t pid=[args[@"pid"] intValue];
            NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];
            NSMutableDictionary *description=[NSMutableDictionary dictionary];
            if(app.localizedName) description[@"app"]=app.localizedName;
            if(pid>0 && pid!=getpid() && AXIsProcessTrusted()) {
                AXUIElementRef ax=AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(ax,0.05);
                id menu=attribute(ax,kAXMenuBarAttribute);
                if(menu) { int budget=500; NSString *match=menuMatch((__bridge AXUIElementRef)menu,args[@"key"],[args[@"modifiers"] intValue],0,&budget,NSDate.timeIntervalSinceReferenceDate+0.2,@""); if(match.length) description[@"menu"]=match; }
                CFRelease(ax);
            }
            result=description;
        } else if([op isEqual:@"system"]) {
            NSDictionary *hotkeys=[[NSUserDefaults alloc] initWithSuiteName:@"com.apple.symbolichotkeys"].dictionaryRepresentation[@"AppleSymbolicHotKeys"];
            NSMutableArray *entries=[NSMutableArray array];
            NSDictionary *names=@{@"64":@"Show Spotlight search",@"65":@"Show Finder search",@"32":@"Mission Control",@"33":@"Application windows",@"36":@"Show Desktop",@"60":@"Previous input source",@"61":@"Next input source",@"118":@"Switch to Desktop 1",@"120":@"Switch to Desktop 2"};
            for(NSString *identifier in hotkeys) {
                NSDictionary *entry=hotkeys[identifier]; NSArray *params=entry[@"value"][@"parameters"];
                if(![entry[@"enabled"] boolValue] || ![params isKindOfClass:NSArray.class] || params.count<3) continue;
                [entries addObject:@{@"code":params[1],@"modifiers":@(modifiers([params[2] unsignedLongLongValue])),@"name":names[identifier]?:[NSString stringWithFormat:@"System shortcut %@",identifier]}];
            }
            result=entries;
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        return strdup([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String?:"{}");
    } @catch(NSException *exception) { return strdup("{\"error\":\"Native shortcut detection failed.\"}"); } }
}
void tooki_detective_free(char *value) { free(value); }
