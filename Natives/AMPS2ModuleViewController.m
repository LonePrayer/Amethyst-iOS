#import "AMPS2ModuleViewController.h"
#import "AMModule.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "utils.h"

#import <dlfcn.h>
#import <GameController/GameController.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSInteger, AMPS2Section) {
    AMPS2SectionActions = 0,
    AMPS2SectionGames = 1,
    AMPS2SectionBIOS = 2,
    AMPS2SectionMemory = 3,
    AMPS2SectionRuntime = 4,
    AMPS2SectionBundle = 5,
    AMPS2SectionCount = 6,
};

typedef NS_ENUM(NSInteger, AMPS2DocumentPickerMode) {
    AMPS2DocumentPickerModeNone = 0,
    AMPS2DocumentPickerModeExternalFolder = 1,
    AMPS2DocumentPickerModeGameImport = 2,
    AMPS2DocumentPickerModeMemoryCardImport = 3,
    AMPS2DocumentPickerModeCheatImport = 4,
    AMPS2DocumentPickerModePatchImport = 5,
};

typedef int (*AMPS2InitializeFunction)(const char *dataRoot, const char *resourcesRoot);
typedef int (*AMPS2StartFunction)(UIView *renderView, const char *isoPath, const char *biosPath);
typedef void (*AMPS2StopFunction)(void);
typedef void (*AMPS2PauseFunction)(int paused);
typedef int (*AMPS2IsRunningFunction)(void);
typedef int (*AMPS2StateFunction)(int slot);
typedef int (*AMPS2PrepareMemoryCardsFunction)(const char *dataRoot);
typedef void (*AMPS2PadButtonFunction)(int key, int range, int pressed);
typedef void (*AMPS2ResetPadFunction)(void);
typedef const char *(*AMPS2LastErrorFunction)(void);

static AMPS2InitializeFunction gPS2Initialize = NULL;
static AMPS2StartFunction gPS2Start = NULL;
static AMPS2StopFunction gPS2Stop = NULL;
static AMPS2PauseFunction gPS2Pause = NULL;
static AMPS2IsRunningFunction gPS2IsRunning = NULL;
static AMPS2StateFunction gPS2SaveState = NULL;
static AMPS2StateFunction gPS2LoadState = NULL;
static AMPS2PrepareMemoryCardsFunction gPS2PrepareMemoryCards = NULL;
static AMPS2PadButtonFunction gPS2SetPadButton = NULL;
static AMPS2ResetPadFunction gPS2ResetPad = NULL;
static AMPS2LastErrorFunction gPS2LastError = NULL;
static BOOL gPS2JITHandshakeComplete = NO;

static NSString * const AMPS2ExternalFolderBookmarkKey = @"AMPS2ExternalFolderBookmark";
static NSString * const AMPS2ExternalFolderPathKey = @"AMPS2ExternalFolderPath";
static NSString * const AMPS2StateSlotKey = @"AMPS2StateSlot";
static NSString * const AMPS2SelectedBIOSPathKey = @"AMPS2SelectedBIOSPath";
static NSString * const AMPS2AspectRatioKey = @"AMPS2AspectRatio";
static NSString * const AMPS2UpscaleMultiplierKey = @"AMPS2UpscaleMultiplier";
static NSString * const AMPS2VSyncKey = @"AMPS2VSync";
static NSString * const AMPS2FXAAKey = @"AMPS2FXAA";
static NSString * const AMPS2IntegerScalingKey = @"AMPS2IntegerScaling";
static NSString * const AMPS2FrameLimitKey = @"AMPS2FrameLimit";
static NSString * const AMPS2EECycleRateKey = @"AMPS2EECycleRate";
static NSString * const AMPS2EECycleSkipKey = @"AMPS2EECycleSkip";
static NSString * const AMPS2FastCDVDKey = @"AMPS2FastCDVD";
static NSString * const AMPS2FastBootKey = @"AMPS2FastBoot";
static NSString * const AMPS2EnableCheatsKey = @"AMPS2EnableCheats";
static NSString * const AMPS2HostFSKey = @"AMPS2HostFS";
static NSString * const AMPS2EnablePatchesKey = @"AMPS2EnablePatches";
static NSString * const AMPS2WidescreenPatchesKey = @"AMPS2WidescreenPatches";
static NSString * const AMPS2NoInterlacingPatchesKey = @"AMPS2NoInterlacingPatches";
static NSString * const AMPS2AudioEnabledKey = @"AMPS2AudioEnabled";
static NSString * const AMPS2AudioVolumeKey = @"AMPS2AudioVolume";
static NSString * const AMPS2ControllerVibrationKey = @"AMPS2ControllerVibration";
static NSString * const AMPS2Memcard1EnabledKey = @"AMPS2Memcard1Enabled";
static NSString * const AMPS2Memcard2EnabledKey = @"AMPS2Memcard2Enabled";
static NSString * const AMPS2OSDFPSKey = @"AMPS2OSDFPS";
static NSString * const AMPS2OSDSpeedKey = @"AMPS2OSDSpeed";
static NSString * const AMPS2OSDResolutionKey = @"AMPS2OSDResolution";
static NSString * const AMPS2OSDGSStatsKey = @"AMPS2OSDGSStats";
static NSString * const AMPS2OSDInputsKey = @"AMPS2OSDInputs";
static NSString * const AMPS2TextureFilteringKey = @"AMPS2TextureFiltering";
static NSString * const AMPS2InterlaceModeKey = @"AMPS2InterlaceMode";
static NSString * const AMPS2AccurateBlendingKey = @"AMPS2AccurateBlending";
static NSString * const AMPS2AnisotropyKey = @"AMPS2Anisotropy";
static NSString * const AMPS2DitheringKey = @"AMPS2Dithering";
static NSString * const AMPS2BilinearPresentKey = @"AMPS2BilinearPresent";
static NSString * const AMPS2TexturePreloadingKey = @"AMPS2TexturePreloading";
static NSString * const AMPS2HWMipmapKey = @"AMPS2HWMipmap";
static NSString * const AMPS2AutoFlushSWKey = @"AMPS2AutoFlushSW";
static NSString * const AMPS2AutoFlushHWKey = @"AMPS2AutoFlushHW";
static NSString * const AMPS2WaitLoopKey = @"AMPS2WaitLoop";
static NSString * const AMPS2IntcStatKey = @"AMPS2IntcStat";
static NSString * const AMPS2MVUFlagKey = @"AMPS2MVUFlag";
static NSString * const AMPS2InstantVU1Key = @"AMPS2InstantVU1";
static NSString * const AMPS2VUThreadKey = @"AMPS2VUThread";

static BOOL AMPS2BoolSetting(NSString *key, BOOL defaultValue)
{
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [NSUserDefaults.standardUserDefaults boolForKey:key] : defaultValue;
}

static NSInteger AMPS2IntegerSetting(NSString *key, NSInteger defaultValue)
{
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [NSUserDefaults.standardUserDefaults integerForKey:key] : defaultValue;
}

static NSString *AMPS2AspectRatioTitle(NSInteger value)
{
    switch (value) {
        case 0:
            return @"Stretch";
        case 2:
            return @"4:3";
        case 3:
            return @"16:9";
        case 4:
            return @"10:7";
        default:
            return @"Auto 4:3/3:2";
    }
}

static NSString *AMPS2UpscaleTitle(NSInteger value)
{
    if (value <= 1) {
        return @"Native";
    }
    return [NSString stringWithFormat:@"%ldx", (long)value];
}

static NSString *AMPS2EECycleRateTitle(NSInteger value)
{
    if (value == 0) {
        return @"Normal";
    }
    return [NSString stringWithFormat:@"%+ld", (long)value];
}

static NSString *AMPS2EECycleSkipTitle(NSInteger value)
{
    return value == 0 ? @"Off" : [NSString stringWithFormat:@"%ld", (long)value];
}

