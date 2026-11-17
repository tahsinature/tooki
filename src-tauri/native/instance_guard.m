#import <AppKit/AppKit.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

static int acquire_session(NSString *path) {
    int descriptor = open(path.fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
        close(descriptor);
        return -1;
    }
    return descriptor;
}

static int fail(NSString *message, char **error) {
    *error = strdup(message.UTF8String);
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Another Tooki is running";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return -1;
}

// Called before any feature starts. NSRunningApplication.terminate is a normal
// quit request, allowing the other app to save and release its native hooks.
int tooki_instance_guard(bool development, char **error) {
    @autoreleasepool {
        NSString *otherID = development ? @"us.tahsin.tooki" : @"us.tahsin.tooki.dev";
        NSArray<NSRunningApplication *> *others = [NSRunningApplication runningApplicationsWithBundleIdentifier:otherID];
        if (development) {
            for (NSRunningApplication *other in others) {
                if (![other terminate]) {
                    return fail(@"Tooki could not quit normally. Quit the production app, then start Tooki Dev again. No forced quit was used.", error);
                }
            }
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8];
            while ([NSRunningApplication runningApplicationsWithBundleIdentifier:otherID].count > 0) {
                if (deadline.timeIntervalSinceNow <= 0) {
                    return fail(@"Tooki is still running. Finish any open dialog and quit it before starting Tooki Dev. No forced quit was used.", error);
                }
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
        } else if (others.count > 0) {
            return fail(@"Quit Tooki Dev before opening Tooki. Only one version can use your shortcuts and shared configuration at a time.", error);
        }

        // This lock is local, never synced with portable preferences. Both builds
        // use it to close the race between checking processes and starting hooks.
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/us.tahsin.tooki"];
        NSError *directoryError = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&directoryError]) {
            return fail(@"Could not create Tooki’s local session lock. The app was not started.", error);
        }
        NSString *path = [directory stringByAppendingPathComponent:@"active-session.lock"];
        int descriptor = acquire_session(path);
        if (descriptor < 0) {
            return fail(@"Another Tooki instance is starting or running. Quit it before trying again.", error);
        }
        return descriptor;
    }
}
void tooki_instance_guard_release(int descriptor) { close(descriptor); }
void tooki_instance_guard_free(char *error) { free(error); }
