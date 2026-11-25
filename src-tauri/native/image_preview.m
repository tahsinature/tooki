#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

// Read-only, bounded display preview. Never re-encode or replace the source file.
// ImageIO handles orientation and image formats that the webview cannot display.
id tooki_image_preview(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url,
        (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
    if (!source) return NSNull.null;
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    NSUInteger width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    NSUInteger orientation = [properties[(__bridge NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@1600
    });
    CFRelease(source);
    if (!image) return NSNull.null;
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef writer = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
    BOOL success = NO;
    if (writer) {
        CGImageDestinationAddImage(writer, image, NULL);
        success = CGImageDestinationFinalize(writer);
        CFRelease(writer);
    }
    CGImageRelease(image);
    if (!success) return NSNull.null;
    BOOL rotated = orientation >= 5 && orientation <= 8;
    return @{
        @"data": [@"data:image/png;base64," stringByAppendingString:[data base64EncodedStringWithOptions:0]],
        @"width": @(rotated ? height : width),
        @"height": @(rotated ? width : height)
    };
}