static NSString *AMPS2TitleForValue(NSInteger value, NSArray<NSDictionary<NSString *, id> *> *choices, NSString *fallback)
{
    for (NSDictionary<NSString *, id> *choice in choices) {
        if ([choice[@"value"] integerValue] == value) {
            return choice[@"title"];
        }
    }
    return fallback;
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2TextureFilteringChoices(void)
{
    return @[
        @{@"title": @"PS2", @"value": @2},
        @{@"title": @"Forced Bilinear", @"value": @1},
        @{@"title": @"Nearest", @"value": @0},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2InterlaceChoices(void)
{
    return @[
        @{@"title": @"Automatic", @"value": @0},
        @{@"title": @"Off", @"value": @1},
        @{@"title": @"Weave TFF", @"value": @2},
        @{@"title": @"Weave BFF", @"value": @3},
        @{@"title": @"Bob TFF", @"value": @4},
        @{@"title": @"Bob BFF", @"value": @5},
        @{@"title": @"Blend TFF", @"value": @6},
        @{@"title": @"Blend BFF", @"value": @7},
        @{@"title": @"Adaptive TFF", @"value": @8},
        @{@"title": @"Adaptive BFF", @"value": @9},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2AccurateBlendingChoices(void)
{
    return @[
        @{@"title": @"Minimum", @"value": @0},
        @{@"title": @"Basic", @"value": @1},
        @{@"title": @"Medium", @"value": @2},
        @{@"title": @"High", @"value": @3},
        @{@"title": @"Full", @"value": @4},
        @{@"title": @"Maximum", @"value": @5},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2AnisotropyChoices(void)
{
    return @[
        @{@"title": @"Off", @"value": @0},
        @{@"title": @"2x", @"value": @2},
        @{@"title": @"4x", @"value": @4},
        @{@"title": @"8x", @"value": @8},
        @{@"title": @"16x", @"value": @16},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2DitheringChoices(void)
{
    return @[
        @{@"title": @"Off", @"value": @0},
        @{@"title": @"Scaled", @"value": @1},
        @{@"title": @"Unscaled", @"value": @2},
        @{@"title": @"Force 32-bit", @"value": @3},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2BilinearPresentChoices(void)
{
    return @[
        @{@"title": @"Off", @"value": @0},
        @{@"title": @"Bilinear Smooth", @"value": @1},
        @{@"title": @"Bilinear Sharp", @"value": @2},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2TexturePreloadingChoices(void)
{
    return @[
        @{@"title": @"Off", @"value": @0},
        @{@"title": @"Partial", @"value": @1},
        @{@"title": @"Full", @"value": @2},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2AutoFlushHWChoices(void)
{
    return @[
        @{@"title": @"Disabled", @"value": @0},
        @{@"title": @"Sprites Only", @"value": @1},
        @{@"title": @"Enabled", @"value": @2},
    ];
}

static NSArray<NSDictionary<NSString *, id> *> *AMPS2AudioVolumeChoices(void)
{
    return @[
        @{@"title": @"0%", @"value": @0},
        @{@"title": @"50%", @"value": @50},
        @{@"title": @"100%", @"value": @100},
        @{@"title": @"150%", @"value": @150},
        @{@"title": @"200%", @"value": @200},
    ];
}

static NSString *AMPS2ControllerSummary(void)
{
    return [NSString stringWithFormat:@"%lu detected by GameController.framework", (unsigned long)GCController.controllers.count];
}

static NSString *AMPS2ControllerDiagnosticsText(void)
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:AMPS2ControllerSummary()];
    [GCController.controllers enumerateObjectsUsingBlock:^(GCController *controller, NSUInteger index, __unused BOOL *stop) {
        NSString *vendor = controller.vendorName.length > 0 ? controller.vendorName : @"(no vendor)";
        NSString *category = @"(no category)";
        if ([controller respondsToSelector:@selector(productCategory)]) {
            category = controller.productCategory ?: category;
        }
        [lines addObject:[NSString stringWithFormat:@"%lu. %@ / %@", (unsigned long)index + 1, vendor, category]];
        [lines addObject:[NSString stringWithFormat:@"   extended=%@ gamepad=%@ micro=%@ motion=%@",
                          controller.extendedGamepad ? @"yes" : @"no",
                          controller.gamepad ? @"yes" : @"no",
                          controller.microGamepad ? @"yes" : @"no",
                          controller.motion ? @"yes" : @"no"]];
    }];
    return [lines componentsJoinedByString:@"\n"];
}

static NSString *AMPS2ControllerMappingText(void)
{
    return [@[
        @"A -> Cross",
        @"B -> Circle",
        @"X -> Square",
        @"Y -> Triangle",
        @"Menu -> Start",
        @"Options -> Select",
        @"D-Pad -> D-Pad",
        @"Left Stick -> Left Analog",
        @"Right Stick -> Right Analog",
        @"L1/R1 -> L1/R1",
        @"L2/R2 -> L2/R2"
    ] componentsJoinedByString:@"\n"];
}

static NSArray<NSString *> *AMPS2ExternalStorageSubdirectories(void)
{
    return @[@"Software", @"Memcards", @"States", @"Config", @"Logs", @"Cache", @"Resources", @"Screenshots", @"Textures", @"Cheats", @"Patches", @"InputProfiles", @"Videos"];
}

static NSURL *AMPS2ResolveExternalFolderURL(void)
{
    NSData *bookmarkData = [NSUserDefaults.standardUserDefaults dataForKey:AMPS2ExternalFolderBookmarkKey];
    if (bookmarkData.length > 0) {
        BOOL stale = NO;
        NSError *error = nil;
        NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                options:0
                                          relativeToURL:nil
                                    bookmarkDataIsStale:&stale
                                                  error:&error];
        if (url && !stale) {
            return url;
        }
        NSLog(@"[PS2] External folder bookmark failed: stale=%d error=%@", stale, error.localizedDescription);
    }

    NSString *forcedPath = @(getenv("AM_PS2_HOME") ?: "");
    return forcedPath.length > 0 ? [NSURL fileURLWithPath:forcedPath isDirectory:YES] : nil;
}

static BOOL AMPS2StartExternalFolderAccess(NSURL *url)
{
    return url ? [url startAccessingSecurityScopedResource] : NO;
}

static void AMPS2StopExternalFolderAccess(NSURL *url, BOOL didStartAccessing)
{
    if (url && didStartAccessing) {
        [url stopAccessingSecurityScopedResource];
    }
}

static BOOL AMPS2WriteProbeAtDirectory(NSURL *directoryURL, NSString **failureMessage)
{
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *createError = nil;
    if (![fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&createError]) {
        if (failureMessage) {
            *failureMessage = [NSString stringWithFormat:@"%@: %@", directoryURL.path, createError.localizedDescription ?: @"create failed"];
        }
        return NO;
    }

    NSURL *probeURL = [directoryURL URLByAppendingPathComponent:@".amethyst-write-test"];
    NSError *writeError = nil;
    if (![@"write-test\n" writeToURL:probeURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (failureMessage) {
            *failureMessage = [NSString stringWithFormat:@"%@: %@", probeURL.path, writeError.localizedDescription ?: @"write failed"];
        }
        return NO;
    }
    [fileManager removeItemAtURL:probeURL error:nil];
    return YES;
}

static BOOL AMPS2ExternalStorageReady(NSURL *rootURL, NSString **failureMessage)
{
    if (!rootURL) {
        if (failureMessage) {
            *failureMessage = @"External PS2 folder is not selected.";
        }
        return NO;
    }

    if (!AMPS2WriteProbeAtDirectory(rootURL, failureMessage)) {
        return NO;
    }
    for (NSString *relativePath in AMPS2ExternalStorageSubdirectories()) {
        if (!AMPS2WriteProbeAtDirectory([rootURL URLByAppendingPathComponent:relativePath isDirectory:YES], failureMessage)) {
            return NO;
        }
    }
    return YES;
}

static void AMPS2StoreExternalFolderURL(NSURL *url)
{
    NSError *error = nil;
    NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil
                                                  error:&error];
    if (bookmarkData.length == 0) {
        NSLog(@"[PS2] Failed to store bookmark for %@: %@", url.path, error.localizedDescription);
        return;
    }
    [NSUserDefaults.standardUserDefaults setObject:bookmarkData forKey:AMPS2ExternalFolderBookmarkKey];
    [NSUserDefaults.standardUserDefaults setObject:url.path ?: @"" forKey:AMPS2ExternalFolderPathKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

static NSString *AMPS2LastErrorMessage(void)
{
    if (!gPS2LastError) {
        return @"Unknown PS2 error.";
    }
    const char *error = gPS2LastError();
    return error && error[0] != '\0' ? @(error) : @"Unknown PS2 error.";
}

static BOOL AMPS2NeedsTXMJITHandshake(void)
{
    if (@available(iOS 26, *)) {
        return DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM);
    }
    return NO;
}

static BOOL AMPS2CanBootWithCurrentJIT(void)
{
    if (isJITEnabled(false)) {
        gPS2JITHandshakeComplete = YES;
    }
    NSLog(@"[PS2] JIT gate host=%d strict=%d txmNeeded=%d handshake=%d",
          isJITEnabled(false), isJITEnabled(true), AMPS2NeedsTXMJITHandshake(), gPS2JITHandshakeComplete);
    return isJITEnabled(false) || gPS2JITHandshakeComplete;
}

@interface AMPS2SettingsViewController : UITableViewController
@end

@implementation AMPS2SettingsViewController

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"PS2 Settings";
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(controllerListChanged:)
                                                     name:GCControllerDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(controllerListChanged:)
                                                     name:GCControllerDidDisconnectNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 7;
        case 1:
            return 15;
        case 2:
            return 9;
        case 3:
            return 3;
        case 4:
            return 3;
        case 5:
            return 5;
        case 6:
            return 2;
        case 7:
            return 3;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"General";
        case 1:
            return @"Graphics";
        case 2:
            return @"Performance";
        case 3:
            return @"Controller";
        case 4:
            return @"Memory";
        case 5:
            return @"Stats";
        case 6:
            return @"Audio";
        case 7:
            return @"Storage";
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1 || section == 2 || section == 5 || section == 6) {
        return @"These settings are written to PCSX2-Amethyst.ini and apply the next time a game starts.";
    }
    if (section == 3) {
        return @"Controller input uses iOS GameController events mapped directly to DualShock 2 controls.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PS2SettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PS2SettingsCell"];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;

    NSDictionary<NSString *, id> *row = [self rowForIndexPath:indexPath];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"detail"];

    NSString *key = row[@"key"];
    if (key.length > 0) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = AMPS2BoolSetting(key, [row[@"default"] boolValue]);
        toggle.accessibilityIdentifier = key;
        [toggle addTarget:self action:@selector(settingChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if ([row[@"action"] length] > 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (NSDictionary<NSString *, id> *)rowForIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        NSArray *rows = @[
            @{@"title": @"Aspect Ratio",
              @"detail": AMPS2AspectRatioTitle(AMPS2IntegerSetting(AMPS2AspectRatioKey, 1)),
              @"action": @"aspectRatio"},
            @{@"title": @"Fast Boot", @"detail": @"Skip the PS2 BIOS splash when supported.", @"key": AMPS2FastBootKey, @"default": @YES},
            @{@"title": @"Enable Cheats", @"detail": @"Load enabled pnach cheats.", @"key": AMPS2EnableCheatsKey, @"default": @NO},
            @{@"title": @"Enable Patches", @"detail": @"Load game pnach patches.", @"key": AMPS2EnablePatchesKey, @"default": @YES},
            @{@"title": @"Widescreen Patches", @"detail": @"Use PCSX2 widescreen patch list when available.", @"key": AMPS2WidescreenPatchesKey, @"default": @NO},
            @{@"title": @"No-interlacing Patches", @"detail": @"Use no-interlacing patches when available.", @"key": AMPS2NoInterlacingPatchesKey, @"default": @NO},
            @{@"title": @"HostFS", @"detail": @"Expose host files to games that use HostFS.", @"key": AMPS2HostFSKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 1) {
        NSArray *rows = @[
            @{@"title": @"Renderer", @"detail": @"Metal"},
            @{@"title": @"Internal Resolution",
              @"detail": AMPS2UpscaleTitle(AMPS2IntegerSetting(AMPS2UpscaleMultiplierKey, 2)),
              @"action": @"upscale"},
            @{@"title": @"Texture Filtering",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2TextureFilteringKey, 2), AMPS2TextureFilteringChoices(), @"PS2"),
              @"action": @"textureFiltering"},
            @{@"title": @"Interlace Mode",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2InterlaceModeKey, 0), AMPS2InterlaceChoices(), @"Automatic"),
              @"action": @"interlace"},
            @{@"title": @"Accurate Blending",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2AccurateBlendingKey, 1), AMPS2AccurateBlendingChoices(), @"Basic"),
              @"action": @"accurateBlending"},
            @{@"title": @"Anisotropic Filtering",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2AnisotropyKey, 0), AMPS2AnisotropyChoices(), @"Off"),
              @"action": @"anisotropy"},
            @{@"title": @"Dithering",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2DitheringKey, 2), AMPS2DitheringChoices(), @"Unscaled"),
              @"action": @"dithering"},
            @{@"title": @"Bilinear Present",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2BilinearPresentKey, 1), AMPS2BilinearPresentChoices(), @"Bilinear Smooth"),
              @"action": @"bilinearPresent"},
            @{@"title": @"Texture Preloading",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2TexturePreloadingKey, 2), AMPS2TexturePreloadingChoices(), @"Full"),
              @"action": @"texturePreloading"},
            @{@"title": @"HW Auto Flush",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2AutoFlushHWKey, 0), AMPS2AutoFlushHWChoices(), @"Disabled"),
              @"action": @"autoFlushHW"},
            @{@"title": @"V-Sync", @"detail": @"Wait for vertical blank.", @"key": AMPS2VSyncKey, @"default": @NO},
            @{@"title": @"FXAA", @"detail": @"Post-process anti-aliasing.", @"key": AMPS2FXAAKey, @"default": @NO},
            @{@"title": @"Integer Scaling", @"detail": @"Use integer scaling for output presentation.", @"key": AMPS2IntegerScalingKey, @"default": @NO},
            @{@"title": @"Hardware Mipmapping", @"detail": @"Use hardware mipmap generation.", @"key": AMPS2HWMipmapKey, @"default": @YES},
            @{@"title": @"Auto Flush SW", @"detail": @"Use software renderer auto flush behavior.", @"key": AMPS2AutoFlushSWKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 2) {
        NSArray *rows = @[
            @{@"title": @"Frame Limiter", @"detail": @"Keep game speed at normal PS2 rate.", @"key": AMPS2FrameLimitKey, @"default": @YES},
            @{@"title": @"EE Cycle Rate",
              @"detail": AMPS2EECycleRateTitle(AMPS2IntegerSetting(AMPS2EECycleRateKey, 0)),
              @"action": @"eeCycleRate"},
            @{@"title": @"EE Cycle Skip",
              @"detail": AMPS2EECycleSkipTitle(AMPS2IntegerSetting(AMPS2EECycleSkipKey, 0)),
              @"action": @"eeCycleSkip"},
            @{@"title": @"Fast CDVD", @"detail": @"Speed up disc access for games that tolerate it.", @"key": AMPS2FastCDVDKey, @"default": @NO},
            @{@"title": @"Wait Loop Detection", @"detail": @"Fast-forward constant EE wait loops.", @"key": AMPS2WaitLoopKey, @"default": @YES},
            @{@"title": @"INTC Spin Detection", @"detail": @"Fast-forward intc_stat waits.", @"key": AMPS2IntcStatKey, @"default": @YES},
            @{@"title": @"mVU Flag Hack", @"detail": @"Recommended microVU flag speedhack.", @"key": AMPS2MVUFlagKey, @"default": @YES},
            @{@"title": @"Instant VU1", @"detail": @"Recommended VU1 speedhack when MTVU is off.", @"key": AMPS2InstantVU1Key, @"default": @YES},
            @{@"title": @"VU Thread", @"detail": @"Threaded VU1. Disable if a game has timing problems.", @"key": AMPS2VUThreadKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 3) {
        NSArray *rows = @[
            @{@"title": @"Connected Controllers", @"detail": AMPS2ControllerSummary(), @"action": @"controllers"},
            @{@"title": @"Controller Mapping", @"detail": @"GameController buttons are mapped to DualShock 2 controls.", @"action": @"controllerMapping"},
            @{@"title": @"Vibration", @"detail": @"Allow DualShock vibration when available.", @"key": AMPS2ControllerVibrationKey, @"default": @YES},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 4) {
        NSArray *rows = @[
            @{@"title": @"Prepare Memory Folder", @"detail": @"Mcd001.ps2 and Mcd002.ps2 are used in the Memcards folder.", @"action": @"createMemcards"},
            @{@"title": @"Memory Card 1", @"detail": @"Mcd001.ps2", @"key": AMPS2Memcard1EnabledKey, @"default": @YES},
            @{@"title": @"Memory Card 2", @"detail": @"Mcd002.ps2", @"key": AMPS2Memcard2EnabledKey, @"default": @YES},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 5) {
        NSArray *rows = @[
            @{@"title": @"FPS", @"detail": @"Show frames per second.", @"key": AMPS2OSDFPSKey, @"default": @YES},
            @{@"title": @"Speed", @"detail": @"Show emulation speed.", @"key": AMPS2OSDSpeedKey, @"default": @YES},
            @{@"title": @"Resolution", @"detail": @"Show internal rendering resolution.", @"key": AMPS2OSDResolutionKey, @"default": @YES},
            @{@"title": @"GS Stats", @"detail": @"Show graphics synthesizer stats.", @"key": AMPS2OSDGSStatsKey, @"default": @NO},
            @{@"title": @"Inputs", @"detail": @"Show controller input overlay.", @"key": AMPS2OSDInputsKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 6) {
        NSArray *rows = @[
            @{@"title": @"Audio Output", @"detail": @"SDL backend.", @"key": AMPS2AudioEnabledKey, @"default": @YES},
            @{@"title": @"Volume",
              @"detail": AMPS2TitleForValue(AMPS2IntegerSetting(AMPS2AudioVolumeKey, 100), AMPS2AudioVolumeChoices(), @"100%"),
              @"action": @"audioVolume"},
        ];
        return rows[indexPath.row];
    }

    NSURL *rootURL = AMPS2ResolveExternalFolderURL();
    NSArray *rows = @[
        @{@"title": @"Data Root", @"detail": rootURL.path ?: @"External folder not selected"},
        @{@"title": @"Software", @"detail": rootURL ? [rootURL URLByAppendingPathComponent:@"Software" isDirectory:YES].path : @"External folder not selected"},
        @{@"title": @"Built-in BIOS", @"detail": @"Bundled in Modules/ps2/Resources/BIOS"},
    ];
    return rows[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, id> *row = [self rowForIndexPath:indexPath];
    NSString *action = row[@"action"];
    if ([action isEqualToString:@"aspectRatio"]) {
        [self presentChoiceWithTitle:@"Aspect Ratio"
                                  key:AMPS2AspectRatioKey
                              choices:@[
            @{@"title": @"Stretch", @"value": @0},
            @{@"title": @"Auto 4:3/3:2", @"value": @1},
            @{@"title": @"4:3", @"value": @2},
            @{@"title": @"16:9", @"value": @3},
            @{@"title": @"10:7", @"value": @4},
        ]
                            indexPath:indexPath];
    } else if ([action isEqualToString:@"upscale"]) {
        [self presentChoiceWithTitle:@"Internal Resolution"
                                  key:AMPS2UpscaleMultiplierKey
                              choices:@[
            @{@"title": @"Native", @"value": @1},
            @{@"title": @"2x", @"value": @2},
            @{@"title": @"3x", @"value": @3},
            @{@"title": @"4x", @"value": @4},
            @{@"title": @"5x", @"value": @5},
            @{@"title": @"6x", @"value": @6},
            @{@"title": @"8x", @"value": @8},
        ]
                            indexPath:indexPath];
    } else if ([action isEqualToString:@"textureFiltering"]) {
        [self presentChoiceWithTitle:@"Texture Filtering" key:AMPS2TextureFilteringKey choices:AMPS2TextureFilteringChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"interlace"]) {
        [self presentChoiceWithTitle:@"Interlace Mode" key:AMPS2InterlaceModeKey choices:AMPS2InterlaceChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"accurateBlending"]) {
        [self presentChoiceWithTitle:@"Accurate Blending" key:AMPS2AccurateBlendingKey choices:AMPS2AccurateBlendingChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"anisotropy"]) {
        [self presentChoiceWithTitle:@"Anisotropic Filtering" key:AMPS2AnisotropyKey choices:AMPS2AnisotropyChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"dithering"]) {
        [self presentChoiceWithTitle:@"Dithering" key:AMPS2DitheringKey choices:AMPS2DitheringChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"bilinearPresent"]) {
        [self presentChoiceWithTitle:@"Bilinear Present" key:AMPS2BilinearPresentKey choices:AMPS2BilinearPresentChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"texturePreloading"]) {
        [self presentChoiceWithTitle:@"Texture Preloading" key:AMPS2TexturePreloadingKey choices:AMPS2TexturePreloadingChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"autoFlushHW"]) {
        [self presentChoiceWithTitle:@"HW Auto Flush" key:AMPS2AutoFlushHWKey choices:AMPS2AutoFlushHWChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"audioVolume"]) {
        [self presentChoiceWithTitle:@"Volume" key:AMPS2AudioVolumeKey choices:AMPS2AudioVolumeChoices() indexPath:indexPath];
    } else if ([action isEqualToString:@"eeCycleRate"]) {
        [self presentChoiceWithTitle:@"EE Cycle Rate"
                                  key:AMPS2EECycleRateKey
                              choices:@[
            @{@"title": @"-3", @"value": @-3},
            @{@"title": @"-2", @"value": @-2},
            @{@"title": @"-1", @"value": @-1},
            @{@"title": @"Normal", @"value": @0},
            @{@"title": @"+1", @"value": @1},
            @{@"title": @"+2", @"value": @2},
            @{@"title": @"+3", @"value": @3},
        ]
                            indexPath:indexPath];
    } else if ([action isEqualToString:@"eeCycleSkip"]) {
        [self presentChoiceWithTitle:@"EE Cycle Skip"
                                  key:AMPS2EECycleSkipKey
                              choices:@[
            @{@"title": @"Off", @"value": @0},
            @{@"title": @"1", @"value": @1},
            @{@"title": @"2", @"value": @2},
            @{@"title": @"3", @"value": @3},
        ]
                            indexPath:indexPath];
    } else if ([action isEqualToString:@"controllers"]) {
        [self presentControllerDiagnostics];
    } else if ([action isEqualToString:@"controllerMapping"]) {
        [self presentControllerMapping];
    } else if ([action isEqualToString:@"createMemcards"]) {
        [self createDefaultMemoryCards];
    }
}

- (void)settingChanged:(UISwitch *)sender
{
    if (sender.accessibilityIdentifier.length == 0) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:sender.accessibilityIdentifier];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)controllerListChanged:(NSNotification *)notification
{
    NSLog(@"[PS2] Controller notification: %@", notification.name);
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)presentChoiceWithTitle:(NSString *)title
                           key:(NSString *)key
                       choices:(NSArray<NSDictionary<NSString *, id> *> *)choices
                     indexPath:(NSIndexPath *)indexPath
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary<NSString *, id> *choice in choices) {
        [alert addAction:[UIAlertAction actionWithTitle:choice[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:[choice[@"value"] integerValue] forKey:key];
            [NSUserDefaults.standardUserDefaults synchronize];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentControllerDiagnostics
{
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Controller Diagnostics"
                                                                   message:AMPS2ControllerDiagnosticsText()
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Refresh" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentControllerDiagnostics];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentControllerMapping
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Controller Mapping"
                                                                   message:AMPS2ControllerMappingText()
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createDefaultMemoryCards
{
    NSURL *rootURL = AMPS2ResolveExternalFolderURL();
    if (!rootURL) {
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a PS2 external folder first."];
        return;
    }

    BOOL accessed = AMPS2StartExternalFolderAccess(rootURL);
    NSString *failureMessage = nil;
    if (!AMPS2ExternalStorageReady(rootURL, &failureMessage)) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: rootURL.path];
        return;
    }

    int result = gPS2PrepareMemoryCards ? gPS2PrepareMemoryCards(rootURL.path.UTF8String) : 0;
    AMPS2StopExternalFolderAccess(rootURL, accessed);

    if (!result) {
        [self showAlertWithTitle:@"Memory Card Failed" message:AMPS2LastErrorMessage()];
        return;
    }

    NSURL *memcardsURL = [rootURL URLByAppendingPathComponent:@"Memcards" isDirectory:YES];
    [self showAlertWithTitle:@"Memory Cards Ready" message:memcardsURL.path];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@interface AMPS2RenderViewController : UIViewController

- (instancetype)initWithGameURL:(NSURL *)gameURL
                         biosURL:(NSURL *)biosURL
                userDirectoryURL:(NSURL *)userDirectoryURL
                    resourcesURL:(NSURL *)resourcesURL;

@end

@interface AMPS2RenderViewController ()
@property(nonatomic) NSURL *gameURL;
@property(nonatomic) NSURL *biosURL;
@property(nonatomic) NSURL *userDirectoryURL;
@property(nonatomic) NSURL *resourcesURL;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) NSTimer *controlsHideTimer;
@property(nonatomic) NSInteger stateSlot;
@property(nonatomic) BOOL didStart;
@property(nonatomic) BOOL statusShouldStayVisible;
@property(nonatomic) BOOL accessingSecurityScopedUserDirectory;
@property(nonatomic) id controllerConnectObserver;
@property(nonatomic) id controllerDisconnectObserver;
@end

@implementation AMPS2RenderViewController

- (instancetype)initWithGameURL:(NSURL *)gameURL
                         biosURL:(NSURL *)biosURL
                userDirectoryURL:(NSURL *)userDirectoryURL
                    resourcesURL:(NSURL *)resourcesURL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _gameURL = gameURL;
        _biosURL = biosURL;
        _userDirectoryURL = userDirectoryURL;
        _resourcesURL = resourcesURL;
        _stateSlot = MAX(1, [NSUserDefaults.standardUserDefaults integerForKey:AMPS2StateSlotKey]);
        self.title = gameURL.lastPathComponent ?: @"PS2";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.accessingSecurityScopedUserDirectory = [self.userDirectoryURL startAccessingSecurityScopedResource];
    self.view.backgroundColor = UIColor.blackColor;
    if (self.stateSlot < 1 || self.stateSlot > 10) {
        self.stateSlot = 1;
    }

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"PS2"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(closeGame)];
    [self rebuildGameMenu];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"Starting PS2...";
    self.statusShouldStayVisible = YES;
    [self.view addSubview:self.statusLabel];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlsTemporarily)];
    tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapRecognizer];
    [self installControllerObservers];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.didStart) {
        self.didStart = YES;
        [self startEmulation];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.controlsHideTimer invalidate];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        [self stopEmulation];
    }
}

