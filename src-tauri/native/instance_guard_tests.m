#import "instance_guard.m"
#define CHECK(value) if (!(value)) { fprintf(stderr, "Guard check failed at line %d\n", __LINE__); return 1; }
int main(void) {
    @autoreleasepool {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        int first = acquire_session(path);
        CHECK(first >= 0);
        CHECK(acquire_session(path) < 0);
        tooki_instance_guard_release(first);
        int next = acquire_session(path);
        CHECK(next >= 0);
        tooki_instance_guard_release(next);
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        NSString *link = [path stringByAppendingString:@".link"];
        CHECK(symlink(path.fileSystemRepresentation, link.fileSystemRepresentation) == 0);
        CHECK(acquire_session(link) < 0);
        unlink(link.fileSystemRepresentation);
        puts("Session lock exclusion, release and symlink rejection passed. No apps were stopped.");
    }
    return 0;
}
