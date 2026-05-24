#import "AMModulesViewController.h"
#import "AMExternalStorage.h"
#import "AMModule.h"
#import "AMModuleRegistry.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "utils.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <string.h>

extern void init_setupAccounts(void);
extern void init_setupCustomControls(void);
extern void init_setupMultiDir(void);
extern void init_setupResolvConf(void);

typedef NS_ENUM(NSInteger, AMModulesSection) {
    AMModulesSectionActions = 0,
    AMModulesSectionRuntime = 1,
    AMModulesSectionIdentity = 2,
    AMModulesSectionApps = 3,
    AMModulesSectionCount = 4,
};

typedef NS_ENUM(NSInteger, AMModulesDocumentPickerMode) {
    AMModulesDocumentPickerModeNone = 0,
    AMModulesDocumentPickerModeAmethystHome = 1,
};

@interface AMModulesViewController () <UIDocumentPickerDelegate>

@property(nonatomic) NSArray<AMModule *> *modules;
@property(nonatomic) BOOL didHandleAutoBoot;
@property(nonatomic) AMModulesDocumentPickerMode documentPickerMode;
@property(nonatomic) AMModule *pendingExternalHomeModule;

@end

@implementation AMModulesViewController

static NSString *AMSideStoreSignedBundleIdentifier(void) {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    NSString *profilePath = [NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"];
    NSData *profileData = profilePath ? [NSData dataWithContentsOfFile:profilePath] : nil;
    if (!profileData) {
        return bundleIdentifier;
    }

    NSString *profile = [[NSString alloc] initWithData:profileData encoding:NSISOLatin1StringEncoding];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<key>application-identifier</key>\\s*<string>([^<]+)</string>"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:profile options:0 range:NSMakeRange(0, profile.length)];
    if (!match || match.numberOfRanges < 2) {
        return bundleIdentifier;
    }

    NSString *applicationIdentifier = [profile substringWithRange:[match rangeAtIndex:1]];
    NSRange separator = [applicationIdentifier rangeOfString:@"."];
    if (separator.location == NSNotFound || separator.location + 1 >= applicationIdentifier.length) {
        return bundleIdentifier;
    }

    NSString *signedBundleIdentifier = [applicationIdentifier substringFromIndex:separator.location + 1];
    return signedBundleIdentifier.length > 0 ? signedBundleIdentifier : bundleIdentifier;
}

- (id)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    self.title = @"Apps";
    return self;
}

- (NSString *)imageName {
    return @"square.grid.2x2";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self reloadModules];
    NSLog(@"[Apps] Loaded module picker, modules=%lu", (unsigned long)self.modules.count);

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshRuntimeState)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshRuntimeState)
                                               name:@"AMJITStatusDidChangeNotification"
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleAutoBootNotification)
                                               name:@"AMDolphinAutoBootRequestedNotification"
                                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    [self refreshRuntimeState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self handleAutoBootIfNeeded];
}

- (LauncherNavigationController *)contentNavigationController {
    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        return (LauncherNavigationController *)self.navigationController;
    }

    NSArray<UIViewController *> *viewControllers = self.splitViewController.viewControllers;
    if (viewControllers.count > 1 && [viewControllers[1] isKindOfClass:LauncherNavigationController.class]) {
        return (LauncherNavigationController *)viewControllers[1];
    }

    return nil;
}

- (void)reloadModules {
    [AMModuleRegistry.sharedRegistry reloadModules];
    self.modules = AMModuleRegistry.sharedRegistry.modules;
}

- (void)refreshRuntimeState {
    [self reloadModules];
    [self.tableView reloadData];
}