- (void)rebuildGameMenu
{
    NSMutableArray<UIMenuElement *> *slotActions = [NSMutableArray array];
    for (NSInteger slot = 1; slot <= 10; slot++) {
        UIAction *action = [UIAction actionWithTitle:[NSString stringWithFormat:@"Slot %ld", (long)slot]
                                               image:nil
                                          identifier:nil
                                             handler:^(__unused UIAction *selectedAction) {
            self.stateSlot = slot;
            [NSUserDefaults.standardUserDefaults setInteger:slot forKey:AMPS2StateSlotKey];
            [NSUserDefaults.standardUserDefaults synchronize];
            [self rebuildGameMenu];
            [self showControlsTemporarily];
        }];
        action.state = slot == self.stateSlot ? UIMenuElementStateOn : UIMenuElementStateOff;
        [slotActions addObject:action];
    }

    UIAction *saveAction = [UIAction actionWithTitle:@"Save State"
                                               image:[UIImage systemImageNamed:@"tray.and.arrow.up"]
                                          identifier:nil
                                             handler:^(__unused UIAction *action) { [self performStateOperation:gPS2SaveState name:@"Save State"]; }];
    UIAction *loadAction = [UIAction actionWithTitle:@"Load State"
                                               image:[UIImage systemImageNamed:@"tray.and.arrow.down"]
                                          identifier:nil
                                             handler:^(__unused UIAction *action) { [self performStateOperation:gPS2LoadState name:@"Load State"]; }];
    UIAction *stopAction = [UIAction actionWithTitle:@"Stop"
                                               image:[UIImage systemImageNamed:@"stop.circle"]
                                          identifier:nil
                                             handler:^(__unused UIAction *action) { [self closeGame]; }];
    stopAction.attributes = UIMenuElementAttributesDestructive;

    UIMenu *menu = [UIMenu menuWithChildren:@[
        [UIMenu menuWithTitle:@"State Slot" image:nil identifier:nil options:0 children:slotActions],
        saveAction,
        loadAction,
        stopAction,
    ]];
    UIBarButtonItem *menuButton = [[UIBarButtonItem alloc] initWithTitle:@"Menu" style:UIBarButtonItemStylePlain target:nil action:nil];
    menuButton.menu = menu;
    self.navigationItem.rightBarButtonItem = menuButton;
}

