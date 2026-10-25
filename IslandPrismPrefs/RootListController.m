#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
@interface IPRootListController : PSListController @end
@implementation IPRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers=[self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSData *d=[NSData dataWithContentsOfFile:@"/var/mobile/Media/IslandPrism/config.json"];
    NSDictionary *dict=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
    return [dict isKindOfClass:NSDictionary.class] ? (dict[[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"]) : [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path=@"/var/mobile/Media/IslandPrism/config.json";
    NSData *d=[NSData dataWithContentsOfFile:path];
    NSDictionary *old=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
    NSMutableDictionary *dict=[old isKindOfClass:NSDictionary.class]?[old mutableCopy]:[NSMutableDictionary dictionary];
    NSString *key=[specifier propertyForKey:@"key"];
    if (key) dict[key]=value;
    NSData *out=[NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    if (!out || ![out writeToFile:path options:NSDataWritingAtomic error:nil]) NSLog(@"[IslandPrism] Failed to save preferences at %@", path);
}
@end
