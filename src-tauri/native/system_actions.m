#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

// Read-only enumeration. Ejection is revalidated against this list immediately
// before invoking diskutil, without force-unmounting anything.
char *tooki_ejectable_volumes(void) {
    @autoreleasepool {
        NSArray *keys = @[NSURLVolumeNameKey, NSURLVolumeUUIDStringKey,
            NSURLVolumeIsEjectableKey, NSURLVolumeIsRootFileSystemKey];
        NSArray *volumes = [NSFileManager.defaultManager
            mountedVolumeURLsIncludingResourceValuesForKeys:keys options:0];
        if (!volumes) return NULL;
        NSMutableArray *result = [NSMutableArray array];
        for (NSURL *url in volumes) {
            NSDictionary *values = [url resourceValuesForKeys:keys error:nil];
            if (![values[NSURLVolumeIsEjectableKey] boolValue]
                || [values[NSURLVolumeIsRootFileSystemKey] boolValue]) continue;
            NSString *uuid = values[NSURLVolumeUUIDStringKey];
            // Do not offer volumes without a stable identity.
            if (![uuid isKindOfClass:NSString.class] || uuid.length == 0) continue;
            [result addObject:@{@"id":[NSString stringWithFormat:@"%@:%@", uuid, url.path], @"path":url.path,
                @"name":values[NSURLVolumeNameKey] ?: url.lastPathComponent}];
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        return json ? strdup([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String) : NULL;
    }
}
void tooki_volumes_free(char *value) { free(value); }