- (void)setStatusText:(NSString *)text keepsVisible:(BOOL)keepsVisible
{
    self.statusShouldStayVisible = keepsVisible;
    self.statusLabel.text = text;
    self.statusLabel.hidden = !keepsVisible && self.navigationController.navigationBarHidden;
    [self.view bringSubviewToFront:self.statusLabel];
}

- (void)showControlsTemporarily
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.statusLabel.hidden = NO;
    [self.view bringSubviewToFront:self.statusLabel];
    [self.controlsHideTimer invalidate];
    self.controlsHideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                              target:self
                                                            selector:@selector(hideTransientControls)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void)hideTransientControls
{
    self.controlsHideTimer = nil;
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    if (!self.statusShouldStayVisible) {
        self.statusLabel.hidden = YES;
    }
}

- (void)performStateOperation:(AMPS2StateFunction)operation name:(NSString *)name
{
    if (!operation) {
        [self setStatusText:[NSString stringWithFormat:@"%@ is not available.", name] keepsVisible:YES];
        [self showControlsTemporarily];
        return;
    }

    NSInteger slot = self.stateSlot;
    [self setStatusText:[NSString stringWithFormat:@"%@ slot %ld...", name, (long)slot] keepsVisible:NO];
    [self showControlsTemporarily];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int result = operation((int)slot);
        NSString *message = result ? [NSString stringWithFormat:@"%@ complete: slot %ld", name, (long)slot] : AMPS2LastErrorMessage();
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setStatusText:message keepsVisible:result == 0];
            [weakSelf showControlsTemporarily];
        });
    });
}

