#import "shelf_files.m"
#define CHECK(test) if (!(test)) { fprintf(stderr, "Failed at line %d: %s\n", __LINE__, #test); return 1; }
int main(void) {
    @autoreleasepool {
        NSPasteboard *board = [NSPasteboard pasteboardWithUniqueName];
        [board setString:@"Dropped text ✓" forType:NSPasteboardTypeString];
        CHECK([readDropContent(board)[@"text"] isEqual:@"Dropped text ✓"]);
        [board clearContents];
        [board setString:@"https://example.com/image" forType:NSPasteboardTypeURL];
        [board setString:@"caption" forType:NSPasteboardTypeString];
        CHECK([readDropContent(board)[@"url"] isEqual:@"https://example.com/image"]);
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:3 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        memset(bitmap.bitmapData, 255, bitmap.bytesPerRow * bitmap.pixelsHigh);
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageInterlaced:@YES}];
        [board setData:png forType:NSPasteboardTypePNG];
        NSDictionary *image = readDropContent(board);
        CHECK([image[@"png"] isEqual:[png base64EncodedStringWithOptions:0]]);
        CHECK([image[@"width"] intValue] == 2 && [image[@"height"] intValue] == 3);
        CHECK(!image[@"url"] && !image[@"text"]);
        [board clearContents];
        [board setData:bitmap.TIFFRepresentation forType:NSPasteboardTypeTIFF];
        NSData *converted = [[NSData alloc] initWithBase64EncodedString:readDropContent(board)[@"png"] options:0];
        CHECK([NSBitmapImageRep imageRepWithData:converted].pixelsWide == 2);
        [board clearContents];
        [board writeObjects:@[[NSURL fileURLWithPath:@"/tmp/drop-example.jpg"], [NSURL fileURLWithPath:@"/tmp/drop-folder"]]];
        [board setData:png forType:NSPasteboardTypePNG];
        NSDictionary *files = readDropContent(board);
        CHECK([files[@"files"] count] == 2);
        CHECK(!files[@"png"]);
        [board clearContents];
        CHECK(!readDropContent(board)[@"files"] && !readDropContent(board)[@"png"] && !readDropContent(board)[@"text"]);
        [board releaseGlobally];
        puts("Native drop reader: files, PNG preservation, TIFF fallback, text, links, and priority passed.");
    }
    return 0;
}
