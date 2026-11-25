#define TOOKI_CLIPBOARD_TEST 1
#import "clipboard.m"
#import <ImageIO/ImageIO.h>
#define CHECK(test) if (!(test)) { fprintf(stderr,"Failed at line %d: %s\n",__LINE__,#test); return 1; }
int main(void) {
 @autoreleasepool {
  [NSApplication sharedApplication];
  NSString *directory=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
  NSDictionary *args=@{@"enabled":@YES,@"images":@YES,@"ignoredApps":@[],@"directory":directory};
  NSPasteboard *pb=clipboardBoard();
  CHECK(capture(args)==NSNull.null);
  [pb clearContents];[pb setString:@"Synthetic test note" forType:NSPasteboardTypeString];
  CHECK([capture(args)[@"text"] isEqual:@"Synthetic test note"]);
  CHECK(capture(args)==NSNull.null);
  [pb clearContents];[pb setString:@"secret" forType:NSPasteboardTypeString];[pb setString:@"" forType:@"org.nspasteboard.ConcealedType"];
  CHECK(capture(args)==NSNull.null);
  perform(@"copy",@{@"item":@{@"content":@"Restored rich text",@"html":[[@"<b>Rich</b>" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]},@"mode":@"original"});
  CHECK([[pb stringForType:NSPasteboardTypeString] isEqual:@"Restored rich text"]);
  CHECK([pb dataForType:NSPasteboardTypeHTML].length>0);
  CHECK(capture(args)==NSNull.null);
  NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(600,120)];
  [image lockFocus];[NSColor.whiteColor setFill];NSRectFill(NSMakeRect(0,0,600,120));
  [@"Tooki receipt 12345" drawAtPoint:NSMakePoint(24,40) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:36],NSForegroundColorAttributeName:NSColor.blackColor}];
  [image unlockFocus];
  NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
  // A nondefault encoding catches accidental decoding and re-encoding during capture.
  NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageInterlaced:@YES}];
  NSData *reencoded=[[NSBitmapImageRep imageRepWithData:png] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  CHECK(![png isEqualToData:reencoded]);
  [pb clearContents];[pb setData:png forType:NSPasteboardTypePNG];
  NSDictionary *captured=capture(args);CHECK([captured[@"width"] intValue]>0);
  CHECK([[NSData dataWithContentsOfFile:captured[@"image"]] isEqualToData:png]);
  CHECK([captured[@"bytes"] unsignedLongLongValue]==png.length);
  perform(@"copy",@{@"item":@{@"image":captured[@"image"]},@"mode":@"original"});
  CHECK([[pb dataForType:NSPasteboardTypePNG] isEqualToData:png]);
  [pb clearContents];[pb setData:image.TIFFRepresentation forType:NSPasteboardTypeTIFF];
  NSDictionary *converted=capture(args);
  NSData *convertedPNG=[NSData dataWithContentsOfFile:converted[@"image"]];
  CHECK([convertedPNG isEqualToData:[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]]);
  CHECK([converted[@"bytes"] unsignedLongLongValue]==convertedPNG.length);
  // File previews must honor orientation and bound decoding without changing
  // the source JPEG or advertising preview PNG bytes when copying the file.
  NSBitmapImageRep *large=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2400 pixelsHigh:1800 bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  memset(large.bitmapData, 180, large.bytesPerRow*large.pixelsHigh);
  NSMutableData *jpeg=[NSMutableData data];
  CGImageDestinationRef writer=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)jpeg,CFSTR("public.jpeg"),1,NULL);
  CHECK(writer != NULL);
  CGImageDestinationAddImage(writer,large.CGImage,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImagePropertyOrientation:@6});
  CHECK(CGImageDestinationFinalize(writer));CFRelease(writer);
  NSString *jpegPath=[directory stringByAppendingPathComponent:@"photo.jpg"];
  CHECK([jpeg writeToFile:jpegPath atomically:YES]);
  NSDictionary *filePreview=perform(@"imagePreview",@{@"path":jpegPath});
  CHECK([filePreview[@"width"] intValue]==1800 && [filePreview[@"height"] intValue]==2400);
  NSString *previewData=filePreview[@"data"];
  CHECK([previewData hasPrefix:@"data:image/png;base64,"]);
  NSData *previewPNG=[[NSData alloc] initWithBase64EncodedString:[previewData substringFromIndex:22] options:0];
  NSBitmapImageRep *previewBitmap=[NSBitmapImageRep imageRepWithData:previewPNG];
  CHECK(previewBitmap.pixelsWide==1200 && previewBitmap.pixelsHigh==1600);
  CHECK([[NSData dataWithContentsOfFile:jpegPath] isEqualToData:jpeg]);
  perform(@"copy",@{@"item":@{@"files":@[jpegPath]},@"mode":@"original"});
  CHECK(![pb.types containsObject:NSPasteboardTypePNG]);
  CHECK([[[pb readObjectsForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}] firstObject] isEqual:[NSURL fileURLWithPath:jpegPath]]);
  NSString *invalidPath=[directory stringByAppendingPathComponent:@"not-an-image.jpg"];
  CHECK([[@"ordinary text" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:invalidPath atomically:YES]);
  CHECK(perform(@"imagePreview",@{@"path":invalidPath})==NSNull.null);
  CHECK(perform(@"imagePreview",@{@"path":[directory stringByAppendingPathComponent:@"missing.jpg"]})==NSNull.null);
  NSString *recognized=perform(@"ocr",@{@"path":captured[@"image"]});
  CHECK([recognized isKindOfClass:NSString.class]);CHECK([recognized containsString:@"12345"]);
  NSArray *apps=perform(@"apps",@{@"path":captured[@"image"]});CHECK(apps.count>0);
  [pb clearContents];[pb writeObjects:@[[NSURL fileURLWithPath:captured[@"image"]]]];
  CHECK([capture(args)[@"files"] count]==1);
  perform(@"copy",@{@"item":@{@"image":captured[@"image"]},@"mode":@"paths"});
  CHECK([[pb stringForType:NSPasteboardTypeString] isEqual:captured[@"image"]]);
  CHECK(![pb.types containsObject:NSPasteboardTypePNG]);
  CHECK(capture(args)==NSNull.null);
  NSArray *paths=@[@"/tmp/a file.png",@"/tmp/second.txt"];
  perform(@"copy",@{@"item":@{@"files":paths,@"image":captured[@"image"]},@"mode":@"paths"});
  CHECK([[pb stringForType:NSPasteboardTypeString] isEqual:[paths componentsJoinedByString:@"\n"]]);
  CHECK(perform(@"copy",@{@"item":@{@"content":@"text only"},@"mode":@"paths"})[@"error"] != nil);
  CHECK([[pb stringForType:NSPasteboardTypeString] isEqual:[paths componentsJoinedByString:@"\n"]]);
  CHECK(tooki_clipboard_copy_expansion(@"Unicode ✓\nsecond line"));
  CHECK([[pb stringForType:NSPasteboardTypeString] isEqual:@"Unicode ✓\nsecond line"]);
  CHECK(capture(args)==NSNull.null);
  [NSFileManager.defaultManager removeItemAtPath:directory error:nil];[pb releaseGlobally];
  puts("Native capture, privacy skip, rich copy, image capture, Vision OCR, file capture, path copy, Open With discovery passed.");
 }
 return 0;
}