- (void)startEmulation
{
    if (!gPS2Initialize || !gPS2Start) {
        [self setStatusText:@"PS2 bridge is not loaded." keepsVisible:YES];
        [self showControlsTemporarily];
        return;
    }

    NSString *dataRoot = self.userDirectoryURL.path;
    NSString *resourcesRoot = self.resourcesURL.path;
    NSString *gamePath = self.gameURL.path;
    NSString *biosPath = self.biosURL.path;
    NSString *gameName = self.gameURL.lastPathComponent ?: @"";
    UIView *renderView = self.view;
    __weak typeof(self) weakSelf = self;

    NSLog(@"[PS2] Starting game=%@ bios=%@ data=%@ resources=%@", gamePath, biosPath, dataRoot, resourcesRoot);
    [self setStatusText:@"Initializing PS2..." keepsVisible:YES];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int initResult = gPS2Initialize(dataRoot.UTF8String, resourcesRoot.UTF8String);
        NSLog(@"[PS2] Initialize returned: %d", initResult);
        if (!initResult) {
            NSString *message = AMPS2LastErrorMessage();
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setStatusText:message keepsVisible:YES];
                [weakSelf showControlsTemporarily];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setStatusText:@"Booting PS2..." keepsVisible:YES];
        });

        int startResult = gPS2Start(renderView, gamePath.UTF8String, biosPath.UTF8String);
        NSLog(@"[PS2] Start returned: %d", startResult);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (startResult) {
                [weakSelf setStatusText:[NSString stringWithFormat:@"Running\n%@", gameName] keepsVisible:NO];
                [weakSelf hideTransientControls];
            } else {
                [weakSelf setStatusText:AMPS2LastErrorMessage() keepsVisible:YES];
                [weakSelf showControlsTemporarily];
            }
        });
    });
}

- (void)stopEmulation
{
    [self uninstallControllerObservers];
    if (gPS2ResetPad) {
        gPS2ResetPad();
    }
    if (gPS2Stop && (!gPS2IsRunning || gPS2IsRunning())) {
        gPS2Stop();
    }
    if (self.accessingSecurityScopedUserDirectory) {
        [self.userDirectoryURL stopAccessingSecurityScopedResource];
        self.accessingSecurityScopedUserDirectory = NO;
    }
}

- (void)closeGame
{
    [self stopEmulation];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)installControllerObservers
{
    [self configureController:GCController.controllers.firstObject];
    __weak typeof(self) weakSelf = self;
    self.controllerConnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCControllerDidConnectNotification
                                                                                     object:nil
                                                                                      queue:NSOperationQueue.mainQueue
                                                                                 usingBlock:^(NSNotification *note) {
        [weakSelf configureController:note.object];
        [weakSelf setStatusText:[NSString stringWithFormat:@"Controller connected\n%@", AMPS2ControllerSummary()] keepsVisible:NO];
        [weakSelf showControlsTemporarily];
    }];
    self.controllerDisconnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCControllerDidDisconnectNotification
                                                                                        object:nil
                                                                                         queue:NSOperationQueue.mainQueue
                                                                                    usingBlock:^(__unused NSNotification *note) {
        if (gPS2ResetPad) {
            gPS2ResetPad();
        }
        [weakSelf setStatusText:[NSString stringWithFormat:@"Controller disconnected\n%@", AMPS2ControllerSummary()] keepsVisible:NO];
        [weakSelf showControlsTemporarily];
    }];
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self configureController:GCController.controllers.firstObject];
        });
    }];
}

- (void)uninstallControllerObservers
{
    if (self.controllerConnectObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.controllerConnectObserver];
        self.controllerConnectObserver = nil;
    }
    if (self.controllerDisconnectObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.controllerDisconnectObserver];
        self.controllerDisconnectObserver = nil;
    }
    for (GCController *controller in GCController.controllers) {
        GCExtendedGamepad *gamepad = controller.extendedGamepad;
        gamepad.dpad.valueChangedHandler = nil;
        gamepad.leftThumbstick.valueChangedHandler = nil;
        gamepad.rightThumbstick.valueChangedHandler = nil;
        [self clearButton:gamepad.buttonA];
        [self clearButton:gamepad.buttonB];
        [self clearButton:gamepad.buttonX];
        [self clearButton:gamepad.buttonY];
        [self clearButton:gamepad.leftShoulder];
        [self clearButton:gamepad.rightShoulder];
        [self clearButton:gamepad.leftTrigger];
        [self clearButton:gamepad.rightTrigger];
        [self clearButton:gamepad.leftThumbstickButton];
        [self clearButton:gamepad.rightThumbstickButton];
        [self clearButton:gamepad.buttonMenu];
        [self clearButton:gamepad.buttonOptions];
    }
}

