#import "AMModuleRegistry.h"
#import "AMModule.h"
#import "AMDolphinModuleViewController.h"
#import "AMPS2ModuleViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherSplitViewController.h"

@interface AMModuleRegistry ()
@property(nonatomic) NSMutableArray<AMModule *> *mutableModules;
@end

@implementation AMModuleRegistry

+ (instancetype)sharedRegistry
{
    static AMModuleRegistry *registry = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registry = [[AMModuleRegistry alloc] init];
    });
    return registry;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mutableModules = [NSMutableArray array];
    }
    return self;
}

- (NSArray<AMModule *> *)modules
{
    return self.mutableModules.copy;
}

- (NSURL *)storageRootURL
{
    NSString *modulesHome = @(getenv("AM_MODULES_HOME") ?: "");
    if (modulesHome.length == 0) {
        NSString *appHome = @(getenv("AMETHYST_HOME") ?: NSHomeDirectory().UTF8String);
        modulesHome = appHome;
    }

    NSURL *rootURL = [NSURL fileURLWithPath:modulesHome isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:rootURL withIntermediateDirectories:YES attributes:nil error:nil];
    return rootURL;
}

- (NSURL *)resourceRootURL
{
    NSURL *rootURL = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Modules" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:rootURL withIntermediateDirectories:YES attributes:nil error:nil];
    return rootURL;
}

- (void)registerModule:(AMModule *)module
{
    if (!module.identifier.length || [self moduleWithIdentifier:module.identifier] != nil) {
        return;
    }
    if (![module.entrypoint isEqualToString:@"dolphin"] && ![module.entrypoint isEqualToString:@"amethyst"]) {
        [module storageDirectoryURL];
    }
    [self.mutableModules addObject:module];
}

- (AMModule *)moduleWithIdentifier:(NSString *)identifier
{
    for (AMModule *module in self.mutableModules) {
        if ([module.identifier isEqualToString:identifier]) {
            return module;
        }
    }
    return nil;
}

- (void)reloadModules
{
    [self.mutableModules removeAllObjects];
    [self registerBuiltInModules];
    [self registerManifestModules];
}

- (void)registerBuiltInModules
{
    AMModule *amethyst = [AMModule actionModuleWithIdentifier:@"amethyst"
                                                         name:@"Amethyst"
                                                    imageName:@"AppLogo"
                                                      handler:^(LauncherNavigationController *navigationController, AMModule *module) {
        UIWindow *window = navigationController.view.window ?: UIApplication.sharedApplication.windows.firstObject;
        window.rootViewController = [[LauncherSplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
        [window makeKeyAndVisible];
    }];
    amethyst.subtitle = @"Minecraft Java Client";
    amethyst.requiresJIT = YES;
    amethyst.requiresMemoryLimit = YES;
    amethyst.requiresExtendedVirtualAddressing = NO;
    amethyst.storageSubdirectories = @[
        @"accounts",
        @"controlmap",
        @"controlmap/gamepads",
        @"instances",
        @"java_runtimes",
        @"Library/Application Support",
        @".demo",
    ];
    amethyst.entrypoint = @"amethyst";
    amethyst.debugInfo = @{
        @"type": @"builtin",
        @"root": @"LauncherSplitViewController",
    };
    [self registerModule:amethyst];
}

- (void)registerManifestModules
{
    NSArray<NSURL *> *moduleURLs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.resourceRootURL
                                                               includingPropertiesForKeys:nil
                                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                    error:nil];
    for (NSURL *moduleURL in moduleURLs) {
        NSNumber *isDirectory = nil;
        if (![moduleURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil] || !isDirectory.boolValue) {
            continue;
        }

        NSURL *manifestURL = [moduleURL URLByAppendingPathComponent:@"module.json"];
        NSData *manifestData = [NSData dataWithContentsOfURL:manifestURL];
        if (!manifestData) {
            continue;
        }

        NSError *error = nil;
        NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&error];
        if (![manifest isKindOfClass:NSDictionary.class]) {
            NSLog(@"[Apps] Skipped invalid module manifest at %@: %@", manifestURL.path, error.localizedDescription);
            continue;
        }

        AMModule *module = [AMModule moduleWithManifest:manifest resourcePath:moduleURL.lastPathComponent];
        if (!module) {
            NSLog(@"[Apps] Skipped module manifest missing identifier/name at %@", manifestURL.path);
            continue;
        }
        [self attachNativeHandlerIfNeeded:module];
        [self registerModule:module];
    }
}

- (void)attachNativeHandlerIfNeeded:(AMModule *)module
{
    if ([module.entrypoint isEqualToString:@"dolphin"]) {
        module.launchHandler = ^(LauncherNavigationController *navigationController, AMModule *module) {
            AMDolphinModuleViewController *viewController = [[AMDolphinModuleViewController alloc] initWithModule:module];
            [navigationController pushViewController:viewController animated:YES];
        };
        return;
    }

    if ([module.entrypoint isEqualToString:@"ps2"]) {
        module.launchHandler = ^(LauncherNavigationController *navigationController, AMModule *module) {
            AMPS2ModuleViewController *viewController = [[AMPS2ModuleViewController alloc] initWithModule:module];
            [navigationController pushViewController:viewController animated:YES];
        };
    }
}

@end
