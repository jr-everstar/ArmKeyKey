#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
// Shared storage/validation for the settings recorder and input controller.
@interface AKShortcuts : NSObject
+ (NSArray<NSString *> *)actions;
+ (NSDictionary<NSString *, NSNumber *> *)bindingForAction:(NSString *)action;
+ (NSString *)displayForAction:(NSString *)action;
+ (nullable NSString *)actionForEvent:(NSEvent *)event;
+ (nullable NSString *)setAction:(NSString *)action keyCode:(NSInteger)keyCode modifiers:(NSUInteger)modifiers;
+ (void)clearAction:(NSString *)action;
+ (void)restoreDefaults;
@end
NS_ASSUME_NONNULL_END