- (void)clearButton:(GCControllerButtonInput *)button
{
    button.pressedChangedHandler = nil;
    button.valueChangedHandler = nil;
}

- (void)configureController:(GCController *)controller
{
    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    if (!gamepad || !gPS2SetPadButton) {
        return;
    }

    [self bindButton:gamepad.buttonA toKey:96 analog:NO];
    [self bindButton:gamepad.buttonB toKey:97 analog:NO];
    [self bindButton:gamepad.buttonX toKey:99 analog:NO];
    [self bindButton:gamepad.buttonY toKey:100 analog:NO];
    [self bindButton:gamepad.leftShoulder toKey:102 analog:NO];
    [self bindButton:gamepad.rightShoulder toKey:103 analog:NO];
    [self bindButton:gamepad.leftTrigger toKey:104 analog:YES];
    [self bindButton:gamepad.rightTrigger toKey:105 analog:YES];
    [self bindButton:gamepad.leftThumbstickButton toKey:106 analog:NO];
    [self bindButton:gamepad.rightThumbstickButton toKey:107 analog:NO];
    [self bindButton:gamepad.buttonMenu toKey:108 analog:NO];
    [self bindButton:gamepad.buttonOptions toKey:109 analog:NO];

    gamepad.dpad.valueChangedHandler = ^(__unused GCControllerDirectionPad *dpad, float xValue, float yValue) {
        [self sendPositive:xValue positiveKey:22 negativeKey:21];
        [self sendPositive:yValue positiveKey:19 negativeKey:20];
    };
    gamepad.leftThumbstick.valueChangedHandler = ^(__unused GCControllerDirectionPad *dpad, float xValue, float yValue) {
        [self sendPositive:xValue positiveKey:111 negativeKey:113];
        [self sendPositive:yValue positiveKey:110 negativeKey:112];
    };
    gamepad.rightThumbstick.valueChangedHandler = ^(__unused GCControllerDirectionPad *dpad, float xValue, float yValue) {
        [self sendPositive:xValue positiveKey:121 negativeKey:123];
        [self sendPositive:yValue positiveKey:120 negativeKey:122];
    };
    NSLog(@"[PS2] Bound controller: %@", controller.vendorName ?: @"unknown");
}

- (void)bindButton:(GCControllerButtonInput *)button toKey:(int)key analog:(BOOL)analog
{
    if (!button) {
        return;
    }
    button.valueChangedHandler = ^(__unused GCControllerButtonInput *input, float value, BOOL pressed) {
        int range = analog ? (int)lroundf(MAX(0.0f, MIN(1.0f, value)) * 255.0f) : 0;
        gPS2SetPadButton(key, range, pressed || value > 0.05f);
    };
}

- (void)sendPositive:(float)value positiveKey:(int)positiveKey negativeKey:(int)negativeKey
{
    float clamped = MAX(-1.0f, MIN(1.0f, value));
    int positiveRange = clamped > 0.05f ? (int)lroundf(clamped * 255.0f) : 0;
    int negativeRange = clamped < -0.05f ? (int)lroundf(-clamped * 255.0f) : 0;
    gPS2SetPadButton(positiveKey, positiveRange, positiveRange > 0);
    gPS2SetPadButton(negativeKey, negativeRange, negativeRange > 0);
}

@end

@interface AMPS2ModuleViewController ()
@property(nonatomic) AMModule *module;
@property(nonatomic) void *coreHandle;
@property(nonatomic) NSString *loadStatus;
@property(nonatomic) NSArray<NSURL *> *gameURLs;
@property(nonatomic) NSArray<NSURL *> *biosURLs;
@property(nonatomic) NSArray<NSURL *> *memoryCardURLs;
@property(nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *resourceRows;
@property(nonatomic) AMPS2DocumentPickerMode documentPickerMode;
@property(nonatomic) BOOL didHandleAutoBoot;
@end

@implementation AMPS2ModuleViewController

- (instancetype)initWithModule:(AMModule *)module
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _module = module;
        _loadStatus = @"Not loaded";
        _gameURLs = @[];
        _biosURLs = @[];
        _memoryCardURLs = @[];
        _resourceRows = @[];
        self.title = module.name;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reload"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(refreshDiagnostics)];
    [self refreshDiagnostics];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self handleAutoBootIfNeeded];
}

- (void)refreshDiagnostics
{
    [self loadCoreIfNeeded];
    [self reloadRows];
    [self.tableView reloadData];
}

- (void)handleAutoBootIfNeeded
{
    const char *autoBoot = getenv("AM_PS2_AUTO_BOOT");
    NSString *request = autoBoot && autoBoot[0] != '\0'
        ? @(autoBoot)
        : [NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalPS2AutoBootPath"];
    if (self.didHandleAutoBoot || request.length == 0) {
        return;
    }

    self.didHandleAutoBoot = YES;
    [self refreshDiagnostics];

    NSURL *gameURL = nil;
    if (![request isEqualToString:@"1"] && ![request isEqualToString:@"first"]) {
        NSURL *requestedURL = [NSURL fileURLWithPath:request];
        for (NSURL *url in self.gameURLs) {
            if ([url.path isEqualToString:requestedURL.path] || [url.lastPathComponent isEqualToString:request]) {
                gameURL = url;
                break;
            }
        }
    }
    if (!gameURL) {
        gameURL = self.gameURLs.firstObject;
    }

    if (!gameURL) {
        NSLog(@"[PS2] Auto boot failed: no software found in %@", self.softwareDirectoryURL.path);
        [self showAlertWithTitle:@"PS2 Auto Boot Failed" message:@"No PS2 software found in external Software folder."];
        return;
    }

    NSLog(@"[PS2] Auto boot selected: %@", gameURL.path);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showPendingBootForURL:gameURL];
    });
}

- (void)loadCoreIfNeeded
{
    if (self.coreHandle) {
        self.loadStatus = gPS2Initialize && gPS2Start && gPS2Stop ? @"Loaded; bridge ready" : @"Loaded; bridge missing";
        return;
    }

    self.coreHandle = dlopen("@rpath/libarmsx2_amethyst.dylib", RTLD_NOW | RTLD_GLOBAL);
    if (!self.coreHandle) {
        const char *error = dlerror();
        self.loadStatus = error ? @(error) : @"dlopen failed";
        NSLog(@"[PS2] Failed to load libarmsx2_amethyst.dylib: %@", self.loadStatus);
        return;
    }

    gPS2Initialize = (AMPS2InitializeFunction)dlsym(self.coreHandle, "ARMSX2AmethystInitialize");
    gPS2Start = (AMPS2StartFunction)dlsym(self.coreHandle, "ARMSX2AmethystStart");
    gPS2Stop = (AMPS2StopFunction)dlsym(self.coreHandle, "ARMSX2AmethystStop");
    gPS2Pause = (AMPS2PauseFunction)dlsym(self.coreHandle, "ARMSX2AmethystPause");
    gPS2IsRunning = (AMPS2IsRunningFunction)dlsym(self.coreHandle, "ARMSX2AmethystIsRunning");
    gPS2SaveState = (AMPS2StateFunction)dlsym(self.coreHandle, "ARMSX2AmethystSaveState");
    gPS2LoadState = (AMPS2StateFunction)dlsym(self.coreHandle, "ARMSX2AmethystLoadState");
    gPS2PrepareMemoryCards = (AMPS2PrepareMemoryCardsFunction)dlsym(self.coreHandle, "ARMSX2AmethystPrepareMemoryCards");
    gPS2SetPadButton = (AMPS2PadButtonFunction)dlsym(self.coreHandle, "ARMSX2AmethystSetPadButton");
    gPS2ResetPad = (AMPS2ResetPadFunction)dlsym(self.coreHandle, "ARMSX2AmethystResetPad");
    gPS2LastError = (AMPS2LastErrorFunction)dlsym(self.coreHandle, "ARMSX2AmethystLastError");
    self.loadStatus = gPS2Initialize && gPS2Start && gPS2Stop ? @"Loaded; bridge ready" : @"Loaded; bridge missing";
    NSLog(@"[PS2] Loaded libarmsx2_amethyst.dylib: %@", self.loadStatus);
}

- (NSURL *)ps2UserDirectoryURL
{
    return AMPS2ResolveExternalFolderURL();
}

- (NSURL *)softwareDirectoryURL
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    return rootURL ? [rootURL URLByAppendingPathComponent:@"Software" isDirectory:YES] : nil;
}

- (NSURL *)bundledBIOSDirectoryURL
{
    return [self.resourcesDirectoryURL URLByAppendingPathComponent:@"BIOS" isDirectory:YES];
}

- (NSURL *)memoryCardDirectoryURL
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    return rootURL ? [rootURL URLByAppendingPathComponent:@"Memcards" isDirectory:YES] : nil;
}

