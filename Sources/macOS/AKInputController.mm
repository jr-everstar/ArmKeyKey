#import "AKInputController.h"
#import <UserNotifications/UserNotifications.h>
#import <CoreText/CoreText.h>
#import "ArmKeyKey-Swift.h"
#include "Engine.hpp"
#include <memory>
static NSString *L(NSString *key) { NSBundle *chinese=[NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"zh-Hant" ofType:@"lproj"]]; return [chinese localizedStringForKey:key value:key table:nil]; }
static NSString *S(const std::string& text) {return [NSString stringWithUTF8String:text.c_str()] ?: @"";}
// Share the same font for candidate drawing and panel width measurement.
static NSFont *CandidateFont() {
    double value=[NSUserDefaults.standardUserDefaults doubleForKey:@"candidateFontSize"];
    CGFloat size=isfinite(value) && value>0?MIN(28,MAX(12,value)):17;
    NSFont *base=[NSFont fontWithName:@"NotoSansTC-Regular" size:size]
        ?: [NSFont fontWithName:@"NotoSansTC-Thin_Regular" size:size]
        ?: [NSFont systemFontOfSize:size];
    NSFontDescriptor *descriptor=[base.fontDescriptor fontDescriptorByAddingAttributes:@{
        NSFontCascadeListAttribute:@[[NSFontDescriptor fontDescriptorWithName:@"PingFangTC-Regular" size:size]]
    }];
    return [NSFont fontWithDescriptor:descriptor size:size] ?: base;
}
// Convert output only; dictionary identity and learning remain in the original script.
static NSString *OutputText(NSString *text) {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    if([defaults boolForKey:@"simplifiedOutput"])
        text=[text stringByApplyingTransform:@"Traditional-Simplified" reverse:NO] ?: text;
    if([defaults boolForKey:@"fullWidthOutput"]){
        NSMutableString *result=[NSMutableString new];
        for(NSUInteger i=0;i<text.length;i++){
            unichar c=[text characterAtIndex:i];
            if(c==0x20)c=0x3000;
            else if(c>=0x21 && c<=0x7e)c+=0xfee0;
            [result appendFormat:@"%C",c];
        }
        text=result;
    }
    return text;
}
// Brand palette sampled from the supplied Everstar logo (sRGB).
static NSColor *EverstarCyan() { return [NSColor colorWithSRGBRed:0 green:215.0/255 blue:230.0/255 alpha:1]; }
static NSColor *EverstarCharcoal() { return [NSColor colorWithSRGBRed:77.0/255 green:77.0/255 blue:77.0/255 alpha:1]; }
static NSColor *CandidateColor(NSString *key, NSColor *fallback) {
    NSString *hex=[NSUserDefaults.standardUserDefaults stringForKey:key];
    if(hex.length!=6)return fallback;
    unsigned int rgb=0;
    NSScanner *scanner=[NSScanner scannerWithString:hex];
    if(![scanner scanHexInt:&rgb] || !scanner.isAtEnd)return fallback;
    return [NSColor colorWithSRGBRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1];
}
@interface AKCandidatePanel : NSPanel
@end
@implementation AKCandidatePanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end
@interface AKCandidateBackground : NSView
@property BOOL everstar;
@end
@implementation AKCandidateBackground
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0.5,0.5) xRadius:11 yRadius:11];
    [CandidateColor(@"candidateBackground",self.everstar?EverstarCharcoal():NSColor.blackColor) setFill];[shape fill];
    [CandidateColor(@"candidateAccent",self.everstar?EverstarCyan():[NSColor colorWithWhite:0.8 alpha:1]) setStroke];[shape stroke];
}
@end
@interface AKCandidateButton : NSButton
@property BOOL selectedCandidate;
@property BOOL everstar;
@property NSInteger choiceNumber;
@end
// Center visible glyphs independently of the font's ascender and line spacing.
static void DrawCandidateText(NSString *text, NSFont *font, NSColor *color,
                              NSRect rect, BOOL centered, BOOL flipped) {
    NSAttributedString *attributed=[[NSAttributedString alloc] initWithString:text
        attributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
    CTLineRef line=CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    CGRect ink=CTLineGetBoundsWithOptions(line,kCTLineBoundsUseGlyphPathBounds);
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGContextTranslateCTM(context,NSMinX(rect),NSMidY(rect));
    if(flipped)CGContextScaleCTM(context,1,-1);
    CGContextSetTextMatrix(context,CGAffineTransformIdentity);
    CGFloat x=centered?(NSWidth(rect)-ink.size.width)/2-ink.origin.x:0;
    CGContextSetTextPosition(context,x,-CGRectGetMidY(ink));
    CTLineDraw(line,context);
    CGContextRestoreGState(context);
    CFRelease(line);
}
@implementation AKCandidateButton
- (void)drawRect:(NSRect)dirtyRect {
    if(self.selectedCandidate){[CandidateColor(@"candidateHighlight",self.everstar?EverstarCyan():[NSColor colorWithCalibratedRed:0.48 green:0 blue:0.48 alpha:1]) setFill];NSRectFill(self.bounds);}
    if(self.choiceNumber){
        NSRect badge=NSMakeRect(3,NSMidY(self.bounds)-8,16,16);
        [CandidateColor(@"candidateBackground",self.everstar?EverstarCharcoal():NSColor.blackColor)setFill];[[NSBezierPath bezierPathWithOvalInRect:badge]fill];
        NSString *number=[NSString stringWithFormat:@"%ld",(long)self.choiceNumber];
        DrawCandidateText(number,[NSFont systemFontOfSize:11],CandidateColor(@"candidateText",NSColor.whiteColor),badge,YES,self.isFlipped);
    }
    NSFont *font=CandidateFont();
    NSColor *textColor=self.selectedCandidate?CandidateColor(@"candidateSelectedText",self.everstar?EverstarCharcoal():NSColor.whiteColor):CandidateColor(@"candidateText",NSColor.whiteColor);
    CGFloat textX=self.choiceNumber?24:6;
    DrawCandidateText(self.title,font,textColor,NSMakeRect(textX,0,NSWidth(self.bounds)-textX,NSHeight(self.bounds)),NO,self.isFlipped);
    if(self.window.firstResponder==self){[textColor setStroke];NSFrameRect(NSInsetRect(self.bounds,1,1));}
}
@end
@implementation AKInputController {
    std::unique_ptr<armkeykey::Engine> _engine;
    armkeykey::State _state;
    AKCandidatePanel *_panel;
    __weak id _activeClient;
    NSInteger _generation;
}
- (void)buildEngine {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    BOOL simplex=[[defaults stringForKey:@"mode"] isEqual:@"simplex"];
    NSString *key=simplex?@"simplexLearning":@"cangjieLearning";
    NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    support=[support URLByAppendingPathComponent:@"ArmKeyKey" isDirectory:YES];
    NSError *error=nil;
    [NSFileManager.defaultManager createDirectoryAtURL:support withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];
    _engine.reset();
    if(error)return;
    NSString *dictionary=[NSBundle.mainBundle pathForResource:@"Dictionary" ofType:@"sqlite3"];
    NSString *cantonese=[NSBundle.mainBundle pathForResource:@"Cantonese" ofType:@"sqlite3"];
    BOOL jyutping=[[defaults stringForKey:@"mode"] isEqual:@"jyutping"];
    if(jyutping && !cantonese)return;
    try {if(dictionary)_engine=std::make_unique<armkeykey::Engine>(dictionary.UTF8String,support.path.UTF8String,simplex,[defaults boolForKey:key],[defaults boolForKey:@"extendedCharacters"]?armkeykey::CharacterSet::FullUnicode:armkeykey::CharacterSet::Compatible,[defaults boolForKey:@"associatedPhrases"]?(cantonese.UTF8String ?: ""):"",jyutping?(cantonese.UTF8String ?: ""):"",[defaults integerForKey:@"phraseModifier"]);}
    catch(const std::exception&) { /* Never log client text. Settings exposes installation help. */ }
    _generation=[defaults integerForKey:@"dataGeneration"];
}
- (void)activateServer:(id)sender { [self buildEngine];_activeClient=sender; }
- (void)deactivateServer:(id)sender { [self commitComposition:sender];_engine.reset();_activeClient=nil; }
- (NSUInteger)recognizedEvents:(id)sender {return NSEventMaskKeyDown;}
- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    if(event.type!=NSEventTypeKeyDown)return NO;
    if(!_engine || _generation!=[NSUserDefaults.standardUserDefaults integerForKey:@"dataGeneration"]){[self clear:sender];[self buildEngine];}
    if(!_engine)return NO;
    _activeClient=sender;
    NSEventModifierFlags chord=event.modifierFlags & (NSEventModifierFlagControl|NSEventModifierFlagShift|NSEventModifierFlagOption|NSEventModifierFlagCommand);
    BOOL scriptShortcut=chord==(NSEventModifierFlagControl|NSEventModifierFlagCommand) && event.keyCode==5;
    BOOL widthShortcut=chord==(NSEventModifierFlagShift|NSEventModifierFlagCommand) && event.keyCode==49;
    if(scriptShortcut || widthShortcut){
        if(!event.isARepeat){
            NSString *key=scriptShortcut?@"simplifiedOutput":@"fullWidthOutput";
            [self toggleOutputKey:key];
            [AKFeatureNotifications showFeature:key enabled:[NSUserDefaults.standardUserDefaults boolForKey:key]];
        }
        return YES;
    }
    unsigned code=0;
    switch(event.keyCode){case 51:code=8;break;case 36:case 76:code=13;break;case 53:code=27;break;case 123:code=28;break;case 124:code=29;break;case 125:code=31;break;case 126:code=30;break;case 116:code=11;break;case 121:code=12;break;case 117:code=127;break;case 48:code=9;break;case 115:code=1;break;case 119:code=4;break;default:break;}
    NSString *text=event.characters ?: @"";
    if(!code && text.length==1 && [text characterAtIndex:0]<128)code=[text characterAtIndex:0];
    if(!code && text.length==1){
        unichar character=[text characterAtIndex:0];
        if(character>=NSF1FunctionKey && character<=NSF10FunctionKey)code=0x11001+(character-NSF1FunctionKey);
        else if(character>=0xF700 && character<=0xF8FF){[self clear:sender];return NO;}
    }
    unsigned mods=0;auto f=event.modifierFlags;
    if(f&NSEventModifierFlagShift)mods|=8;
    if(f&NSEventModifierFlagControl)mods|=4;
    if(f&NSEventModifierFlagCommand)mods|=16;
    if(f&NSEventModifierFlagOption)mods|=2;
    if(f&NSEventModifierFlagCapsLock)mods|=64;
    switch(event.keyCode){case 82:case 83:case 84:case 85:case 86:case 87:case 88:case 89:case 91:case 92:case 65:case 69:case 78:case 67:case 75:case 81:mods|=32;break;default:break;}
    // Modified number keys produce symbols (Shift+1 is "!"). Decode the
    // physical selection keys only for an active, matching suggestion chord.
    if(_state.associated && mods==[NSUserDefaults.standardUserDefaults integerForKey:@"phraseModifier"]){
        switch(event.keyCode){
            case 18:code='1';break;case 19:code='2';break;case 20:code='3';break;
            case 21:code='4';break;case 23:code='5';break;case 22:code='6';break;
            case 26:code='7';break;case 28:code='8';break;case 25:code='9';break;
            case 49:code=32;break;default:break;
        }
    }
    std::string received=(code && (code<32 || code>=0x10000)) ? "" : (text.UTF8String ?: "");
    _state=_engine->process({code,received,mods});
    [self render:sender];
    // Only printable pass-through keys are widened. Composition and selection keep their normal keys.
    if(!_state.handled && !(f & (NSEventModifierFlagControl|NSEventModifierFlagCommand|NSEventModifierFlagOption)) &&
       [NSUserDefaults.standardUserDefaults boolForKey:@"fullWidthOutput"] && text.length==1 &&
       [text characterAtIndex:0]>=0x20 && [text characterAtIndex:0]<=0x7e){
        [sender insertText:OutputText(text) replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
        return YES;
    }
    return _state.handled;
}
- (void)clear:(id)sender {
    if(_engine)_engine->reset();_state={};[_panel orderOut:nil];
    [sender setMarkedText:@"" selectionRange:NSMakeRange(0,0) replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
}
- (void)commitComposition:(id)sender {
    if(_engine && _state.visible && !_state.associated && _state.highlight<_state.candidates.size()){
        _state=_engine->select(_state.highlight);[self render:sender];
    }
    // Unconverted radicals are canceled, never inserted as unintended Chinese text.
    [self clear:sender];
}
- (void)chooseCandidate:(NSButton*)button {
    if(!_engine || !_activeClient)return;
    _state=_engine->select(button.tag);[self render:_activeClient];
}
- (void)turnCandidatePage:(NSButton*)button {
    if(!_engine || !_activeClient)return;
    _state=_engine->process({button.tag<0?11u:12u,"",0});[self render:_activeClient];
}
- (void)render:(id)sender {
    if(!_state.committed.empty()){
        [sender insertText:OutputText(S(_state.committed)) replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
        _state.committed.clear();
    }
    NSString *reading=S(_state.composition);
    [sender setMarkedText:reading selectionRange:NSMakeRange(reading.length,0) replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
    if(_state.beep)NSBeep();
    if(!_state.visible){[_panel orderOut:nil];return;}
    if(!_panel){
        _panel=[[AKCandidatePanel alloc] initWithContentRect:NSMakeRect(0,0,300,100) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
        _panel.opaque=NO;_panel.backgroundColor=NSColor.clearColor;
        _panel.level=NSPopUpMenuWindowLevel;_panel.hasShadow=YES;_panel.hidesOnDeactivate=NO;
        _panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
        _panel.accessibilityLabel=L(@"ArmKeyKey candidates");
    }
    BOOL everstar=[[NSUserDefaults.standardUserDefaults stringForKey:@"candidateStyle"] isEqualToString:@"everstar"];
    size_t start=_state.page*_state.pageSize,end=std::min(start+_state.pageSize,_state.candidates.size());
    NSFont *font=CandidateFont();
    CGFloat width=66;
    for(size_t i=start;i<end;++i)width=MAX(width,[OutputText(S(_state.candidates[i])) sizeWithAttributes:@{NSFontAttributeName:font}].width+36);
    width=MIN(width,420);
    CGFloat header=_state.associated?34:18;
    const CGFloat rowHeight=MAX(25,font.pointSize+8);
    NSSize size=NSMakeSize(width,(end-start)*rowHeight+header+22);
    AKCandidateBackground *background=[[AKCandidateBackground alloc]initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    background.everstar=everstar;
    for(size_t i=start;i<end;++i){
        AKCandidateButton *button=[[AKCandidateButton alloc]initWithFrame:NSMakeRect(1,size.height-header-(i-start+1)*rowHeight,width-2,rowHeight)];
        button.title=OutputText(S(_state.candidates[i]));button.target=self;button.action=@selector(chooseCandidate:);button.bordered=NO;
        button.everstar=everstar;button.tag=i;button.choiceNumber=i-start+1;button.selectedCandidate=i==_state.highlight;
        button.accessibilityLabel=[NSString stringWithFormat:@"%zu，%@%@",i-start+1,button.title,button.selectedCandidate?@"，已選取":@""];
        [background addSubview:button];
    }
    for(NSNumber *direction in @[@(-1),@(1)]){
        NSButton *arrow=[NSButton buttonWithTitle:direction.intValue<0?@"▲":@"▼" target:self action:@selector(turnCandidatePage:)];
        arrow.bordered=NO;arrow.font=[NSFont systemFontOfSize:10];arrow.contentTintColor=CandidateColor(@"candidateAccent",everstar?EverstarCyan():NSColor.whiteColor);arrow.tag=direction.integerValue;
        arrow.frame=NSMakeRect(3,direction.intValue<0?size.height-17:2,19,16);
        arrow.accessibilityLabel=direction.intValue<0?@"上一頁":@"下一頁";[background addSubview:arrow];
    }
    if(_state.associated){
        NSTextField *label=[NSTextField labelWithString:@"聯想詞"];label.font=[NSFont systemFontOfSize:10];label.textColor=CandidateColor(@"candidateAccent",everstar?EverstarCyan():NSColor.whiteColor);
        label.frame=NSMakeRect(7,size.height-34,width-14,15);[background addSubview:label];
    }
    NSTextField *footer=[NSTextField labelWithString:[NSString stringWithFormat:@"%zu/%zu",_state.page+1,(_state.candidates.size()+_state.pageSize-1)/_state.pageSize]];
    footer.font=[NSFont systemFontOfSize:10];footer.textColor=CandidateColor(@"candidateAccent",everstar?EverstarCyan():NSColor.whiteColor);footer.alignment=NSTextAlignmentRight;
    footer.frame=NSMakeRect(23,4,width-30,14);[background addSubview:footer];
    double requestedScale=[NSUserDefaults.standardUserDefaults doubleForKey:@"candidateScale"];
    CGFloat scale=isfinite(requestedScale) && requestedScale>0?MIN(1.6,MAX(0.8,requestedScale)):1;
    NSSize logicalSize=size;
    size=NSMakeSize(size.width*scale,size.height*scale);
    [_panel setContentSize:size];
    [background setFrameSize:size];
    [background setBoundsSize:logicalSize];
    _panel.contentView=background;
    NSRect caret=NSZeroRect;[sender attributesForCharacterIndex:0 lineHeightRectangle:&caret];
    NSScreen *screen=NSScreen.mainScreen;
    for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(caret.origin,candidate.frame)){screen=candidate;break;}
    NSRect visible=screen.visibleFrame;
    CGFloat x=MAX(NSMinX(visible),MIN(caret.origin.x,NSMaxX(visible)-size.width));
    CGFloat y=caret.origin.y-size.height-4;if(y<NSMinY(visible))y=NSMaxY(caret)+4;
    y=MAX(NSMinY(visible),MIN(y,NSMaxY(visible)-size.height));
    [_panel setFrame:NSMakeRect(x,y,size.width,size.height) display:YES];[_panel orderFrontRegardless];
}
- (NSMenu*)menu {
    NSMenu *menu=[[NSMenu alloc] initWithTitle:@"ArmKeyKey"];
    for(NSString *mode in @[@"Cangjie",@"Simplex",@"Jyutping"]){NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:L(mode) action:@selector(changeMode:) keyEquivalent:@""];item.target=self;item.representedObject=[mode lowercaseString];NSString *selected=[NSUserDefaults.standardUserDefaults stringForKey:@"mode"];item.state=[selected isEqual:item.representedObject]?NSControlStateValueOn:NSControlStateValueOff;[menu addItem:item];}
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *phrases=[[NSMenuItem alloc]initWithTitle:@"聯想字" action:@selector(toggleAssociatedPhrases:) keyEquivalent:@""];
    phrases.target=self;
    phrases.state=[NSUserDefaults.standardUserDefaults boolForKey:@"associatedPhrases"]?NSControlStateValueOn:NSControlStateValueOff;
    [menu addItem:phrases];
    NSArray *keys=@[@"simplifiedOutput",@"fullWidthOutput"];
    NSArray *titles=@[@"繁體中文轉換為簡体",@"全碼文字（全形）"];
    for(NSUInteger i=0;i<keys.count;i++){
        NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:titles[i] action:@selector(toggleOutput:) keyEquivalent:i==0?@"g":@" "];
        item.keyEquivalentModifierMask=NSEventModifierFlagCommand|(i==0?NSEventModifierFlagControl:NSEventModifierFlagShift);
        item.target=self;item.representedObject=keys[i];
        item.state=[NSUserDefaults.standardUserDefaults boolForKey:keys[i]]?NSControlStateValueOn:NSControlStateValueOff;
        [menu addItem:item];
    }
    [menu addItem:NSMenuItem.separatorItem];NSMenuItem *settings=[[NSMenuItem alloc]initWithTitle:L(@"ArmKeyKey Settings…") action:@selector(openSettings:) keyEquivalent:@""];settings.target=self;[menu addItem:settings];
    NSMenuItem *updates=[[NSMenuItem alloc]initWithTitle:@"檢查更新…" action:@selector(checkUpdates:) keyEquivalent:@""];
    updates.target=self;[menu addItem:updates];
    NSMenuItem *about=[[NSMenuItem alloc]initWithTitle:@"關於 ArmKeyKey…" action:@selector(openAbout:) keyEquivalent:@""];
    about.target=self;[menu addItem:about];
    NSMenuItem *licenses=[[NSMenuItem alloc]initWithTitle:@"版權資訊…" action:@selector(openLicenses:) keyEquivalent:@""];
    licenses.target=self;[menu addItem:licenses];
    return menu;
}
- (void)changeMode:(id)sender {
    NSMenuItem *item=[sender isKindOfClass:NSDictionary.class]?sender[kIMKCommandMenuItemName]:sender;
    [self commitComposition:_activeClient];[NSUserDefaults.standardUserDefaults setObject:item.representedObject forKey:@"mode"];[self buildEngine];
}
- (void)toggleOutputKey:(NSString *)key {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    [defaults setBool:![defaults boolForKey:key] forKey:key];
    if(_activeClient)[self render:_activeClient];
}
- (void)toggleAssociatedPhrases:(id)sender {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    [self commitComposition:_activeClient];
    BOOL enabled=![defaults boolForKey:@"associatedPhrases"];
    [defaults setBool:enabled forKey:@"associatedPhrases"];
    // Other input controllers reload the same preference on their next event.
    [defaults setInteger:[defaults integerForKey:@"dataGeneration"]+1 forKey:@"dataGeneration"];
    [self buildEngine];
    NSMenuItem *item=[sender isKindOfClass:NSDictionary.class]?sender[kIMKCommandMenuItemName]:sender;
    item.state=enabled?NSControlStateValueOn:NSControlStateValueOff;
}
- (void)toggleOutput:(id)sender {
    NSMenuItem *item=[sender isKindOfClass:NSDictionary.class]?sender[kIMKCommandMenuItemName]:sender;
    [self toggleOutputKey:item.representedObject];
}
- (void)openSettings:(id)sender { [AKSettings show]; }
- (void)checkUpdates:(id)sender { [AKSettings checkUpdates]; }
- (void)openAbout:(id)sender { [AKSettings showAbout]; }
- (void)openLicenses:(id)sender { [AKSettings showLicenses]; }
@end