- (void)handleAutoBootIfNeeded {
    const char *ps2AutoBoot = getenv("AM_PS2_AUTO_BOOT");
    NSString *pendingPS2AutoBoot = ps2AutoBoot && ps2AutoBoot[0] != '\0'
        ? @(ps2AutoBoot)
        : [NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalPS2AutoBootPath"];
    if (!self.didHandleAutoBoot && pendingPS2AutoBoot.length > 0) {
        self.didHandleAutoBoot = YES;
        AMModule *module = [AMModuleRegistry.sharedRegistry moduleWithIdentifier:@"ps2"];
        if (!module) {
            [self showLaunchFailure:@"PS2 module is not available."];
            return;
        }

        NSLog(@"[PS2] Auto boot requested: %@", pendingPS2AutoBoot);
        if (![self canLaunchModule:module]) {
            return;
        }

        void (^launchBlock)(void) = ^{
            [self launchModule:module];
        };
        const char *noJIT = getenv("AM_PS2_AUTO_BOOT_NO_JIT");
        BOOL shouldSkipJIT = noJIT && strcmp(noJIT, "1") == 0;
        if (module.requiresJIT && !shouldSkipJIT && !isJITEnabled(false)) {
            LauncherNavigationController *navigationController = [self contentNavigationController];
            if (!navigationController) {
                [self showLaunchFailure:@"Cannot find launcher navigation controller."];
                return;
            }
            [navigationController runAfterJITEnabled:launchBlock];
        } else {
            launchBlock();
        }
        return;
    }

    const char *autoBootPath = getenv("AM_DOLPHIN_AUTO_BOOT");
    NSString *pendingAutoBootPath = autoBootPath && autoBootPath[0] != '\0'
        ? @(autoBootPath)
        : [NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalDolphinAutoBootPath"];
    if (self.didHandleAutoBoot || pendingAutoBootPath.length == 0) {
        return;
    }

    self.didHandleAutoBoot = YES;
    AMModule *module = [AMModuleRegistry.sharedRegistry moduleWithIdentifier:@"dolphin"];
    if (!module) {
        [self showLaunchFailure:@"Dolphin module is not available."];
        return;
    }

    NSLog(@"[Dolphin] Auto boot requested: %@", pendingAutoBootPath);
    if (![self canLaunchModule:module]) {
        return;
    }

    void (^launchBlock)(void) = ^{
        if ([module.entrypoint isEqualToString:@"amethyst"]) {
            [self launchAmethystModule:module];
            return;
        }
        if (![module.entrypoint isEqualToString:@"dolphin"]) {
            [module storageDirectoryURL];
        }
        [self launchModule:module];
    };

    const char *noJIT = getenv("AM_DOLPHIN_AUTO_BOOT_NO_JIT");
    BOOL shouldSkipJIT = (noJIT && strcmp(noJIT, "1") == 0)
        || [NSUserDefaults.standardUserDefaults boolForKey:@"AMInternalDolphinAutoBootSkipJIT"];
    if (module.requiresJIT && !shouldSkipJIT && !isJITEnabled(false)) {
        LauncherNavigationController *navigationController = [self contentNavigationController];
        if (!navigationController) {
            [self showLaunchFailure:@"Cannot find launcher navigation controller."];
            return;
        }
        [navigationController runAfterJITEnabled:launchBlock];
    } else {
        launchBlock();
    }
}

- (void)handleAutoBootNotification {
    self.didHandleAutoBoot = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleAutoBootIfNeeded];
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return AMModulesSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case AMModulesSectionActions:
            return 2;
        case AMModulesSectionRuntime:
            return 4;
        case AMModulesSectionIdentity:
            return 5;
        case AMModulesSectionApps:
            return MAX(self.modules.count, 1);
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case AMModulesSectionActions:
            return @"Control";
        case AMModulesSectionRuntime:
            return @"Runtime";
        case AMModulesSectionIdentity:
            return @"Debug";
        case AMModulesSectionApps:
            return @"Apps";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == AMModulesSectionApps) {
        return [self tableView:tableView moduleCellForRowAtIndexPath:indexPath];
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DebugCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DebugCell"];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = nil;

    if (indexPath.section == AMModulesSectionActions) {
        [self configureActionCell:cell row:indexPath.row];
    } else if (indexPath.section == AMModulesSectionRuntime) {
        [self configureRuntimeCell:cell row:indexPath.row];
    } else if (indexPath.section == AMModulesSectionIdentity) {
        [self configureIdentityCell:cell row:indexPath.row];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView moduleCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModuleCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ModuleCell"];
    }

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;

    if (self.modules.count == 0) {
        cell.textLabel.text = @"No bundled apps";
        cell.detailTextLabel.text = @"Package apps into the Modules directory.";
        cell.imageView.image = [UIImage systemImageNamed:@"shippingbox"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    AMModule *module = self.modules[indexPath.row];
    cell.textLabel.text = module.name;
    cell.detailTextLabel.text = [self requirementTextForModule:module];
    cell.imageView.image = [self imageForModule:module];
    return cell;
}

- (void)configureActionCell:(UITableViewCell *)cell row:(NSInteger)row {
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (row == 0) {
        cell.textLabel.text = isJITEnabled(false) ? @"JIT Initialized" : @"Init JIT";
        cell.detailTextLabel.text = isJITEnabled(false) ? @"Host process already has JIT." : @"Enable JIT for the host before launching apps.";
        cell.imageView.image = [UIImage systemImageNamed:@"bolt.fill"];
    } else {
        cell.textLabel.text = @"Refresh Status";
        cell.detailTextLabel.text = @"Reload runtime and signing diagnostics.";
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    }
}

- (void)configureRuntimeCell:(UITableViewCell *)cell row:(NSInteger)row {
    NSArray<NSDictionary *> *rows = @[
        @{@"title": @"JIT", @"value": isJITEnabled(false) ? @"ON" : @"OFF"},
        @{@"title": @"Increased Memory", @"value": getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit") ? @"YES" : @"NO"},
        @{@"title": @"Extended Virtual Addressing", @"value": getEntitlementValue(@"com.apple.developer.kernel.extended-virtual-addressing") ? @"YES" : @"NO"},
        @{@"title": @"Device JIT Flags", @"value": [NSString stringWithFormat:@"0x%X", DeviceGetJITFlags(NO)]},
    ];
    cell.textLabel.text = rows[row][@"title"];
    cell.detailTextLabel.text = rows[row][@"value"];
}

- (void)configureIdentityCell:(UITableViewCell *)cell row:(NSInteger)row {
    NSString *signedBundleIdentifier = AMSideStoreSignedBundleIdentifier();
    NSArray<NSDictionary *> *rows = @[
        @{@"title": @"Bundle", @"value": NSBundle.mainBundle.bundleIdentifier ?: @""},
        @{@"title": @"Signed Bundle", @"value": signedBundleIdentifier},
        @{@"title": @"JIT Return URL", @"value": [NSString stringWithFormat:@"sidestore-%@://jit-enabled", signedBundleIdentifier]},
        @{@"title": @"Minecraft Home", @"value": @(getenv("POJAV_HOME") ?: "")},
        @{@"title": @"External Amethyst", @"value": [NSUserDefaults.standardUserDefaults stringForKey:AMAmethystExternalFolderPathKey] ?: @"Not selected"},
    ];
    cell.textLabel.text = rows[row][@"title"];
    cell.detailTextLabel.text = rows[row][@"value"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == AMModulesSectionActions) {
        if (indexPath.row == 0) {
            [self initJIT];
        } else {
            [self refreshRuntimeState];
        }
        return;
    }

    if (indexPath.section != AMModulesSectionApps || self.modules.count == 0) {
        return;
    }

    AMModule *module = self.modules[indexPath.row];
    if (![self canLaunchModule:module]) {
        return;
    }

    void (^launchBlock)(void) = ^{
        if ([module.entrypoint isEqualToString:@"amethyst"]) {
            [self launchAmethystModule:module];
            return;
        }
        if (![module.entrypoint isEqualToString:@"dolphin"]) {
            [module storageDirectoryURL];
        }
        [self launchModule:module];
    };

    if (module.requiresJIT && !isJITEnabled(false)) {
        LauncherNavigationController *navigationController = [self contentNavigationController];
        if (!navigationController) {
            [self showLaunchFailure:@"Cannot find launcher navigation controller."];
            return;
        }
        [navigationController runAfterJITEnabled:launchBlock];
    } else {
        launchBlock();
    }
}

- (void)initJIT {
    if (isJITEnabled(false)) {
        [self refreshRuntimeState];
        return;
    }

    LauncherNavigationController *navigationController = [self contentNavigationController];
    if (!navigationController) {
        [self showLaunchFailure:@"Cannot find launcher navigation controller."];
        return;
    }

    [navigationController initializeJITWithCompletion:^{
        [self refreshRuntimeState];
    }];
}

- (UIImage *)imageForModule:(AMModule *)module {
    if (module.imageName.length == 0) {
        return [UIImage systemImageNamed:@"app"];
    }

    UIImage *image = [UIImage systemImageNamed:module.imageName];
    if (!image) {
        image = [UIImage imageNamed:module.imageName];
    }
    if (!image) {
        NSURL *imageURL = [module.resourceDirectoryURL URLByAppendingPathComponent:module.imageName];
        image = [UIImage imageWithContentsOfFile:imageURL.path];
    }
    return image ?: [UIImage systemImageNamed:@"app"];
}

- (NSString *)requirementTextForModule:(AMModule *)module {
    NSMutableArray<NSString *> *requirements = [NSMutableArray array];
    if (module.requiresJIT) {
        [requirements addObject:@"JIT"];
    }
    if (module.requiresMemoryLimit) {
        [requirements addObject:@"Large Memory"];
    }
    if (module.requiresExtendedVirtualAddressing) {
        [requirements addObject:@"Extended VA"];
    }
    if (module.entrypoint.length > 0) {
        [requirements addObject:[NSString stringWithFormat:@"Entry: %@", module.entrypoint]];
    } else if (module.launchURL) {
        [requirements addObject:@"URL Launch"];
    }
    if (requirements.count == 0) {
        return module.subtitle ?: @"Ready";
    }
    return [NSString stringWithFormat:@"%@ | %@", module.subtitle ?: @"Ready", [requirements componentsJoinedByString:@", "]];
}

- (BOOL)canLaunchModule:(AMModule *)module {
    if (module.requiresMemoryLimit && !getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit")) {
        [self showLaunchFailure:@"Missing Increased Memory Limit entitlement."];
        return NO;
    }

    if (module.requiresExtendedVirtualAddressing && !getEntitlementValue(@"com.apple.developer.kernel.extended-virtual-addressing")) {
        [self showLaunchFailure:@"Missing Extended Virtual Addressing entitlement."];
        return NO;
    }

    return YES;
}

- (void)launchAmethystModule:(AMModule *)module {
    NSURL *homeURL = AMAmethystExternalHomeURL(YES);
    if (!homeURL) {
        self.pendingExternalHomeModule = module;
        [self selectAmethystExternalHome];
        return;
    }

    NSString *failureMessage = nil;
    if (!AMAmethystPrepareExternalHomeURL(homeURL, &failureMessage)) {
        [self showLaunchFailure:failureMessage ?: @"External Amethyst folder is not writable."];
        return;
    }

    AMAmethystApplyExternalHomeURL(homeURL);
    [self reloadAmethystStorageState];
    [self launchModule:module];
}

- (void)selectAmethystExternalHome {
    self.documentPickerMode = AMModulesDocumentPickerModeAmethystHome;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)reloadAmethystStorageState {
    loadPreferences(NO);
    init_setupResolvConf();
    init_setupMultiDir();
    [PLProfiles updateCurrent];
    init_setupAccounts();
    init_setupCustomControls();
    [self refreshRuntimeState];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (self.documentPickerMode != AMModulesDocumentPickerModeAmethystHome) {
        return;
    }

    NSURL *url = urls.firstObject;
    self.documentPickerMode = AMModulesDocumentPickerModeNone;
    if (!url) {
        self.pendingExternalHomeModule = nil;
        return;
    }

    [url startAccessingSecurityScopedResource];
    NSString *failureMessage = nil;
    if (!AMAmethystStoreExternalHomeURL(url, &failureMessage)) {
        self.pendingExternalHomeModule = nil;
        [self showLaunchFailure:failureMessage ?: @"External Amethyst folder is not writable."];
        return;
    }

    [self reloadAmethystStorageState];
    AMModule *module = self.pendingExternalHomeModule;
    self.pendingExternalHomeModule = nil;
    if (module) {
        [self launchModule:module];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.documentPickerMode = AMModulesDocumentPickerModeNone;
    self.pendingExternalHomeModule = nil;
}

- (void)launchModule:(AMModule *)module {
    LauncherNavigationController *navigationController = [self contentNavigationController];
    if (!navigationController) {
        [self showLaunchFailure:@"Cannot find launcher navigation controller."];
        return;
    }

    if (module.launchMode == AMModuleLaunchModeAction) {
        if (module.launchHandler) {
            module.launchHandler(navigationController, module);
        } else if (module.launchURL) {
            [UIApplication.sharedApplication openURL:module.launchURL options:@{} completionHandler:nil];
        } else if (module.entrypoint.length > 0) {
            [self showLaunchFailure:[NSString stringWithFormat:@"Unsupported module entrypoint: %@", module.entrypoint]];
        } else {
            [self showLaunchFailure:@"This app does not provide a launch action."];
        }
        return;
    }

    if (!module.viewControllerFactory) {
        [self showLaunchFailure:@"This app does not provide a launch view."];
        return;
    }

    UIViewController *viewController = module.viewControllerFactory(module);
    if (!viewController.title) {
        viewController.title = module.name;
    }
    [navigationController pushViewController:viewController animated:YES];
}

- (void)showLaunchFailure:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cannot Launch App"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = self.view.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

@end
