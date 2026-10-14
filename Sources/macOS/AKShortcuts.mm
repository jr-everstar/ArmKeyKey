#import "AKShortcuts.h"

@implementation AKShortcuts
+ (NSArray<NSString *> *)actions { return @[@"simplifiedOutput",@"fullWidthOutput",@"associatedPhrases"]; }
+ (NSString *)storageKey:(NSString *)action { return [@"shortcut." stringByAppendingString:action]; }
+ (NSDictionary *)defaultBinding:(NSString *)action {
    if([action isEqual:@"simplifiedOutput"])return @{@"keyCode":@5,@"modifiers":@(NSEventModifierFlagControl|NSEventModifierFlagCommand)};
    if([action isEqual:@"fullWidthOutput"])return @{@"keyCode":@49,@"modifiers":@(NSEventModifierFlagShift|NSEventModifierFlagCommand)};
    return @{};
}
+ (NSDictionary<NSNumber *,NSString *> *)keyNames {
    // Physical ANSI keys; matching is independent of typed/shifted characters.
    return @{@0:@"A",@1:@"S",@2:@"D",@3:@"F",@4:@"H",@5:@"G",@6:@"Z",@7:@"X",@8:@"C",@9:@"V",@11:@"B",@12:@"Q",@13:@"W",@14:@"E",@15:@"R",@16:@"Y",@17:@"T",@18:@"1",@19:@"2",@20:@"3",@21:@"4",@22:@"6",@23:@"5",@24:@"=",@25:@"9",@26:@"7",@27:@"−",@28:@"8",@29:@"0",@30:@"]",@31:@"O",@32:@"U",@33:@"[",@34:@"I",@35:@"P",@37:@"L",@38:@"J",@39:@"'",@40:@"K",@41:@";",@42:@"\\",@43:@",",@44:@"/",@45:@"N",@46:@"M",@47:@".",@49:@"空白鍵",@50:@"`"};
}
+ (NSUInteger)mask { return NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagCommand; }
+ (BOOL)validBinding:(NSDictionary *)binding {
    if(![binding isKindOfClass:NSDictionary.class])return NO;
    NSNumber *code=binding[@"keyCode"], *flags=binding[@"modifiers"];
    if(![code isKindOfClass:NSNumber.class] || ![flags isKindOfClass:NSNumber.class])return NO;
    if(code.doubleValue!=code.integerValue || flags.doubleValue!=flags.unsignedIntegerValue)return NO;
    NSUInteger mods=flags.unsignedIntegerValue;
    return [self keyNames][code]!=nil && (mods & ~[self mask])==0 && (mods & (NSEventModifierFlagControl|NSEventModifierFlagCommand))!=0;
}
+ (NSDictionary<NSString *, NSNumber *> *)bindingForAction:(NSString *)action {
    if(![[self actions] containsObject:action])return @{};
    id saved=[NSUserDefaults.standardUserDefaults objectForKey:[self storageKey:action]];
    if(!saved)return [self defaultBinding:action];
    // Empty or malformed saved preferences disable this binding, never grab typing.
    return [self validBinding:saved]?saved:@{};
}
+ (NSString *)displayForAction:(NSString *)action {
    NSDictionary *binding=[self bindingForAction:action];
    if(!binding.count)return @"無快捷鍵";
    NSUInteger mods=[binding[@"modifiers"] unsignedIntegerValue];
    NSMutableString *label=[NSMutableString new];
    if(mods & NSEventModifierFlagControl)[label appendString:@"⌃"];
    if(mods & NSEventModifierFlagOption)[label appendString:@"⌥"];
    if(mods & NSEventModifierFlagShift)[label appendString:@"⇧"];
    if(mods & NSEventModifierFlagCommand)[label appendString:@"⌘"];
    [label appendString:[self keyNames][binding[@"keyCode"]]];
    return label;
}
+ (NSString *)actionForEvent:(NSEvent *)event {
    if(event.type!=NSEventTypeKeyDown)return nil;
    NSUInteger mods=event.modifierFlags & [self mask];
    for(NSString *action in [self actions]){
        NSDictionary *binding=[self bindingForAction:action];
        if(binding.count && [binding[@"keyCode"] integerValue]==event.keyCode && [binding[@"modifiers"] unsignedIntegerValue]==mods)return action;
    }
    return nil;
}
+ (NSString *)setAction:(NSString *)action keyCode:(NSInteger)keyCode modifiers:(NSUInteger)modifiers {
    if(![[self actions] containsObject:action])return @"不支援的快捷鍵動作。";
    NSDictionary *binding=@{@"keyCode":@(keyCode),@"modifiers":@(modifiers & [self mask])};
    if(![self validBinding:binding])return @"請使用 Control 或 Command，配合英文字母、數字、標點或空白鍵；可加 Shift 或 Option。";
    for(NSString *other in [self actions]){
        if(![other isEqual:action] && [[self bindingForAction:other] isEqual:binding])return @"此組合已用於另一個 ArmKeyKey 功能，請先清除該設定或使用另一組合。";
    }
    [NSUserDefaults.standardUserDefaults setObject:binding forKey:[self storageKey:action]];
    return nil;
}
+ (void)clearAction:(NSString *)action {
    if([[self actions] containsObject:action])[NSUserDefaults.standardUserDefaults setObject:@{} forKey:[self storageKey:action]];
}
+ (void)restoreDefaults {
    for(NSString *action in [self actions])[NSUserDefaults.standardUserDefaults removeObjectForKey:[self storageKey:action]];
}
@end
