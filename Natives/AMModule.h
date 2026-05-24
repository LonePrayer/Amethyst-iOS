#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class LauncherNavigationController;
@class AMModule;

typedef UIViewController *_Nonnull (^AMModuleViewControllerFactory)(AMModule *module);
typedef void (^AMModuleLaunchHandler)(LauncherNavigationController *navigationController, AMModule *module);

typedef NS_ENUM(NSInteger, AMModuleLaunchMode) {
    AMModuleLaunchModeViewController = 0,
    AMModuleLaunchModeAction = 1,
};

@interface AMModule : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, copy, nullable) NSString *imageName;
@property(nonatomic, copy, nullable) NSString *relativeResourcePath;
@property(nonatomic, copy, nullable) NSString *entrypoint;
@property(nonatomic, copy, nullable) NSURL *launchURL;
@property(nonatomic, copy, nullable) NSDictionary *debugInfo;
@property(nonatomic, copy) NSArray<NSString *> *storageSubdirectories;
@property(nonatomic, readonly) AMModuleLaunchMode launchMode;
@property(nonatomic) BOOL requiresJIT;
@property(nonatomic) BOOL requiresMemoryLimit;
@property(nonatomic) BOOL requiresExtendedVirtualAddressing;
@property(nonatomic, copy, nullable) AMModuleViewControllerFactory viewControllerFactory;
@property(nonatomic, copy, nullable) AMModuleLaunchHandler launchHandler;

+ (instancetype)viewControllerModuleWithIdentifier:(NSString *)identifier
                                              name:(NSString *)name
                                         imageName:(nullable NSString *)imageName
                                           factory:(AMModuleViewControllerFactory)factory;

+ (instancetype)actionModuleWithIdentifier:(NSString *)identifier
                                      name:(NSString *)name
                                 imageName:(nullable NSString *)imageName
                                   handler:(AMModuleLaunchHandler)handler;

+ (nullable instancetype)moduleWithManifest:(NSDictionary *)manifest
                                resourcePath:(NSString *)resourcePath;

- (NSURL *)storageDirectoryURL;
- (NSURL *)resourceDirectoryURL;

@end

NS_ASSUME_NONNULL_END
