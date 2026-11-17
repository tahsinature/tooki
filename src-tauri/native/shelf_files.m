#import <AppKit/AppKit.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

static NSString *pngURL(NSImage *image) {
    NSData *tiff = image.TIFFRepresentation;
    NSBitmapImageRep *bitmap = tiff ? [NSBitmapImageRep imageRepWithData:tiff] : nil;
    NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return data ? [@"data:image/png;base64," stringByAppendingString:[data base64EncodedStringWithOptions:0]] : nil;
}
// Called on a blocking worker. Quick Look completes on its own queue, never block AppKit.
char *tooki_shelf_thumbnail(const char *path) {
    @autoreleasepool {
        @try {
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
            QLThumbnailGenerationRequest *request = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:url size:CGSizeMake(128,128) scale:2 representationTypes:QLThumbnailGenerationRequestRepresentationTypeAll];
            dispatch_semaphore_t completed = dispatch_semaphore_create(0);
            __block NSString *result = nil;
            [QLThumbnailGenerator.sharedGenerator generateBestRepresentationForRequest:request completionHandler:^(QLThumbnailRepresentation *thumbnail, NSError *error) {
                (void)error;
                result = pngURL(thumbnail.NSImage);
                dispatch_semaphore_signal(completed);
            }];
            BOOL timedOut = dispatch_semaphore_wait(completed, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC)) != 0;
            if (timedOut) [QLThumbnailGenerator.sharedGenerator cancelRequest:request];
            if (!timedOut && result) return strdup(result.UTF8String);
            // Keep fallback separate from the asynchronous Quick Look result.
            __block NSString *icon = nil;
            dispatch_semaphore_t iconReady = dispatch_semaphore_create(0);
            void (^loadIcon)(void) = ^{
                @try { icon = pngURL([NSWorkspace.sharedWorkspace iconForFile:url.path]); }
                @catch (NSException *exception) { (void)exception; }
                dispatch_semaphore_signal(iconReady);
            };
            if (NSThread.isMainThread) loadIcon();
            else dispatch_async(dispatch_get_main_queue(), loadIcon);
            if (dispatch_semaphore_wait(iconReady, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC))) return NULL;
            return icon ? strdup(icon.UTF8String) : NULL;
        } @catch(NSException *exception) { return NULL; }
    }
}
// Explicit paste, not clipboard monitoring. Preserve image-before-link priority from Swift.
char *tooki_shelf_pasteboard(bool drag) {
    @autoreleasepool {
        @try {
            NSPasteboard *board = drag ? [NSPasteboard pasteboardWithName:NSPasteboardNameDrag] : NSPasteboard.generalPasteboard;
            NSArray *files = [board readObjectsForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}];
            NSMutableDictionary *result = [NSMutableDictionary dictionary];
            if (files.count) result[@"files"] = [files valueForKey:@"path"];
            else {
                NSData *png = [board dataForType:NSPasteboardTypePNG];
                if (!png) {
                    NSData *tiff = [board dataForType:NSPasteboardTypeTIFF];
                    if (tiff) png = [[NSBitmapImageRep imageRepWithData:tiff] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                }
                if (png.length) result[@"png"] = [png base64EncodedStringWithOptions:0];
                else {
                    NSString *link = [board stringForType:NSPasteboardTypeURL];
                    NSString *text = [board stringForType:NSPasteboardTypeString];
                    if (link.length && ([link hasPrefix:@"https://"] || [link hasPrefix:@"http://"])) result[@"url"] = link;
                    else if (text.length) result[@"text"] = text;
                }
            }
            NSData *json = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
            return strdup([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
        } @catch(NSException *exception) { return strdup("{}"); }
    }
}

// Tauri/Wry owns drag destination dispatch. Keep this adapter limited to AppKit data.
bool tooki_shelf_drag_has_files(void) {
    NSPasteboard *board=[NSPasteboard pasteboardWithName:NSPasteboardNameDrag];
    return [board canReadObjectForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}];
}
