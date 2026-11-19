// These tests use fixture mappings and temporary locks. They never remap keys or post events.
#import "hyper.m"
int main(void) {
  @autoreleasepool {
    NSString *error = nil;
    assert([parseMapping(@"(null)", &error) count] == 0 && !error);
    NSString *entry = @"({ HIDKeyboardModifierMappingSrc = 12; "
                      @"HIDKeyboardModifierMappingDst = 13; })";
    NSString *table = [NSString
        stringWithFormat:@"RegistryID Key Value\n100 UserKeyMapping %@\n101 "
                         @"UserKeyMapping (null)\n102 UserKeyMapping %@",
                         entry, entry];
    NSArray *mapping = parseMapping(table, &error);
    assert(mapping.count == 1 && !error);
    assert([mapping[0][@"HIDKeyboardModifierMappingDst"] intValue] == 13);
    assert([mapping[0][@"HIDKeyboardModifierMappingDst"] isKindOfClass:NSNumber.class]);
    assert([mapping[0][@"HIDKeyboardModifierMappingDst"] unsignedLongLongValue] == 13);
    NSArray *caps = parseMapping(@"({ HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771181; })", &error);
    assert([caps[0][@"HIDKeyboardModifierMappingSrc"] unsignedLongLongValue] == capsUsage);
    assert([caps[0][@"HIDKeyboardModifierMappingDst"] unsignedLongLongValue] == f18Usage);
    assert(normalizeMapping(@[@{@"HIDKeyboardModifierMappingSrc": @"30064771129", @"HIDKeyboardModifierMappingDst": @30064771181}], &error));
    assert(!normalizeMapping(@[@"invalid"], &error)); error = nil;
    assert(!normalizeMapping(@[@{@"HIDKeyboardModifierMappingSrc": NSNull.null, @"HIDKeyboardModifierMappingDst": @1}], &error)); error = nil;
    NSString *different =
        [table stringByAppendingString:
                   @"\n103 UserKeyMapping ({ HIDKeyboardModifierMappingSrc = "
                   @"12; HIDKeyboardModifierMappingDst = 14; })"];
    assert(parseMapping(different, &error) == nil && error);
    error = nil;
    assert(parseMapping(@"Unexpected output", &error) == nil && error);
    NSDictionary *owned = @{@"HIDKeyboardModifierMappingSrc": @(capsUsage), @"HIDKeyboardModifierMappingDst": @(f18Usage)};
    NSDictionary *foreign = @{@"HIDKeyboardModifierMappingSrc": @(capsUsage), @"HIDKeyboardModifierMappingDst": @42};
    NSDictionary *unrelated = @{@"HIDKeyboardModifierMappingSrc": @12, @"HIDKeyboardModifierMappingDst": @13};
    BOOL owns = NO;
    assert([restoredMapping(@[], @[owned, unrelated], &owns) isEqual:@[unrelated]] && owns);
    assert(([restoredMapping(@[], @[foreign, unrelated], &owns) isEqual:@[foreign, unrelated]] && !owns));
    assert([restoredMapping(@[], @[], &owns) count] == 0 && !owns);
    NSString *lock = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    mappingLocks = [NSMutableArray array];
    assert(acquireMappingLock(lock));
    assert(!acquireMappingLock(lock));
    releaseMappingLocks();
    mappingLocks = [NSMutableArray array];
    assert(acquireMappingLock(lock));
    releaseMappingLocks();
    [NSFileManager.defaultManager removeItemAtPath:lock error:nil];
    puts("Hyper Key parsing, recovery ownership and lock exclusion passed (no system changes).");
  }
}
