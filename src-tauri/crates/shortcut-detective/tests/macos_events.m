// Synthetic events are passed directly to the callback; nothing is posted to the OS.
#include "../native/macos.m"
#include <assert.h>
int main(void) {
    @autoreleasepool {
        CGEventRef event=CGEventCreateKeyboardEvent(NULL,0,true);
        CGEventSetFlags(event,0);
        observe(NULL,kCGEventKeyDown,event,NULL); assert(count==0);
        CGEventSetFlags(event,kCGEventFlagMaskShift);
        observe(NULL,kCGEventKeyDown,event,NULL); assert(count==0);
        CGEventSetFlags(event,kCGEventFlagMaskCommand);
        CGEventSetTimestamp(event,100);
        observe(NULL,kCGEventKeyDown,event,NULL);
        CGEventSetTimestamp(event,200);
        observe(NULL,kCGEventKeyDown,event,NULL);
        assert(count==2 && queue[0].timestamp==100 && queue[1].timestamp==200);
        CGEventSetIntegerValueField(event,kCGEventTargetUnixProcessID,123);
        observe(NULL,kCGEventKeyDown,event,(void*)1);
        assert(queue[2].stage==1 && queue[2].pid==123 && queue[2].timestamp==200);
        count=0;blockPresses=YES;
        assert(observe(NULL,kCGEventKeyDown,event,NULL)==NULL);
        assert(swallowed[0] && count==1);
        CGEventSetIntegerValueField(event,kCGKeyboardEventAutorepeat,1);
        assert(observe(NULL,kCGEventKeyDown,event,NULL)==NULL && count==1);
        assert(observe(NULL,kCGEventKeyUp,event,NULL)==NULL && !swallowed[0]);
        assert(observe(NULL,kCGEventKeyUp,event,NULL)==event);
        stop();assert(count==0 && !earlyTap && !lateTap);
        CFRelease(event);
        puts("Native callback checks passed: typing exclusion, press identity, delivery, suppression, repeat and cleanup.");
    }
}