- (NSURL *)cheatsDirectoryURL
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    return rootURL ? [rootURL URLByAppendingPathComponent:@"Cheats" isDirectory:YES] : nil;
}

- (NSURL *)patchesDirectoryURL
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    return rootURL ? [rootURL URLByAppendingPathComponent:@"Patches" isDirectory:YES] : nil;
}

- (NSURL *)selectedBIOSURL
{
    NSString *selectedPath = [NSUserDefaults.standardUserDefaults stringForKey:AMPS2SelectedBIOSPathKey];
    if (selectedPath.length > 0) {
        for (NSURL *url in self.biosURLs) {
            if ([url.path isEqualToString:selectedPath]) {
                return url;
            }
        }
    }
    return self.biosURLs.firstObject;
}

- (NSURL *)resourcesDirectoryURL
{
    return [[self.module resourceDirectoryURL] URLByAppendingPathComponent:@"Resources" isDirectory:YES];
}

- (void)reloadRows
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    BOOL accessed = AMPS2StartExternalFolderAccess(rootURL);
    self.gameURLs = [self sortedFilesInDirectory:self.softwareDirectoryURL extensions:[NSSet setWithArray:@[@"iso", @"bin", @"chd", @"cso", @"gz", @"mdf"]]];
    self.biosURLs = [self sortedFilesInDirectory:self.bundledBIOSDirectoryURL extensions:[NSSet setWithArray:@[@"bin"]]];
    self.memoryCardURLs = [self sortedFilesInDirectory:self.memoryCardDirectoryURL extensions:[NSSet setWithArray:@[@"ps2", @"mcd", @"mcr", @"psu"]]];
    AMPS2StopExternalFolderAccess(rootURL, accessed);

    NSURL *resourceURL = [self.module resourceDirectoryURL];
    NSURL *resourcesURL = self.resourcesDirectoryURL;
    NSURL *biosURL = self.bundledBIOSDirectoryURL;
    NSURL *fontsURL = [resourcesURL URLByAppendingPathComponent:@"fonts" isDirectory:YES];
    NSURL *gameIndexURL = [resourcesURL URLByAppendingPathComponent:@"GameIndex.yaml"];
    self.resourceRows = @[
        @{@"title": @"Module", @"value": [self existsAtURL:resourceURL] ? @"YES" : @"NO"},
        @{@"title": @"Resources", @"value": [self existsAtURL:resourcesURL] ? @"YES" : @"NO"},
        @{@"title": @"Built-in BIOS", @"value": [self existsAtURL:biosURL] ? @"YES" : @"NO"},
        @{@"title": @"Fonts", @"value": [self existsAtURL:fontsURL] ? @"YES" : @"NO"},
        @{@"title": @"GameIndex", @"value": [self existsAtURL:gameIndexURL] ? @"YES" : @"NO"},
    ];
}

- (NSArray<NSURL *> *)sortedFilesInDirectory:(NSURL *)directoryURL extensions:(NSSet<NSString *> *)extensions
{
    if (!directoryURL) {
        return @[];
    }

    NSArray<NSURLResourceKey> *keys = @[NSURLIsRegularFileKey, NSURLFileSizeKey];
    NSArray<NSURL *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directoryURL
                                                             includingPropertiesForKeys:keys
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                  error:nil] ?: @[];
    NSMutableArray<NSURL *> *files = [NSMutableArray array];
    for (NSURL *url in contents) {
        NSNumber *isRegularFile = nil;
        if (![url getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil] || !isRegularFile.boolValue) {
            continue;
        }
        if (!extensions || [extensions containsObject:url.pathExtension.lowercaseString]) {
            [files addObject:url];
        }
    }
    [files sortUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
        return [left.lastPathComponent localizedCaseInsensitiveCompare:right.lastPathComponent];
    }];
    return files.copy;
}

- (BOOL)existsAtURL:(NSURL *)url
{
    return [NSFileManager.defaultManager fileExistsAtPath:url.path];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return AMPS2SectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case AMPS2SectionActions:
            return 7;
        case AMPS2SectionGames:
            return MAX(self.gameURLs.count, 1);
        case AMPS2SectionBIOS:
            return MAX(self.biosURLs.count, 1);
        case AMPS2SectionMemory:
            return MAX(self.memoryCardURLs.count, 1);
        case AMPS2SectionRuntime:
            return 5;
        case AMPS2SectionBundle:
            return self.resourceRows.count;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case AMPS2SectionActions:
            return @"Actions";
        case AMPS2SectionGames:
            return @"Software";
        case AMPS2SectionBIOS:
            return @"BIOS";
        case AMPS2SectionMemory:
            return @"Memory Cards";
        case AMPS2SectionRuntime:
            return @"Runtime";
        case AMPS2SectionBundle:
            return @"Bundle";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PS2Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PS2Cell"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 3;

    NSDictionary<NSString *, NSString *> *row = [self rowForIndexPath:indexPath];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"value"];
    cell.imageView.image = [UIImage systemImageNamed:row[@"image"] ?: @""];

    if (indexPath.section == AMPS2SectionActions ||
        (indexPath.section == AMPS2SectionGames && self.gameURLs.count > 0) ||
        (indexPath.section == AMPS2SectionBIOS && self.biosURLs.count > 0)) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = indexPath.section == AMPS2SectionBIOS ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.section == AMPS2SectionBIOS) {
            NSURL *selectedURL = [self selectedBIOSURL];
            cell.accessoryType = [selectedURL.path isEqualToString:self.biosURLs[indexPath.row].path] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
    }
    return cell;
}

