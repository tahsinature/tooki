#import <AppKit/AppKit.h>
typedef void (*ShelfDragCallback)(void *,bool);
@interface TookiShelfDragSource:NSObject<NSDraggingSource>
@property(nonatomic,assign) ShelfDragCallback callback;
@property(nonatomic,assign) void *context;
@end
static TookiShelfDragSource *activeShelfDrag;
@implementation TookiShelfDragSource
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    (void)session;return context==NSDraggingContextOutsideApplication?(NSDragOperationCopy|NSDragOperationMove|NSDragOperationGeneric):NSDragOperationNone;
}
- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)point operation:(NSDragOperation)operation {
    (void)session;(void)point;
    ShelfDragCallback callback=self.callback;void *context=self.context;
    activeShelfDrag=nil;
    if(callback)callback(context,operation!=NSDragOperationNone);
}
@end
bool tooki_shelf_drag(void *nativeWindow,const char *input,void *context,ShelfDragCallback callback){
    @try{
        if(activeShelfDrag)return false;
        NSWindow *window=(__bridge NSWindow *)nativeWindow;
        NSEvent *event=NSApp.currentEvent;
        if(!window||!event)return false;
        NSArray *items=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:input] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSMutableArray *dragged=[NSMutableArray array];
        NSPoint point=[window.contentView convertPoint:[window convertPointFromScreen:NSEvent.mouseLocation] fromView:nil];
        NSUInteger index=0;
        for(NSDictionary *item in items){
            NSString *path=item[@"path"];
            if(![NSFileManager.defaultManager fileExistsAtPath:path])return false;
            NSURL *url=[NSURL fileURLWithPath:path];
            id<NSPasteboardWriting> writer=url;
            if([item[@"text"] isKindOfClass:NSString.class]){
                NSPasteboardItem *content=[NSPasteboardItem new];
                [content setString:url.absoluteString forType:NSPasteboardTypeFileURL];
                [content setString:item[@"text"] forType:NSPasteboardTypeString];
                if([item[@"isLink"] boolValue])[content setString:item[@"text"] forType:NSPasteboardTypeURL];
                writer=content;
            }
            NSDraggingItem *drag=[[NSDraggingItem alloc]initWithPasteboardWriter:writer];
            NSImage *icon=[NSWorkspace.sharedWorkspace iconForFile:path];
            [drag setDraggingFrame:NSMakeRect(point.x-24,point.y-24,48,48) contents:index++==0?icon:nil];
            [dragged addObject:drag];
        }
        if(!dragged.count)return false;
        activeShelfDrag=[TookiShelfDragSource new];activeShelfDrag.context=context;activeShelfDrag.callback=callback;
        [window.contentView beginDraggingSessionWithItems:dragged event:event source:activeShelfDrag];return true;
    }@catch(NSException *exception){activeShelfDrag=nil;return false;}
}
