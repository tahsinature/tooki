#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

// Matches Swift ImageConverter: one still image, orientation applied, metadata optional.
char *tooki_shelf_convert(const char *input) {
    @autoreleasepool { @try {
        NSDictionary *args=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:input] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSURL *sourceURL=[NSURL fileURLWithPath:args[@"source"]];
        NSURL *outputURL=[NSURL fileURLWithPath:args[@"output"]];
        NSString *format=@{@"jpeg":@"public.jpeg",@"png":@"public.png",@"heif":@"public.heic"}[args[@"format"]];
        if (!format) return strdup("Unsupported image format.");
        CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)sourceURL,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
        if (!source) return strdup("This file is not a readable image.");
        if (CGImageSourceGetCount(source)!=1) { CFRelease(source);return strdup("Animated or multi-page images cannot be converted."); }
        NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
        NSUInteger width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue],height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
        NSUInteger limit=[args[@"size"] unsignedIntegerValue];
        NSUInteger maxSize=limit?MIN(limit,MAX(width,height)):MAX(width,height);
        CGImageRef image=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@(maxSize)});
        CFRelease(source);
        if (!image) return strdup("Could not decode the image.");
        NSMutableDictionary *metadata=[args[@"metadata"] boolValue]?[properties mutableCopy]:[NSMutableDictionary dictionary];
        metadata[(__bridge NSString *)kCGImagePropertyOrientation]=@1;
        metadata[(__bridge NSString *)kCGImagePropertyPixelWidth]=@(CGImageGetWidth(image));
        metadata[(__bridge NSString *)kCGImagePropertyPixelHeight]=@(CGImageGetHeight(image));
        NSMutableDictionary *tiff=[metadata[(__bridge NSString *)kCGImagePropertyTIFFDictionary] mutableCopy];
        if(tiff){tiff[(__bridge NSString *)kCGImagePropertyTIFFOrientation]=@1;metadata[(__bridge NSString *)kCGImagePropertyTIFFDictionary]=tiff;}
        NSMutableDictionary *exif=[metadata[(__bridge NSString *)kCGImagePropertyExifDictionary] mutableCopy];
        if(exif){exif[(__bridge NSString *)kCGImagePropertyExifPixelXDimension]=@(CGImageGetWidth(image));exif[(__bridge NSString *)kCGImagePropertyExifPixelYDimension]=@(CGImageGetHeight(image));metadata[(__bridge NSString *)kCGImagePropertyExifDictionary]=exif;}
        metadata[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality]=@0.9;
        CGColorRef white=CGColorCreateGenericGray(1,1);
        metadata[(__bridge NSString *)kCGImageDestinationBackgroundColor]=(__bridge id)white;
        CGImageDestinationRef writer=CGImageDestinationCreateWithURL((__bridge CFURLRef)outputURL,(__bridge CFStringRef)format,1,NULL);
        BOOL success=NO;
        if(writer){CGImageDestinationAddImage(writer,image,(__bridge CFDictionaryRef)metadata);success=CGImageDestinationFinalize(writer);CFRelease(writer);}
        CFRelease(image);CGColorRelease(white);
        if(!success) return strdup("Could not encode the selected format.");
        CGImageSourceRef check=CGImageSourceCreateWithURL((__bridge CFURLRef)outputURL,NULL);
        success=check&&CGImageSourceGetStatus(check)==kCGImageStatusComplete;
        if(check)CFRelease(check);
        return success?NULL:strdup("The converted image failed validation.");
    } @catch(NSException *exception) {return strdup(exception.reason.UTF8String?:"Image conversion failed.");} }
}

char *tooki_shelf_validate_image(const char *path) {
    @autoreleasepool { @try {
        NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
        CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
        if(!source)return strdup("The conversion preview is not a readable image. Reload or convert again.");
        NSString *expected=@{@"jpg":@"public.jpeg",@"png":@"public.png",@"heic":@"public.heic"}[url.pathExtension.lowercaseString];
        BOOL valid=CGImageSourceGetStatus(source)==kCGImageStatusComplete && CGImageSourceGetCount(source)==1 && expected && CFEqual(CGImageSourceGetType(source),(__bridge CFStringRef)expected);
        CGImageRef image=valid?CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@64}):NULL;
        valid=valid&&image!=NULL;if(image)CFRelease(image);CFRelease(source);
        return valid?NULL:strdup("The preview is incomplete, or its format no longer matches its filename. Convert again.");
    } @catch(NSException *exception){return strdup(exception.reason.UTF8String?:"Image validation failed.");} }
}
