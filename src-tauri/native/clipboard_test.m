#define TOOKI_CLIPBOARD_TEST 1
#import "clipboard.m"
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
  NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  [pb clearContents];[pb setData:png forType:NSPasteboardTypePNG];
  NSDictionary *captured=capture(args);CHECK([captured[@"width"] intValue]>0);
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
  [NSFileManager.defaultManager removeItemAtPath:directory error:nil];[pb releaseGlobally];
  puts("Native capture, privacy skip, rich copy, image capture, Vision OCR, file capture, path copy, Open With discovery passed.");
 }
 return 0;
}
