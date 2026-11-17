#import <AppKit/AppKit.h>
static void collectApplications(NSURL *folder, NSInteger depth, NSMutableArray *result, NSMutableSet *seen) {
    NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *url in entries) {
        if ([url.pathExtension.lowercaseString isEqualToString:@"app"]) {
            NSString *key = url.lastPathComponent.lowercaseString;
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
            NSString *name = [[NSFileManager.defaultManager displayNameAtPath:url.path] stringByDeletingPathExtension];
            NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:url.path];
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:40 pixelsHigh:40 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState];
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
            [icon drawInRect:NSMakeRect(0,0,40,40)];
            [NSGraphicsContext restoreGraphicsState];
            NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSMutableDictionary *entry = [@{@"id":url.path, @"name":name} mutableCopy];
            NSString *bundleID = [NSBundle bundleWithURL:url].bundleIdentifier;
            if (bundleID) entry[@"bundle_id"] = bundleID;
            if (png) entry[@"icon"] = [@"data:image/png;base64," stringByAppendingString:[png base64EncodedStringWithOptions:0]];
            [result addObject:entry];
        } else if (depth > 1) {
            NSNumber *directory, *symlink;
            [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
            [url getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];
            if (directory.boolValue && !symlink.boolValue) collectApplications(url, depth-1, result, seen);
        }
    }
}
char *tooki_applications(void) {
    @autoreleasepool {
        @try {
            NSMutableArray *apps = [NSMutableArray array];
            NSMutableSet *seen = [NSMutableSet set];
            for (NSString *folder in @[@"/Applications", @"/System/Applications", @"/System/Library/CoreServices/Applications", @"~/Applications"])
                collectApplications([NSURL fileURLWithPath:folder.stringByExpandingTildeInPath], 2, apps, seen);
            NSData *json = [NSJSONSerialization dataWithJSONObject:apps options:0 error:nil];
            return json ? strdup([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String) : NULL;
        } @catch (NSException *exception) { return NULL; }
    }
}
void tooki_applications_free(char *value) { free(value); }
char *tooki_application_trash(const char *path) {
    @autoreleasepool {
        @try {
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
            for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)
                if ([app.bundleURL.URLByResolvingSymlinksInPath isEqual:url.URLByResolvingSymlinksInPath])
                    return strdup("Quit this application before moving it to Trash.");
            NSError *error = nil;
            if (![NSFileManager.defaultManager trashItemAtURL:url resultingItemURL:nil error:&error])
                return strdup(error.localizedDescription.UTF8String ?: "Could not move application to Trash.");
            return NULL;
        } @catch (NSException *exception) { return strdup("Could not move application to Trash."); }
    }
}

char *tooki_application_bundle_id(const char *path) {
    @autoreleasepool {
        NSString *identifier = [NSBundle bundleWithPath:[NSString stringWithUTF8String:path]].bundleIdentifier;
        return identifier.length ? strdup(identifier.UTF8String) : NULL;
    }
}
