#import "AMModule.h"
#import "AMModuleRegistry.h"

@interface AMModule ()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic) AMModuleLaunchMode launchMode;
@end

@implementation AMModule

+ (instancetype)viewControllerModuleWithIdentifier:(NSString *)identifier
                                              name:(NSString *)name
                                         imageName:(NSString *)imageName
                                           factory:(AMModuleViewControllerFactory)factory
{
    AMModule *module = [[self alloc] initWithIdentifier:identifier name:name imageName:imageName launchMode:AMModuleLaunchModeViewController];
    module.viewControllerFactory = factory;
    return module;
}

+ (instancetype)actionModuleWithIdentifier:(NSString *)identifier
                                      name:(NSString *)name
                                 imageName:(NSString *)imageName
                                   handler:(AMModuleLaunchHandler)handler
{
    AMModule *module = [[self alloc] initWithIdentifier:identifier name:name imageName:imageName launchMode:AMModuleLaunchModeAction];
    module.launchHandler = handler;
    return module;
}

+ (instancetype)moduleWithManifest:(NSDictionary *)manifest
                       resourcePath:(NSString *)resourcePath
{
    NSString *identifier = [manifest[@"identifier"] isKindOfClass:NSString.class] ? manifest[@"identifier"] : nil;
    NSString *name = [manifest[@"name"] isKindOfClass:NSString.class] ? manifest[@"name"] : nil;
    if (identifier.length == 0 || name.length == 0) {
        return nil;
    }

    NSString *imageName = [manifest[@"imageName"] isKindOfClass:NSString.class] ? manifest[@"imageName"] : nil;
    NSString *entrypoint = [manifest[@"entrypoint"] isKindOfClass:NSString.class] ? manifest[@"entrypoint"] : nil;
    NSString *launchURLString = [manifest[@"launchURL"] isKindOfClass:NSString.class] ? manifest[@"launchURL"] : nil;

    AMModule *module = [[self alloc] initWithIdentifier:identifier
                                                   name:name
                                              imageName:imageName
                                             launchMode:AMModuleLaunchModeAction];
    module.subtitle = [manifest[@"subtitle"] isKindOfClass:NSString.class] ? manifest[@"subtitle"] : nil;
    module.relativeResourcePath = resourcePath;
    module.entrypoint = entrypoint;
    module.launchURL = launchURLString.length > 0 ? [NSURL URLWithString:launchURLString] : nil;
    module.requiresJIT = [manifest[@"requiresJIT"] respondsToSelector:@selector(boolValue)] ? [manifest[@"requiresJIT"] boolValue] : YES;
    module.requiresMemoryLimit = [manifest[@"requiresMemoryLimit"] respondsToSelector:@selector(boolValue)] ? [manifest[@"requiresMemoryLimit"] boolValue] : NO;
    module.requiresExtendedVirtualAddressing = [manifest[@"requiresExtendedVirtualAddressing"] respondsToSelector:@selector(boolValue)] ? [manifest[@"requiresExtendedVirtualAddressing"] boolValue] : NO;
    module.debugInfo = [manifest[@"debugInfo"] isKindOfClass:NSDictionary.class] ? manifest[@"debugInfo"] : nil;
    module.storageSubdirectories = [self storageSubdirectoriesFromManifest:manifest];
    return module;
}

+ (NSArray<NSString *> *)storageSubdirectoriesFromManifest:(NSDictionary *)manifest
{
    NSArray *directories = [manifest[@"storageSubdirectories"] isKindOfClass:NSArray.class] ? manifest[@"storageSubdirectories"] : @[];
    NSMutableArray<NSString *> *validDirectories = [NSMutableArray array];

    for (id directory in directories) {
        if (![directory isKindOfClass:NSString.class]) {
            continue;
        }

        NSString *relativePath = (NSString *)directory;
        if (relativePath.length == 0 || [relativePath hasPrefix:@"/"] || [relativePath containsString:@".."]) {
            continue;
        }

        [validDirectories addObject:relativePath];
    }

    return validDirectories.copy;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                         imageName:(NSString *)imageName
                        launchMode:(AMModuleLaunchMode)launchMode
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _name = [name copy];
        _imageName = [imageName copy];
        _launchMode = launchMode;
        _storageSubdirectories = @[];
    }
    return self;
}

- (NSURL *)storageDirectoryURL
{
    NSURL *directoryURL = [AMModuleRegistry.sharedRegistry.storageRootURL URLByAppendingPathComponent:self.identifier isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];

    for (NSString *relativePath in self.storageSubdirectories) {
        NSURL *subdirectoryURL = [directoryURL URLByAppendingPathComponent:relativePath isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:subdirectoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return directoryURL;
}

- (NSURL *)resourceDirectoryURL
{
    if (self.relativeResourcePath.length > 0) {
        return [AMModuleRegistry.sharedRegistry.resourceRootURL URLByAppendingPathComponent:self.relativeResourcePath isDirectory:YES];
    }
    return [AMModuleRegistry.sharedRegistry.resourceRootURL URLByAppendingPathComponent:self.identifier isDirectory:YES];
}

@end
