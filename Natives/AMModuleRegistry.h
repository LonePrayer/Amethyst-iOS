#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMModule;

@interface AMModuleRegistry : NSObject

@property(nonatomic, readonly) NSArray<AMModule *> *modules;
@property(nonatomic, readonly) NSURL *storageRootURL;
@property(nonatomic, readonly) NSURL *resourceRootURL;

+ (instancetype)sharedRegistry;

- (void)registerModule:(AMModule *)module;
- (nullable AMModule *)moduleWithIdentifier:(NSString *)identifier;
- (void)reloadModules;

@end

NS_ASSUME_NONNULL_END
