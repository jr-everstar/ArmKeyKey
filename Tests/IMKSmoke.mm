#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>
#import "AKInputController.h"
#import "AKShortcuts.h"
#import "ArmKeyKey-Swift.h"
static NSMutableArray *featureNotifications;
@implementation AKFeatureNotifications
+ (void)showFeature:(NSString *)key enabled:(BOOL)enabled {
    if(!featureNotifications)featureNotifications=[NSMutableArray new];
    [featureNotifications addObject:@[key,@(enabled)]];
}
@end
static int settingsOpens=0, aboutOpens=0, licenseOpens=0, updateOpens=0;
@implementation AKSettings
+ (void)showAbout { ++aboutOpens; }
+ (void)checkUpdates { ++updateOpens; }
+ (void)showLicenses { ++licenseOpens; }
+ (void)show { ++settingsOpens; }
@end
@interface TestClient : NSObject
@property NSString *marked;
@property NSRange selection;
@property NSMutableString *committed;
@end
@implementation TestClient
- (instancetype)init {if((self=[super init])){_marked=@"";_committed=[NSMutableString new];}return self;}
- (NSString*)bundleIdentifier {return @"org.armkeykey.testclient";}
- (NSInteger)windowLevel {return NSNormalWindowLevel;}
- (void)setMarkedText:(id)text selectionRange:(NSRange)selection replacementRange:(NSRange)replacement {_marked=[text isKindOfClass:NSAttributedString.class]?[text string]:text;_selection=selection;}
- (void)insertText:(id)text replacementRange:(NSRange)replacement {[_committed appendString:[text isKindOfClass:NSAttributedString.class]?[text string]:text];_marked=@"";}
- (NSDictionary*)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRect*)rect {*rect=NSMakeRect(100,500,1,20);return @{};}
- (NSRange)selectedRange {return NSMakeRange(0,0);}
- (NSRange)markedRange {return _marked.length?NSMakeRange(0,_marked.length):NSMakeRange(NSNotFound,0);}
@end
static void check(BOOL condition,const char*message){if(!condition){fprintf(stderr,"FAIL native: %s\n",message);exit(1);}}
static BOOL send(AKInputController *controller,TestClient *client,NSString *text,unsigned short code,NSUInteger flags=0){
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:0 context:nil characters:text charactersIgnoringModifiers:text isARepeat:NO keyCode:code];
    return [controller handleEvent:event client:client];
}
int main(int argc,char**argv){@autoreleasepool{
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    // Explicit test-domain values: registerDefaults does not override a previous run's saved mode.
    NSDictionary *initial=@{@"mode":@"simplex",@"simplexLearning":@NO,@"cangjieLearning":@NO,@"associatedPhrases":@NO,@"extendedCharacters":@NO,@"phraseModifier":@8,@"simplifiedOutput":@NO,@"fullWidthOutput":@NO};
    for(NSString *key in initial)[NSUserDefaults.standardUserDefaults setObject:initial[key] forKey:key];
    [AKShortcuts restoreDefaults];
    // Unit-test adapter methods only: real IMK initialization requires its remote client proxy.
    TestClient *client=[TestClient new];
    AKInputController *controller=[[AKInputController alloc]init];
    check(controller!=nil,"controller construction");[controller activateServer:client];
    NSMenu *menu=[controller menu];
    for(NSString *title in @[@"關於 ArmKeyKey…",@"版權資訊…"]){
        NSMenuItem *item=[menu itemWithTitle:title];
        check(item!=nil && item.target==controller,"informational menu entry exists and targets controller");
        check([NSApp sendAction:item.action to:item.target from:item],"informational menu action dispatch");
    }
    NSMenuItem *updateItem=[menu itemWithTitle:@"檢查更新…"];
    check(updateItem!=nil && [NSApp sendAction:updateItem.action to:updateItem.target from:updateItem] && updateOpens==1,"update menu opens update check");
    check(aboutOpens==1 && licenseOpens==1 && settingsOpens==0,"menu opens correct settings destination");

    check(send(controller,client,@"a",0),"first key consumed");check([client.marked isEqual:@"日"],"marked reading");
    check(send(controller,client,@"a",0),"automatic Simplex composition");
    check(send(controller,client,@"2",19),"candidate selection");check(client.committed.length>0&&client.marked.length==0,"commit clears marked text");
    NSString *first=[client.committed copy];[controller commitComposition:client];[controller deactivateServer:client];check([client.committed isEqual:first],"no duplicate commit at deactivate");
    [controller activateServer:client];send(controller,client,@"a",0);check(!send(controller,client,@"c",8,NSEventModifierFlagCommand),"host shortcut passes");check(client.marked.length==0,"shortcut clears reading");
    send(controller,client,@"a",0);send(controller,client,@"a",0);[controller commitComposition:client];NSUInteger count=client.committed.length;[controller commitComposition:client];check(client.committed.length==count,"forced commit idempotent");
    send(controller,client,@"a",0);send(controller,client,@"\033",53);check(client.marked.length==0,"escape clears");
    check(!send(controller,client,[NSString stringWithFormat:@"%C",(unichar)NSF1FunctionKey],122),"function key passes when idle");
    [controller deactivateServer:client];
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"associatedPhrases"];
    [controller activateServer:client];
    send(controller,client,@"h",4);send(controller,client,@"i",34);
    if(argc>1){
        NSWindow *panel=nil;for(NSWindow *window in NSApp.windows)if([window isKindOfClass:NSPanel.class] && window.visible)panel=window;
        check(panel!=nil,"candidate panel visible");
        NSView *view=panel.contentView;NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
        [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
    }
    send(controller,client,@"7",26);
    if(argc>1){
        for(NSWindow *panel in NSApp.windows)if([panel isKindOfClass:NSPanel.class] && panel.visible){
            NSView *view=panel.contentView;NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
            NSString *path=[[NSString stringWithUTF8String:argv[1]] stringByAppendingString:@"-phrases.png"];
            [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:path atomically:YES];
        }
    }
    NSString *before=[client.committed copy];
    [controller commitComposition:client];check([client.committed isEqual:before],"focus change must not accept a suggestion");
    send(controller,client,@"h",4);send(controller,client,@"i",34);send(controller,client,@"7",26);
    before=[client.committed copy];send(controller,client,@"!",18,NSEventModifierFlagShift);
    check([client.committed isEqual:[before stringByAppendingString:@"們"]],"native phrase appends suffix once");
    [controller deactivateServer:client];
    NSArray *modifiers=@[@8,@4,@2,@16,@0];
    NSUInteger flags[]={NSEventModifierFlagShift,NSEventModifierFlagControl,NSEventModifierFlagOption,NSEventModifierFlagCommand,0};
    NSArray *characters=@[@"!",@"1",@"¡",@"1",@"1"];
    for(NSUInteger i=0;i<modifiers.count;i++){
        [NSUserDefaults.standardUserDefaults setObject:modifiers[i] forKey:@"phraseModifier"];
        [controller activateServer:client];
        send(controller,client,@"h",4);send(controller,client,@"i",34);send(controller,client,@"7",26);
        before=[client.committed copy];
        check(send(controller,client,@" ",49,flags[i]),"native configured paging");
        check([client.committed isEqual:before],"paging never commits");
        send(controller,client,@"",116); // Return to first page with Page Up.
        check(send(controller,client,characters[i],18,flags[i]),"native modified number consumed");
        check([client.committed isEqual:[before stringByAppendingString:@"們"]],"native modified number selects suffix");
        send(controller,client,@"h",4);send(controller,client,@"i",34);send(controller,client,@"7",26);
        before=[client.committed copy];
        check(!send(controller,client,@"1",18,flags[i]?0:NSEventModifierFlagShift),"native wrong chord passes through");
        check([client.committed isEqual:before],"native wrong chord does not commit");
        [controller deactivateServer:client];
    }
    [NSUserDefaults.standardUserDefaults setObject:@"jyutping" forKey:@"mode"];
    [controller activateServer:client];
    for(NSString *letter in @[@"n",@"e",@"i",@"5",@"h",@"o",@"u",@"2"])send(controller,client,letter,0);
    check([client.marked isEqual:@"nei5hou2"],"native tone reading");
    send(controller,client,@" ",49);before=[client.committed copy];send(controller,client,@"1",18);
    check([client.committed isEqual:[before stringByAppendingString:@"你好"]] && !client.marked.length,"native Jyutping phrase commit");
    before=[client.committed copy];[controller deactivateServer:client];check([client.committed isEqual:before],"native Jyutping no automatic associated commit");
    [NSUserDefaults.standardUserDefaults setObject:@"simplex" forKey:@"mode"];
    [NSUserDefaults.standardUserDefaults setInteger:8 forKey:@"phraseModifier"];
    [controller activateServer:client];
    NSUInteger scriptChord=NSEventModifierFlagControl|NSEventModifierFlagCommand;
    NSUInteger widthChord=NSEventModifierFlagShift|NSEventModifierFlagCommand;
    send(controller,client,@"h",4);send(controller,client,@"i",34);
    before=[client.committed copy];
    check(send(controller,client,@"g",5,scriptChord),"script toggle consumed during candidates");
    check([client.committed isEqual:before],"toggle does not commit candidate");
    send(controller,client,@"7",26);
    before=[client.committed copy];
    send(controller,client,@"!",18,NSEventModifierFlagShift);
    check([client.committed isEqual:[before stringByAppendingString:@"们"]],"simplified associated suffix");
    before=[client.committed copy];
    send(controller,client,@"g",5,scriptChord);
    check([client.committed isEqual:before],"toggle does not duplicate previous commit");
    send(controller,client,@"h",4);send(controller,client,@"i",34);send(controller,client,@"7",26);
    before=[client.committed copy];send(controller,client,@"!",18,NSEventModifierFlagShift);
    check([client.committed isEqual:[before stringByAppendingString:@"們"]],"switch back to traditional");
    [controller deactivateServer:client];
    [controller activateServer:client];
    check(send(controller,client,@" ",49,widthChord),"width toggle consumed");
    before=[client.committed copy];
    send(controller,client,@"A",0,NSEventModifierFlagShift);
    send(controller,client,@"1",18);
    send(controller,client,@" ",49);
    check([client.committed isEqual:[before stringByAppendingString:@"ａ１　"]],"fullwidth letter digit space");
    before=[client.committed copy];
    check(!send(controller,client,@"c",8,NSEventModifierFlagCommand),"fullwidth preserves host shortcut");
    check([client.committed isEqual:before],"host shortcut inserts nothing");
    send(controller,client,@"a",0);send(controller,client,@"a",0);send(controller,client,@"2",19);
    check(client.committed.length>before.length && !client.marked.length,"fullwidth retains Chinese composition and selection");
    [controller deactivateServer:client];[controller activateServer:client];
    before=[client.committed copy];send(controller,client,@"B",11,NSEventModifierFlagShift);
    check([client.committed isEqual:[before stringByAppendingString:@"ｂ"]],"width persists across activation");
    send(controller,client,@" ",49,widthChord);
    before=[client.committed copy];send(controller,client,@"B",11,NSEventModifierFlagShift);
    check([client.committed isEqual:[before stringByAppendingString:@"b"]],"halfwidth output restored");
    [controller deactivateServer:client];
    check([featureNotifications isEqual:@[@[@"simplifiedOutput",@YES],@[@"simplifiedOutput",@NO],@[@"fullWidthOutput",@YES],@[@"fullWidthOutput",@NO]]],"shortcut notifications report each enabled and disabled state");
    [controller activateServer:client];
    NSEvent *repeat=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:widthChord timestamp:0 windowNumber:0 context:nil characters:@" " charactersIgnoringModifiers:@" " isARepeat:YES keyCode:49];
    check([controller handleEvent:repeat client:client] && featureNotifications.count==4,"holding shortcut never repeats notification or toggle");
    check(![NSUserDefaults.standardUserDefaults boolForKey:@"fullWidthOutput"],"repeat preserves mode");
    [controller deactivateServer:client];
    // InputMethodKit can dispatch registered key equivalents via its menu action,
    // bypassing handleEvent. Exercise both plain and IMK-wrapped menu senders.
    NSMenu *outputMenu=[controller menu];
    for(NSString *key in @[@"simplifiedOutput",@"fullWidthOutput"]){
        NSMenuItem *outputItem=nil;
        for(NSMenuItem *item in outputMenu.itemArray)if([item.representedObject isEqual:key])outputItem=item;
        check(outputItem!=nil,"output menu shortcut exists");
        for(id sender in @[outputItem,@{kIMKCommandMenuItemName:outputItem}]){
            BOOL expected=![NSUserDefaults.standardUserDefaults boolForKey:key];
            NSUInteger previousCount=featureNotifications.count;
            [NSApp sendAction:outputItem.action to:outputItem.target from:sender];
            check([NSUserDefaults.standardUserDefaults boolForKey:key]==expected,"menu shortcut toggles output");
            check(featureNotifications.count==previousCount+1 && [featureNotifications.lastObject isEqual:@[key,@(expected)]],"menu shortcut emits exactly one matching notification");
        }
    }
    // Configurable shortcuts must persist, replace old chords and never steal plain typing.
    check([AKShortcuts bindingForAction:@"associatedPhrases"].count==0,"phrase toggle has no default shortcut");
    check([AKShortcuts setAction:@"associatedPhrases" keyCode:5 modifiers:scriptChord]!=nil,"reject another action default chord");
    check([AKShortcuts setAction:@"simplifiedOutput" keyCode:0 modifiers:0]!=nil,"reject bare typing key");
    check([AKShortcuts setAction:@"simplifiedOutput" keyCode:0 modifiers:NSEventModifierFlagShift]!=nil,"reject shift-only typing key");
    check([AKShortcuts setAction:@"simplifiedOutput" keyCode:55 modifiers:scriptChord]!=nil,"reject modifier-only key");
    check([AKShortcuts setAction:@"simplifiedOutput" keyCode:15 modifiers:scriptChord]==nil,"remap script shortcut");
    check([[NSUserDefaults.standardUserDefaults dictionaryForKey:@"shortcut.simplifiedOutput"][@"keyCode"] integerValue]==15,"persist custom binding");
    [controller activateServer:client];
    BOOL oldScript=[NSUserDefaults.standardUserDefaults boolForKey:@"simplifiedOutput"];
    check(!send(controller,client,@"g",5,scriptChord),"old chord passes to host after remap");
    check([NSUserDefaults.standardUserDefaults boolForKey:@"simplifiedOutput"]==oldScript,"old chord cannot toggle");
    check(send(controller,client,@"r",15,scriptChord|NSEventModifierFlagCapsLock),"custom chord ignores caps lock state");
    check([NSUserDefaults.standardUserDefaults boolForKey:@"simplifiedOutput"]!=oldScript,"custom chord toggles");
    NSUInteger notificationsBefore=featureNotifications.count;
    check(!send(controller,client,@"R",15,scriptChord|NSEventModifierFlagShift),"extra modifier does not match");
    check(featureNotifications.count==notificationsBefore,"unmatched chord produces no notification");
    [controller deactivateServer:client];[controller activateServer:client];
    check(send(controller,client,@"r",15,scriptChord),"custom binding survives controller activation");
    [AKShortcuts clearAction:@"simplifiedOutput"];
    check([AKShortcuts bindingForAction:@"simplifiedOutput"].count==0 && !send(controller,client,@"r",15,scriptChord),"clear disables custom shortcut");
    check(!send(controller,client,@"g",5,scriptChord),"clear does not restore default implicitly");
    check([AKShortcuts setAction:@"fullWidthOutput" keyCode:17 modifiers:scriptChord]==nil,"remap width shortcut");
    BOOL oldWidth=[NSUserDefaults.standardUserDefaults boolForKey:@"fullWidthOutput"];
    check(!send(controller,client,@" ",49,widthChord),"old width shortcut passes through");
    check(send(controller,client,@"t",17,scriptChord) && [NSUserDefaults.standardUserDefaults boolForKey:@"fullWidthOutput"]!=oldWidth,"new width shortcut toggles");
    send(controller,client,@"t",17,scriptChord);
    check([AKShortcuts setAction:@"associatedPhrases" keyCode:35 modifiers:scriptChord]==nil,"assign phrase toggle shortcut");
    BOOL oldPhrases=[NSUserDefaults.standardUserDefaults boolForKey:@"associatedPhrases"];
    NSInteger generationBefore=[NSUserDefaults.standardUserDefaults integerForKey:@"dataGeneration"];
    notificationsBefore=featureNotifications.count;
    check(send(controller,client,@"p",35,scriptChord),"phrase shortcut consumed");
    check([NSUserDefaults.standardUserDefaults boolForKey:@"associatedPhrases"]!=oldPhrases,"phrase shortcut changes preference");
    check([NSUserDefaults.standardUserDefaults integerForKey:@"dataGeneration"]==generationBefore+1,"phrase toggle invalidates other controllers");
    check(featureNotifications.count==notificationsBefore+1 && [featureNotifications.lastObject isEqual:@[@"associatedPhrases",@(!oldPhrases)]],"phrase feedback matches state");
    NSEvent *phraseRepeat=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:scriptChord timestamp:0 windowNumber:0 context:nil characters:@"p" charactersIgnoringModifiers:@"p" isARepeat:YES keyCode:35];
    check([controller handleEvent:phraseRepeat client:client] && featureNotifications.count==notificationsBefore+1,"held phrase shortcut toggles once");
    NSMenu *customMenu=[controller menu];
    check([customMenu itemWithTitle:@"聯想字（⌃⌘P）"]!=nil,"menu displays custom phrase binding");
    for(NSMenuItem *item in customMenu.itemArray)if([item.representedObject isEqual:@"fullWidthOutput"]){
        check([item.title containsString:@"⌃⌘T"] && !item.keyEquivalent.length,"menu displays physical chord without a second shortcut dispatcher");
    }
    [AKShortcuts clearAction:@"associatedPhrases"];
    check(!send(controller,client,@"p",35,scriptChord),"cleared phrase shortcut passes through");
    [NSUserDefaults.standardUserDefaults setObject:@{@"keyCode":@0,@"modifiers":@0} forKey:@"shortcut.simplifiedOutput"];
    check([AKShortcuts bindingForAction:@"simplifiedOutput"].count==0,"invalid saved plain-key binding disabled");
    [NSUserDefaults.standardUserDefaults setObject:@"bad" forKey:@"shortcut.fullWidthOutput"];
    check([AKShortcuts bindingForAction:@"fullWidthOutput"].count==0,"malformed saved binding disabled");
    [AKShortcuts restoreDefaults];
    check([[AKShortcuts bindingForAction:@"simplifiedOutput"][@"keyCode"] integerValue]==5 && [[AKShortcuts bindingForAction:@"fullWidthOutput"][@"keyCode"] integerValue]==49 && ![AKShortcuts bindingForAction:@"associatedPhrases"].count,"restore all original defaults");
    [controller deactivateServer:client];
    // New modes use the same controller and panel without changing system input sources.
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"smartZhuyinLearning"];
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"cangjie5Learning"];
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"associatedPhrases"];
    for(NSString *mode in @[@"cangjie5",@"zhuyin",@"smartZhuyin"]){
        [NSUserDefaults.standardUserDefaults setObject:mode forKey:@"mode"];
        [controller activateServer:client];before=[client.committed copy];
        NSString *keys=[mode isEqual:@"cangjie5"]?@"mwsl ":@"su3";
        for(NSUInteger n=0;n<keys.length;n++)send(controller,client,[keys substringWithRange:NSMakeRange(n,1)],0);
        if([mode isEqual:@"smartZhuyin"]){
            check(client.marked.length>0 && [client.committed isEqual:before],"smart marked text before commit");
            for(NSString *letter in @[@"c",@"l",@"3"])send(controller,client,letter,0);
            check([client.marked isEqual:@"你好"],"native smart phrase");
            send(controller,client,@"",123);
            check(client.selection.location==1 && client.selection.length==0,"native middle caret uses UTF16");
            send(controller,client,@"",125);check(client.selection.length>0,"native candidate span");
            send(controller,client,@"1",18);
            check([client.committed isEqual:before],"native smart choice remains marked");
        }
        [controller commitComposition:client];
        check(client.committed.length>before.length && client.marked.length==0,"new mode forced commit");
        before=[client.committed copy];[controller deactivateServer:client];
        check([client.committed isEqual:before],"new mode idempotent deactivate");
    }
    [NSUserDefaults.standardUserDefaults setObject:@"smartZhuyin" forKey:@"mode"];
    [controller activateServer:client];
    for(NSString *letter in @[@"s",@"u",@"3"])send(controller,client,letter,0);
    send(controller,client,@"",125);send(controller,client,@"",121);send(controller,client,@"4",21);
    check([client.marked isEqual:@"𦗚"] && client.selection.location==2,"supplementary character caret uses two UTF16 units");
    for(NSString *letter in @[@"c",@"l",@"3"])send(controller,client,letter,0);
    send(controller,client,@"",123);
    check(client.selection.location==2,"sentence caret after supplementary character");
    [controller deactivateServer:client];
    [NSUserDefaults.standardUserDefaults setObject:@"simplex" forKey:@"mode"];
    // Exercise preference changes between panels, including enlarged text and scaled hit targets.
    for(NSString *style in @[@"everstar",@"yahoo"]){
        for(NSNumber *scale in @[@0.8,@1.0,@1.6]){
            [NSUserDefaults.standardUserDefaults setObject:style forKey:@"candidateStyle"];
            [NSUserDefaults.standardUserDefaults setObject:scale forKey:@"candidateScale"];
            [NSUserDefaults.standardUserDefaults setDouble:28 forKey:@"candidateFontSize"];
            [NSUserDefaults.standardUserDefaults setObject:@"123456" forKey:@"candidateBackground"];
            [NSUserDefaults.standardUserDefaults setObject:@"FFCC00" forKey:@"candidateHighlight"];
            [controller activateServer:client];send(controller,client,@"a",0);send(controller,client,@"a",0);
            NSPanel *panel=nil;
            for(NSWindow *window in NSApp.windows)if([window isKindOfClass:NSPanel.class] && window.visible)panel=(NSPanel *)window;
            check(panel!=nil,"custom appearance panel visible");
            NSView *view=panel.contentView;
            check(fabs(view.frame.size.height/view.bounds.size.height-scale.doubleValue)<0.01,"list scale preserves logical layout");
            NSButton *choice=nil;
            for(NSView *child in view.subviews)if([NSStringFromClass(child.class) isEqual:@"AKCandidateButton"]){choice=(NSButton *)child;break;}
            check(choice && choice.frame.size.height==36,"large text expands row height");
            NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
            before=[client.committed copy];[choice performClick:nil];
            check(client.committed.length>before.length,"scaled candidate button still commits");
            [controller deactivateServer:client];
        }
    }
    puts("PASS native InputMethodKit controller with mock text client: marked text, selection, shortcuts, cancellation, lifecycle");
}}