- (NSDictionary<NSString *, NSString *> *)rowForIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == AMPS2SectionActions) {
        NSString *externalPath = [NSUserDefaults.standardUserDefaults stringForKey:AMPS2ExternalFolderPathKey] ?: @"Not selected";
        NSArray *rows = @[
            @{@"title": @"External Folder", @"value": externalPath, @"image": @"folder.badge.gearshape"},
            @{@"title": @"Import Software", @"value": @"Copy selected PS2 images into Software.", @"image": @"square.and.arrow.down"},
            @{@"title": @"Import Memory Card", @"value": @"Copy selected memory cards into Memcards.", @"image": @"memorychip"},
            @{@"title": @"Import Cheats", @"value": @"Copy pnach files into Cheats.", @"image": @"wand.and.stars"},
            @{@"title": @"Import Patches", @"value": @"Copy pnach files into Patches.", @"image": @"wrench.and.screwdriver"},
            @{@"title": @"Settings", @"value": @"Graphics, performance, controller, memory and stats.", @"image": @"slider.horizontal.3"},
            @{@"title": @"Refresh", @"value": @"Reload games, BIOS and core status.", @"image": @"arrow.clockwise"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == AMPS2SectionGames) {
        if (self.gameURLs.count == 0) {
            return @{@"title": self.softwareDirectoryURL ? @"No software found" : @"External folder not selected",
                     @"value": self.softwareDirectoryURL.path ?: @"Select an external PS2 folder first.",
                     @"image": @"opticaldisc"};
        }
        NSURL *url = self.gameURLs[indexPath.row];
        NSNumber *fileSize = nil;
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        return @{@"title": url.lastPathComponent ?: @"Software",
                 @"value": fileSize ? [NSByteCountFormatter stringFromByteCount:fileSize.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : url.path,
                 @"image": @"opticaldiscdrive"};
    }

    if (indexPath.section == AMPS2SectionBIOS) {
        if (self.biosURLs.count == 0) {
            return @{@"title": @"Built-in BIOS missing",
                     @"value": self.bundledBIOSDirectoryURL.path ?: @"Bundle resources missing.",
                     @"image": @"cpu"};
        }
        NSURL *url = self.biosURLs[indexPath.row];
        BOOL selected = [[self selectedBIOSURL].path isEqualToString:url.path];
        return @{@"title": url.lastPathComponent ?: @"BIOS",
                 @"value": selected ? @"Built-in selected" : @"Built-in",
                 @"image": @"cpu"};
    }

    if (indexPath.section == AMPS2SectionMemory) {
        if (self.memoryCardURLs.count == 0) {
            return @{@"title": self.memoryCardDirectoryURL ? @"No memory cards found" : @"External folder not selected",
                     @"value": self.memoryCardDirectoryURL.path ?: @"Select an external PS2 folder first.",
                     @"image": @"memorychip"};
        }
        NSURL *url = self.memoryCardURLs[indexPath.row];
        NSNumber *fileSize = nil;
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        return @{@"title": url.lastPathComponent ?: @"Memory Card",
                 @"value": fileSize ? [NSByteCountFormatter stringFromByteCount:fileSize.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : url.path,
                 @"image": @"memorychip"};
    }

    if (indexPath.section == AMPS2SectionRuntime) {
        NSArray *rows = @[
            @{@"title": @"Core Library", @"value": self.loadStatus, @"image": @"cpu"},
            @{@"title": @"JIT", @"value": isJITEnabled(false) ? @"ON" : @"OFF", @"image": @"bolt.fill"},
            @{@"title": @"Device JIT Flags", @"value": [NSString stringWithFormat:@"0x%X", DeviceGetJITFlags(NO)], @"image": @"flag"},
            @{@"title": @"Increased Memory", @"value": getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit") ? @"YES" : @"NO", @"image": @"memorychip"},
            @{@"title": @"Storage", @"value": self.ps2UserDirectoryURL.path ?: @"External folder not selected", @"image": @"folder"},
        ];
        return rows[indexPath.row];
    }

    return self.resourceRows[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == AMPS2SectionActions) {
        if (indexPath.row == 0) {
            [self selectExternalFolder];
        } else if (indexPath.row == 1) {
            [self importGames];
        } else if (indexPath.row == 2) {
            [self importMemoryCards];
        } else if (indexPath.row == 3) {
            [self importCheats];
        } else if (indexPath.row == 4) {
            [self importPatches];
        } else if (indexPath.row == 5) {
            [self.navigationController pushViewController:[AMPS2SettingsViewController new] animated:YES];
        } else {
            [self refreshDiagnostics];
        }
        return;
    }

    if (indexPath.section == AMPS2SectionGames && self.gameURLs.count > 0) {
        [self showPendingBootForURL:self.gameURLs[indexPath.row]];
    } else if (indexPath.section == AMPS2SectionBIOS && self.biosURLs.count > 0) {
        NSURL *biosURL = self.biosURLs[indexPath.row];
        [NSUserDefaults.standardUserDefaults setObject:biosURL.path ?: @"" forKey:AMPS2SelectedBIOSPathKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:AMPS2SectionBIOS] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)selectExternalFolder
{
    self.documentPickerMode = AMPS2DocumentPickerModeExternalFolder;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importGames
{
    [self importFilesWithMode:AMPS2DocumentPickerModeGameImport missingMessage:@"Select a PS2 external folder first."];
}

- (void)importMemoryCards
{
    [self importFilesWithMode:AMPS2DocumentPickerModeMemoryCardImport missingMessage:@"Select a PS2 external folder first."];
}

- (void)importCheats
{
    [self importFilesWithMode:AMPS2DocumentPickerModeCheatImport missingMessage:@"Select a PS2 external folder first."];
}

- (void)importPatches
{
    [self importFilesWithMode:AMPS2DocumentPickerModePatchImport missingMessage:@"Select a PS2 external folder first."];
}

- (void)importFilesWithMode:(AMPS2DocumentPickerMode)mode missingMessage:(NSString *)missingMessage
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    if (!rootURL) {
        [self showAlertWithTitle:@"External Folder Required" message:missingMessage];
        return;
    }
    BOOL accessed = AMPS2StartExternalFolderAccess(rootURL);
    NSString *failureMessage = nil;
    if (!AMPS2ExternalStorageReady(rootURL, &failureMessage)) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: rootURL.path];
        return;
    }
    AMPS2StopExternalFolderAccess(rootURL, accessed);

    self.documentPickerMode = mode;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    if (self.documentPickerMode == AMPS2DocumentPickerModeExternalFolder) {
        NSURL *url = urls.firstObject;
        if (url) {
            BOOL accessed = AMPS2StartExternalFolderAccess(url);
            NSString *failureMessage = nil;
            if (AMPS2ExternalStorageReady(url, &failureMessage)) {
                AMPS2StoreExternalFolderURL(url);
            } else {
                [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: url.path];
            }
            AMPS2StopExternalFolderAccess(url, accessed);
        }
        self.documentPickerMode = AMPS2DocumentPickerModeNone;
        [self refreshDiagnostics];
        return;
    }

    NSURL *rootURL = self.ps2UserDirectoryURL;
    NSURL *destinationDirectoryURL = self.softwareDirectoryURL;
    if (self.documentPickerMode == AMPS2DocumentPickerModeMemoryCardImport) {
        destinationDirectoryURL = self.memoryCardDirectoryURL;
    } else if (self.documentPickerMode == AMPS2DocumentPickerModeCheatImport) {
        destinationDirectoryURL = self.cheatsDirectoryURL;
    } else if (self.documentPickerMode == AMPS2DocumentPickerModePatchImport) {
        destinationDirectoryURL = self.patchesDirectoryURL;
    }
    if (!rootURL || !destinationDirectoryURL) {
        self.documentPickerMode = AMPS2DocumentPickerModeNone;
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a PS2 external folder first."];
        return;
    }

    BOOL accessed = AMPS2StartExternalFolderAccess(rootURL);
    NSString *failureMessage = nil;
    if (!AMPS2ExternalStorageReady(rootURL, &failureMessage)) {
        self.documentPickerMode = AMPS2DocumentPickerModeNone;
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: rootURL.path];
        return;
    }

    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSURL *destinationURL = [self uniqueDestinationURLForSourceURL:url inDirectoryURL:destinationDirectoryURL];
        NSError *error = nil;
        if (![NSFileManager.defaultManager copyItemAtURL:url toURL:destinationURL error:&error]) {
            [failures addObject:[NSString stringWithFormat:@"%@: %@", url.lastPathComponent, error.localizedDescription]];
        } else {
            NSLog(@"[PS2] Imported %@ -> %@", url.path, destinationURL.path);
        }
    }

    AMPS2StopExternalFolderAccess(rootURL, accessed);
    self.documentPickerMode = AMPS2DocumentPickerModeNone;
    [self refreshDiagnostics];
    if (failures.count > 0) {
        [self showAlertWithTitle:@"Import Failed" message:[failures componentsJoinedByString:@"\n"]];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    self.documentPickerMode = AMPS2DocumentPickerModeNone;
}

- (NSURL *)uniqueDestinationURLForSourceURL:(NSURL *)sourceURL inDirectoryURL:(NSURL *)directoryURL
{
    NSString *baseName = sourceURL.URLByDeletingPathExtension.lastPathComponent ?: @"Software";
    NSString *extension = sourceURL.pathExtension;
    NSURL *candidateURL = [directoryURL URLByAppendingPathComponent:sourceURL.lastPathComponent ?: @"Software"];
    NSInteger index = 2;

    while ([NSFileManager.defaultManager fileExistsAtPath:candidateURL.path]) {
        NSString *fileName = extension.length > 0
            ? [NSString stringWithFormat:@"%@ %ld.%@", baseName, (long)index, extension]
            : [NSString stringWithFormat:@"%@ %ld", baseName, (long)index];
        candidateURL = [directoryURL URLByAppendingPathComponent:fileName];
        index++;
    }
    return candidateURL;
}

- (void)showPendingBootForURL:(NSURL *)url
{
    NSURL *rootURL = self.ps2UserDirectoryURL;
    if (!rootURL) {
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a PS2 external folder before booting games."];
        return;
    }
    BOOL accessed = AMPS2StartExternalFolderAccess(rootURL);
    NSString *failureMessage = nil;
    if (!AMPS2ExternalStorageReady(rootURL, &failureMessage)) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: rootURL.path];
        return;
    }

    [self loadCoreIfNeeded];
    if (!gPS2Initialize || !gPS2Start || !gPS2Stop) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"PS2 Bridge Missing" message:self.loadStatus ?: @"PS2 bridge is not available."];
        return;
    }
    if (self.biosURLs.count == 0) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        [self showAlertWithTitle:@"BIOS Required" message:@"Built-in PS2 BIOS files are missing from the app bundle."];
        return;
    }

    if (!AMPS2CanBootWithCurrentJIT()) {
        AMPS2StopExternalFolderAccess(rootURL, accessed);
        LauncherNavigationController *navigationController = (LauncherNavigationController *)self.navigationController;
        if (![navigationController isKindOfClass:LauncherNavigationController.class]) {
            [self showAlertWithTitle:@"JIT Required" message:@"Cannot find launcher navigation controller."];
            return;
        }

        __weak typeof(self) weakSelf = self;
        [navigationController runAfterJITEnabled:^{
            gPS2JITHandshakeComplete = YES;
            [weakSelf showPendingBootForURL:url];
        }];
        return;
    }

    NSURL *biosURL = [self selectedBIOSURL];
    AMPS2RenderViewController *viewController = [[AMPS2RenderViewController alloc] initWithGameURL:url
                                                                                           biosURL:biosURL
                                                                                  userDirectoryURL:rootURL
                                                                                      resourcesURL:self.resourcesDirectoryURL];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    NSLog(@"[PS2] Presenting render view for %@", url.lastPathComponent);
    AMPS2StopExternalFolderAccess(rootURL, accessed);
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = self.view.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

@end
