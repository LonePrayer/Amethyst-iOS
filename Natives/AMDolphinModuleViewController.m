#import "AMDolphinModuleViewController.h"
#import "AMModule.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "utils.h"

#import <dlfcn.h>
#import <GameController/GameController.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSInteger, AMDolphinSection) {
    AMDolphinSectionActions = 0,
    AMDolphinSectionGames = 1,
    AMDolphinSectionStatus = 2,
    AMDolphinSectionRuntime = 3,
    AMDolphinSectionBundle = 4,
    AMDolphinSectionNext = 5,
    AMDolphinSectionCount = 6,
};

typedef NS_ENUM(NSInteger, AMDolphinDocumentPickerMode) {
    AMDolphinDocumentPickerModeNone = 0,
    AMDolphinDocumentPickerModeExternalFolder = 1,
    AMDolphinDocumentPickerModeSoftwareImport = 2,
};

typedef int (*AMDolphinInitializeFunction)(const char *userDir, int jitType);
typedef int (*AMDolphinRunFunction)(UIView *renderView, const char *path);
typedef void (*AMDolphinStopFunction)(void);
typedef bool (*AMDolphinIsRunningFunction)(void);
typedef const char *(*AMDolphinLastErrorFunction)(void);
typedef int (*AMDolphinStateFunction)(int slot);
typedef int (*AMDolphinSimpleFunction)(void);

static AMDolphinInitializeFunction gDolphinInitialize = NULL;
static AMDolphinRunFunction gDolphinRun = NULL;
static AMDolphinStopFunction gDolphinStop = NULL;
static AMDolphinIsRunningFunction gDolphinIsRunning = NULL;
static AMDolphinLastErrorFunction gDolphinLastError = NULL;
static AMDolphinStateFunction gDolphinSaveState = NULL;
static AMDolphinStateFunction gDolphinLoadState = NULL;
static AMDolphinSimpleFunction gDolphinSaveScreenshot = NULL;
static BOOL gDolphinJITHandshakeComplete = NO;

static NSString * const AMDolphinExternalFolderBookmarkKey = @"AMDolphinExternalFolderBookmark";
static NSString * const AMDolphinExternalFolderPathKey = @"AMDolphinExternalFolderPath";
static NSString * const AMDolphinOverlayAutoHideKey = @"AMDolphinOverlayAutoHide";
static NSString * const AMDolphinCPUThreadKey = @"AMDolphinCPUThread";
static NSString * const AMDolphinSyncGPUKey = @"AMDolphinSyncGPU";
static NSString * const AMDolphinDSPJITKey = @"AMDolphinDSPJIT";
static NSString * const AMDolphinFastmemKey = @"AMDolphinFastmem";
static NSString * const AMDolphinGCPadProfileEnabledKey = @"AMDolphinGCPadProfileEnabled";
static NSString * const AMDolphinWiimoteProfileEnabledKey = @"AMDolphinWiimoteProfileEnabled";
static NSString * const AMDolphinAspectRatioKey = @"AMDolphinAspectRatio";
static NSString * const AMDolphinVSyncKey = @"AMDolphinVSync";
static NSString * const AMDolphinShaderModeKey = @"AMDolphinShaderMode";
static NSString * const AMDolphinWaitForShadersKey = @"AMDolphinWaitForShaders";
static NSString * const AMDolphinWiiWidescreenKey = @"AMDolphinWiiWidescreen";
static NSString * const AMDolphinWiiLanguageKey = @"AMDolphinWiiLanguage";
static NSString * const AMDolphinWiiSoundModeKey = @"AMDolphinWiiSoundMode";
static NSString * const AMDolphinWiiSensorBarPositionKey = @"AMDolphinWiiSensorBarPosition";
static NSString * const AMDolphinWiiSensorBarSensitivityKey = @"AMDolphinWiiSensorBarSensitivity";
static NSString * const AMDolphinWiiSpeakerVolumeKey = @"AMDolphinWiiSpeakerVolume";
static NSString * const AMDolphinWiiRumbleKey = @"AMDolphinWiiRumble";
static NSString * const AMDolphinWiiPAL60Key = @"AMDolphinWiiPAL60";
static NSString * const AMDolphinWiiScreenSaverKey = @"AMDolphinWiiScreenSaver";
static NSString * const AMDolphinWiiKeyboardKey = @"AMDolphinWiiKeyboard";
static NSString * const AMDolphinWiiConnect24Key = @"AMDolphinWiiConnect24";
static NSString * const AMDolphinSkylanderPortalKey = @"AMDolphinSkylanderPortal";
static NSString * const AMDolphinWiiSDCardKey = @"AMDolphinWiiSDCard";
static NSString * const AMDolphinWiiSDWritesKey = @"AMDolphinWiiSDWrites";
static NSString * const AMDolphinWiiSDFolderSyncKey = @"AMDolphinWiiSDFolderSync";
static NSString * const AMDolphinEFBScaleKey = @"AMDolphinEFBScale";
static NSString * const AMDolphinScaledEFBKey = @"AMDolphinScaledEFB";
static NSString * const AMDolphinAnisotropyKey = @"AMDolphinAnisotropy";
static NSString * const AMDolphinTextureFilteringKey = @"AMDolphinTextureFiltering";
static NSString * const AMDolphinWidescreenHackKey = @"AMDolphinWidescreenHack";
static NSString * const AMDolphinDisableFogKey = @"AMDolphinDisableFog";
static NSString * const AMDolphinDisableCopyFilterKey = @"AMDolphinDisableCopyFilter";
static NSString * const AMDolphinPixelLightingKey = @"AMDolphinPixelLighting";
static NSString * const AMDolphinForceTrueColorKey = @"AMDolphinForceTrueColor";
static NSString * const AMDolphinArbitraryMipmapKey = @"AMDolphinArbitraryMipmap";
static NSString * const AMDolphinEFBAccessKey = @"AMDolphinEFBAccess";
static NSString * const AMDolphinEFBToTextureKey = @"AMDolphinEFBToTexture";
static NSString * const AMDolphinEFBFormatChangesKey = @"AMDolphinEFBFormatChanges";
static NSString * const AMDolphinDeferEFBCopiesKey = @"AMDolphinDeferEFBCopies";
static NSString * const AMDolphinGPUTextureDecodingKey = @"AMDolphinGPUTextureDecoding";
static NSString * const AMDolphinXFBToTextureKey = @"AMDolphinXFBToTexture";
static NSString * const AMDolphinImmediateXFBKey = @"AMDolphinImmediateXFB";
static NSString * const AMDolphinSkipDuplicateXFBsKey = @"AMDolphinSkipDuplicateXFBs";
static NSString * const AMDolphinFastDepthKey = @"AMDolphinFastDepth";
static NSString * const AMDolphinVertexRoundingKey = @"AMDolphinVertexRounding";
static NSString * const AMDolphinBBoxKey = @"AMDolphinBBox";
static NSString * const AMDolphinSaveTextureCacheToStateKey = @"AMDolphinSaveTextureCacheToState";
static NSString * const AMDolphinVISkipKey = @"AMDolphinVISkip";
static NSString * const AMDolphinTextureCacheAccuracyKey = @"AMDolphinTextureCacheAccuracy";

static BOOL AMDolphinBoolSetting(NSString *key, BOOL defaultValue)
{
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value boolValue] : defaultValue;
}

static NSInteger AMDolphinIntegerSetting(NSString *key, NSInteger defaultValue)
{
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value integerValue] : defaultValue;
}

static NSString *AMDolphinInternalResolutionTitle(NSInteger scale)
{
    if (scale <= 0) {
        return @"Auto";
    }
    return [NSString stringWithFormat:@"%ldx Native", (long)scale];
}

static NSString *AMDolphinAnisotropyTitle(NSInteger value)
{
    switch (value) {
        case 0:
            return @"1x";
        case 1:
            return @"2x";
        case 2:
            return @"4x";
        case 3:
            return @"8x";
        case 4:
            return @"16x";
        default:
            return @"Default";
    }
}

static NSString *AMDolphinTextureFilteringTitle(NSInteger value)
{
    switch (value) {
        case 1:
            return @"Nearest";
        case 2:
            return @"Linear";
        default:
            return @"Default";
    }
}

static NSString *AMDolphinAspectRatioTitle(NSInteger value)
{
    switch (value) {
        case 1:
            return @"Force 4:3";
        case 2:
            return @"Force 16:9";
        case 3:
            return @"Stretch to Window";
        default:
            return @"Auto";
    }
}

static NSString *AMDolphinWiiAspectRatioTitle(BOOL widescreen)
{
    return widescreen ? @"16:9" : @"4:3";
}

static NSString *AMDolphinWiiLanguageTitle(NSInteger value)
{
    NSArray<NSString *> *titles = @[
        @"Japanese", @"English", @"German", @"French", @"Spanish",
        @"Italian", @"Dutch", @"Simplified Chinese", @"Traditional Chinese", @"Korean"
    ];
    return value >= 0 && value < (NSInteger)titles.count ? titles[value] : @"English";
}

static NSString *AMDolphinWiiSoundTitle(NSInteger value)
{
    switch (value) {
        case 0:
            return @"Mono";
        case 2:
            return @"Surround";
        default:
            return @"Stereo";
    }
}

static NSString *AMDolphinWiiSensorBarTitle(NSInteger value)
{
    return value == 0 ? @"Bottom" : @"Top";
}

static NSString *AMDolphinShaderModeTitle(NSInteger value)
{
    switch (value) {
        case 1:
            return @"Exclusive Ubershaders";
        case 2:
            return @"Hybrid Ubershaders";
        case 3:
            return @"Skip Drawing";
        default:
            return @"Specialized";
    }
}

static NSString *AMDolphinTextureCacheAccuracyTitle(NSInteger value)
{
    switch (value) {
        case 0:
            return @"Fast";
        case 512:
            return @"Safe";
        default:
            return @"Medium";
    }
}

static NSArray<NSString *> *AMDolphinExternalStorageSubdirectories(void)
{
    return @[
        @"Software",
        @"Config",
        @"GC",
        @"GC/JPN",
        @"GC/JPN/Card A",
        @"GC/USA/Card A",
        @"GC/EUR/Card A",
        @"Wii",
        @"Logs",
        @"StateSaves",
        @"Cache",
    ];
}

static NSURL *AMDolphinResolveExternalFolderURL(BOOL startAccessing)
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *bookmarkData = [defaults dataForKey:AMDolphinExternalFolderBookmarkKey];
    if (bookmarkData.length > 0) {
        BOOL stale = NO;
        NSError *error = nil;
        NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                options:0
                                          relativeToURL:nil
                                    bookmarkDataIsStale:&stale
                                                  error:&error];
        if (url && !stale) {
            if (startAccessing) {
                [url startAccessingSecurityScopedResource];
            }
            return url;
        }
        NSLog(@"[Dolphin] External folder bookmark failed: stale=%d error=%@", stale, error.localizedDescription);
    }

    NSString *forcedPath = @(getenv("AM_DOLPHIN_HOME") ?: "");
    if (forcedPath.length > 0) {
        return [NSURL fileURLWithPath:forcedPath isDirectory:YES];
    }

    return nil;
}

static void AMDolphinStoreExternalFolderURL(NSURL *url)
{
    NSError *error = nil;
    NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil
                                                  error:&error];
    if (bookmarkData.length == 0) {
        NSLog(@"[Dolphin] Failed to store external folder bookmark: %@", error.localizedDescription);
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:bookmarkData forKey:AMDolphinExternalFolderBookmarkKey];
    [defaults setObject:url.path ?: @"" forKey:AMDolphinExternalFolderPathKey];
    [defaults synchronize];
}

static void AMDolphinEnsureExternalStorageLayout(NSURL *rootURL)
{
    if (!rootURL) {
        return;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *relativePath in AMDolphinExternalStorageSubdirectories()) {
        NSURL *directoryURL = [rootURL URLByAppendingPathComponent:relativePath isDirectory:YES];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:directoryURL.path isDirectory:&isDirectory] && !isDirectory) {
            NSURL *backupURL = [directoryURL.URLByDeletingLastPathComponent
                URLByAppendingPathComponent:[directoryURL.lastPathComponent stringByAppendingString:@".misplaced"]];
            [fileManager removeItemAtURL:backupURL error:nil];
            NSError *moveError = nil;
            if (![fileManager moveItemAtURL:directoryURL toURL:backupURL error:&moveError]) {
                NSLog(@"[Dolphin] Failed to move misplaced external path %@: %@", directoryURL.path, moveError.localizedDescription);
            }
        }

        NSError *createError = nil;
        if (![fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&createError]) {
            NSLog(@"[Dolphin] Failed to create external path %@: %@", directoryURL.path, createError.localizedDescription);
        }
    }
}

static BOOL AMDolphinWriteProbeAtDirectory(NSURL *directoryURL, NSString **failureMessage)
{
    if (!directoryURL) {
        if (failureMessage) {
            *failureMessage = @"External folder is not selected.";
        }
        return NO;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    __block NSError *directoryCreateError = nil;
    NSError *coordinationError = nil;
    NSFileCoordinator *directoryCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block BOOL directoryOK = NO;
    [directoryCoordinator coordinateWritingItemAtURL:directoryURL options:0 error:&coordinationError byAccessor:^(__unused NSURL *newURL) {
        directoryOK = [fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&directoryCreateError];
    }];
    if (!directoryOK) {
        if (failureMessage) {
            NSError *directoryError = directoryCreateError ?: coordinationError;
            *failureMessage = [NSString stringWithFormat:@"%@: %@", directoryURL.path, directoryError.localizedDescription];
        }
        return NO;
    }

    __block NSError *writeError = nil;
    __block BOOL writeOK = NO;
    NSURL *probeURL = [directoryURL URLByAppendingPathComponent:@".amethyst-write-test" isDirectory:NO];
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateWritingItemAtURL:probeURL options:0 error:&writeError byAccessor:^(NSURL *newURL) {
        NSString *content = [NSString stringWithFormat:@"write-test %@\n", NSDate.date];
        writeOK = [content writeToURL:newURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    }];

    if (!writeOK) {
        if (failureMessage) {
            *failureMessage = [NSString stringWithFormat:@"%@: %@", probeURL.path, writeError.localizedDescription];
        }
        return NO;
    }

    __block NSError *removeError = nil;
    [coordinator coordinateWritingItemAtURL:probeURL options:NSFileCoordinatorWritingForDeleting error:&removeError byAccessor:^(NSURL *newURL) {
        [fileManager removeItemAtURL:newURL error:&removeError];
    }];
    return YES;
}

static BOOL AMDolphinVerifyExternalStorageWritable(NSURL *rootURL, NSString **failureMessage)
{
    if (!rootURL) {
        if (failureMessage) {
            *failureMessage = @"External folder is not selected.";
        }
        return NO;
    }

    AMDolphinEnsureExternalStorageLayout(rootURL);
    NSArray<NSString *> *probePaths = @[
        @"",
        @"Software",
        @"Config",
        @"GC/JPN/Card A",
        @"Wii",
        @"Logs",
        @"StateSaves",
    ];

    for (NSString *relativePath in probePaths) {
        NSURL *directoryURL = relativePath.length > 0
            ? [rootURL URLByAppendingPathComponent:relativePath isDirectory:YES]
            : rootURL;
        if (!AMDolphinWriteProbeAtDirectory(directoryURL, failureMessage)) {
            return NO;
        }
    }

    return YES;
}

static NSURL *AMDolphinExternalStorageURL(void)
{
    NSURL *url = AMDolphinResolveExternalFolderURL(YES);
    AMDolphinEnsureExternalStorageLayout(url);
    return url;
}

static BOOL AMDolphinExternalStorageReady(NSURL *rootURL, NSString **failureMessage)
{
    if (![rootURL startAccessingSecurityScopedResource]) {
        NSLog(@"[Dolphin] External folder startAccessing returned NO for %@", rootURL.path);
    }
    return AMDolphinVerifyExternalStorageWritable(rootURL, failureMessage);
}

static NSString *AMDolphinConnectedMFiDeviceIdentifier(void)
{
    GCController *controller = GCController.controllers.firstObject;
    NSString *name = controller.vendorName.length > 0 ? controller.vendorName : @"Select Device";
    return [NSString stringWithFormat:@"MFi/0/%@", name];
}

static NSString *AMDolphinControllerSummary(void)
{
    NSUInteger count = GCController.controllers.count;
    return [NSString stringWithFormat:@"%lu detected by GameController.framework", (unsigned long)count];
}

static NSString *AMDolphinControllerDiagnosticsText(void)
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSArray<GCController *> *controllers = GCController.controllers;
    [lines addObject:[NSString stringWithFormat:@"GameController count: %lu", (unsigned long)controllers.count]];

    [controllers enumerateObjectsUsingBlock:^(GCController *controller, NSUInteger index, __unused BOOL *stop) {
        NSString *vendor = controller.vendorName ?: @"(no vendor)";
        NSString *category = @"(no category)";
        if ([controller respondsToSelector:@selector(productCategory)]) {
            category = controller.productCategory ?: @"(no category)";
        }
        [lines addObject:[NSString stringWithFormat:@"%lu. %@ / %@", (unsigned long)index + 1, vendor, category]];
        [lines addObject:[NSString stringWithFormat:@"   extended=%@ gamepad=%@ micro=%@ motion=%@",
                          controller.extendedGamepad ? @"yes" : @"no",
                          controller.gamepad ? @"yes" : @"no",
                          controller.microGamepad ? @"yes" : @"no",
                          controller.motion ? @"yes" : @"no"]];
    }];

    if (@available(iOS 14.0, *)) {
        [lines addObject:[NSString stringWithFormat:@"Keyboard: %@",
                          GCKeyboard.coalescedKeyboard ? @"detected" : @"none"]];
    }

    return [lines componentsJoinedByString:@"\n"];
}

static void AMDolphinLogControllerDiagnostics(void)
{
    NSLog(@"[Dolphin] Controller diagnostics:\n%@", AMDolphinControllerDiagnosticsText());
}

static NSURL *AMDolphinControllerDiagnosticsFileURL(NSURL *userDirectoryURL)
{
    NSURL *rootURL = userDirectoryURL ?: AMDolphinExternalStorageURL();
    return [rootURL URLByAppendingPathComponent:@"dolphin-controller-diagnostics.txt"];
}

static void AMDolphinWriteControllerDiagnosticsSnapshot(NSString *reason, NSURL *userDirectoryURL)
{
    NSURL *fileURL = AMDolphinControllerDiagnosticsFileURL(userDirectoryURL);
    if (!fileURL) {
        NSLog(@"[Dolphin] Controller diagnostics skipped: no external folder");
        return;
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZZ";

    NSString *content = [NSString stringWithFormat:@"reason: %@\ntime: %@\n%@\n",
                         reason ?: @"unknown",
                         [formatter stringFromDate:NSDate.date],
                         AMDolphinControllerDiagnosticsText()];
    NSError *error = nil;
    BOOL ok = [content writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSLog(@"[Dolphin] Controller diagnostics file %@: %@ error=%@",
          ok ? @"written" : @"failed", fileURL.path, error);
}

static NSString *AMDolphinLastErrorMessage(void)
{
    if (!gDolphinLastError) {
        return @"Unknown Dolphin error.";
    }

    const char *error = gDolphinLastError();
    return error && error[0] != '\0' ? @(error) : @"Unknown Dolphin error.";
}

static BOOL AMDolphinHasHostJIT(void)
{
    return isJITEnabled(false);
}

static BOOL AMDolphinNeedsTXMJITHandshake(void)
{
    if (@available(iOS 26, *)) {
        return DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM);
    }
    return NO;
}

static BOOL AMDolphinCanBootWithCurrentJIT(void)
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:@"AMInternalDolphinJITHandshakeComplete"]) {
        gDolphinJITHandshakeComplete = YES;
    }

    BOOL hasHostJIT = AMDolphinHasHostJIT();
    if (hasHostJIT) {
        gDolphinJITHandshakeComplete = YES;
        [defaults setBool:YES forKey:@"AMInternalDolphinJITHandshakeComplete"];
        [defaults synchronize];
    }

    NSLog(@"[Dolphin] JIT gate host=%d strict=%d txmNeeded=%d handshake=%d",
          hasHostJIT,
          isJITEnabled(true),
          AMDolphinNeedsTXMJITHandshake(),
          gDolphinJITHandshakeComplete);
    return hasHostJIT || gDolphinJITHandshakeComplete;
}

static void AMDolphinEnsureDirectoryAtURL(NSURL *directoryURL)
{
    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:directoryURL.path isDirectory:&isDirectory] && !isDirectory) {
        NSURL *misplacedURL = [directoryURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:[directoryURL.lastPathComponent stringByAppendingString:@".misplaced.gci"]];
        [fileManager removeItemAtURL:misplacedURL error:nil];
        NSError *moveError = nil;
        if (![fileManager moveItemAtURL:directoryURL toURL:misplacedURL error:&moveError]) {
            NSLog(@"[Dolphin] Failed to move misplaced save path %@: %@", directoryURL.path, moveError.localizedDescription);
        }
    }

    NSError *createError = nil;
    if (![fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&createError]) {
        NSLog(@"[Dolphin] Failed to create save directory %@: %@", directoryURL.path, createError.localizedDescription);
    }
}

static void AMDolphinRemoveMisplacedGCIBackups(NSURL *directoryURL)
{
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSArray<NSURL *> *files = [fileManager contentsOfDirectoryAtURL:directoryURL
                                         includingPropertiesForKeys:nil
                                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                                              error:nil];
    for (NSURL *fileURL in files) {
        if ([fileURL.lastPathComponent containsString:@".misplaced.gci"]) {
            [fileManager removeItemAtURL:fileURL error:nil];
        }
    }
}

static NSDate *AMDolphinModificationDate(NSURL *fileURL)
{
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:fileURL.path error:nil];
    return attributes[NSFileModificationDate];
}

static NSString *AMDolphinHexForData(NSData *data)
{
    const unsigned char *bytes = data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger index = 0; index < data.length; index++) {
        [hex appendFormat:@"%02x", bytes[index]];
    }
    return hex;
}

static NSString *AMDolphinPrintableASCII(NSData *data)
{
    const unsigned char *bytes = data.bytes;
    NSMutableString *string = [NSMutableString stringWithCapacity:data.length];
    for (NSUInteger index = 0; index < data.length; index++) {
        unsigned char byte = bytes[index];
        [string appendFormat:@"%c", byte >= 0x20 && byte <= 0x7e ? byte : '.'];
    }
    return string;
}

static NSString *AMDolphinGCIHeaderSummary(NSURL *fileURL)
{
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:nil];
    if (data.length < 0x40) {
        return @"header=unreadable";
    }

    NSData *gameCode = [data subdataWithRange:NSMakeRange(0x00, 4)];
    NSData *makerCode = [data subdataWithRange:NSMakeRange(0x04, 2)];
    NSData *internalName = [data subdataWithRange:NSMakeRange(0x08, 0x20)];
    NSData *blockCount = [data subdataWithRange:NSMakeRange(0x38, 2)];
    const unsigned char *blockBytes = blockCount.bytes;
    unsigned int blocks = ((unsigned int)blockBytes[0] << 8) | blockBytes[1];
    return [NSString stringWithFormat:@"game=%@ maker=%@ name=%@ blocks=%u header40=%@",
            AMDolphinPrintableASCII(gameCode),
            AMDolphinPrintableASCII(makerCode),
            AMDolphinPrintableASCII(internalName),
            blocks,
            AMDolphinHexForData([data subdataWithRange:NSMakeRange(0, 0x40)])];
}

static NSString *AMDolphinRelativePath(NSURL *rootURL, NSURL *fileURL)
{
    NSString *rootPath = rootURL.path;
    NSString *filePath = fileURL.path;
    if ([filePath hasPrefix:rootPath]) {
        NSString *relative = [filePath substringFromIndex:rootPath.length];
        return [relative hasPrefix:@"/"] ? [relative substringFromIndex:1] : relative;
    }
    return filePath;
}

static void AMDolphinAppendDirectoryState(NSMutableString *text, NSURL *rootURL, NSString *relativePath)
{
    NSURL *url = [rootURL URLByAppendingPathComponent:relativePath];
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDirectory];
    [text appendFormat:@"path=%@ exists=%@ directory=%@\n", relativePath, exists ? @"yes" : @"no", isDirectory ? @"yes" : @"no"];
}

static void AMDolphinWriteSaveDiagnostics(NSURL *userDirectoryURL, NSString *reason)
{
    NSMutableString *text = [NSMutableString string];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZZ";
    [text appendFormat:@"reason=%@\n", reason ?: @"unknown"];
    [text appendFormat:@"time=%@\n", [formatter stringFromDate:NSDate.date]];
    [text appendFormat:@"userDirectory=%@\n\n", userDirectoryURL.path];

    NSArray<NSString *> *interestingPaths = @[
        @"GC",
        @"GC/JPN",
        @"GC/JPN/Card A",
        @"GC/JAP",
        @"GC/JAP/Card A",
        @"GC/USA/Card A",
        @"Wii/title/00010000/5246454a/data",
        @"Wii/title/00010000/52464545/data",
        @"StateSaves",
    ];
    for (NSString *path in interestingPaths) {
        AMDolphinAppendDirectoryState(text, userDirectoryURL, path);
    }

    [text appendString:@"\nfiles=\n"];
    NSDirectoryEnumerator<NSURL *> *enumerator = [NSFileManager.defaultManager enumeratorAtURL:userDirectoryURL
                                                                    includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey, NSURLContentModificationDateKey]
                                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                  errorHandler:^BOOL(NSURL *url, NSError *error) {
        [text appendFormat:@"enumerationError %@: %@\n", url.path, error.localizedDescription];
        return YES;
    }];
    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) {
            continue;
        }

        NSString *extension = url.pathExtension.lowercaseString;
        BOOL interesting = [extension isEqualToString:@"gci"]
            || [extension isEqualToString:@"raw"]
            || [extension isEqualToString:@"dat"]
            || [url.lastPathComponent isEqualToString:@"banner.bin"]
            || [url.lastPathComponent isEqualToString:@"MC_SYSTEM_AREA"];
        if (!interesting) {
            continue;
        }

        NSNumber *fileSize = nil;
        NSDate *modificationDate = nil;
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        [url getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:nil];
        [text appendFormat:@"%@ size=%@ modified=%@",
         AMDolphinRelativePath(userDirectoryURL, url),
         fileSize ?: @0,
         modificationDate ? [formatter stringFromDate:modificationDate] : @"unknown"];
        if ([extension isEqualToString:@"gci"]) {
            [text appendFormat:@" %@", AMDolphinGCIHeaderSummary(url)];
        }
        [text appendString:@"\n"];
    }

    NSURL *diagnosticsURL = [userDirectoryURL URLByAppendingPathComponent:@"dolphin-save-diagnostics.txt"];
    NSError *error = nil;
    BOOL ok = [text writeToURL:diagnosticsURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSLog(@"[Dolphin] Save diagnostics %@: %@ error=%@", ok ? @"written" : @"failed", diagnosticsURL.path, error);
    NSLog(@"[Dolphin] Save diagnostics content:\n%@", text);
}

@interface AMDolphinRenderViewController : UIViewController

- (instancetype)initWithGameURL:(NSURL *)gameURL userDirectoryURL:(NSURL *)userDirectoryURL jitType:(int)jitType;

@end

@interface AMDolphinRenderViewController ()

@property(nonatomic) NSURL *gameURL;
@property(nonatomic) NSURL *userDirectoryURL;
@property(nonatomic) int jitType;
@property(nonatomic) BOOL didStart;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) NSTimer *controlsHideTimer;
@property(nonatomic) BOOL statusShouldStayVisible;
@property(nonatomic) BOOL overlayAutoHide;
@property(nonatomic) NSInteger stateSlot;
@property(nonatomic) BOOL accessingSecurityScopedUserDirectory;

@end

@implementation AMDolphinRenderViewController

- (instancetype)initWithGameURL:(NSURL *)gameURL userDirectoryURL:(NSURL *)userDirectoryURL jitType:(int)jitType
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _gameURL = gameURL;
        _userDirectoryURL = userDirectoryURL;
        _jitType = jitType;
        _overlayAutoHide = AMDolphinBoolSetting(AMDolphinOverlayAutoHideKey, YES);
        _stateSlot = MAX(1, [NSUserDefaults.standardUserDefaults integerForKey:@"AMDolphinStateSlot"]);
        self.title = gameURL.lastPathComponent ?: @"Dolphin";
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

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Dolphin"
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
    self.statusLabel.text = @"Starting Dolphin...";
    [self.view addSubview:self.statusLabel];
    self.statusShouldStayVisible = YES;

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOverlayTap:)];
    tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapRecognizer];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:self.overlayAutoHide animated:animated];
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
    self.controlsHideTimer = nil;
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
            [NSUserDefaults.standardUserDefaults setInteger:slot forKey:@"AMDolphinStateSlot"];
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
                                             handler:^(__unused UIAction *action) {
        [self saveState];
    }];
    UIAction *loadAction = [UIAction actionWithTitle:@"Load State"
                                               image:[UIImage systemImageNamed:@"tray.and.arrow.down"]
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
        [self loadState];
    }];
    UIAction *screenshotAction = [UIAction actionWithTitle:@"Screenshot"
                                                     image:[UIImage systemImageNamed:@"camera"]
                                                identifier:nil
                                                   handler:^(__unused UIAction *action) {
        [self saveScreenshot];
    }];
    UIAction *stopAction = [UIAction actionWithTitle:@"Stop"
                                               image:[UIImage systemImageNamed:@"stop.circle"]
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
        [self closeGame];
    }];
    stopAction.attributes = UIMenuElementAttributesDestructive;

    UIMenu *menu = [UIMenu menuWithChildren:@[
        [UIMenu menuWithTitle:@"State Slot" image:nil identifier:nil options:0 children:slotActions],
        saveAction,
        loadAction,
        screenshotAction,
        stopAction,
    ]];
    UIBarButtonItem *menuButton = [[UIBarButtonItem alloc] initWithTitle:@"Menu"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];
    menuButton.menu = menu;
    self.navigationItem.rightBarButtonItem = menuButton;
}

- (void)handleOverlayTap:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self showControlsTemporarily];
    }
}

- (void)showControlsTemporarily
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.statusLabel.hidden = NO;
    [self.view bringSubviewToFront:self.statusLabel];

    [self.controlsHideTimer invalidate];
    if (!self.overlayAutoHide) {
        self.controlsHideTimer = nil;
        return;
    }
    self.controlsHideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                              target:self
                                                            selector:@selector(hideTransientControls)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void)hideTransientControls
{
    self.controlsHideTimer = nil;
    if (!self.overlayAutoHide) {
        return;
    }
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    if (!self.statusShouldStayVisible) {
        self.statusLabel.hidden = YES;
    }
}

- (void)setStatusText:(NSString *)text keepsVisible:(BOOL)keepsVisible
{
    self.statusShouldStayVisible = keepsVisible;
    self.statusLabel.text = text;
    self.statusLabel.hidden = !keepsVisible && self.navigationController.navigationBarHidden;
    [self.view bringSubviewToFront:self.statusLabel];
}

- (void)saveState
{
    [self performStateOperation:gDolphinSaveState name:@"Save State"];
}

- (void)loadState
{
    [self performStateOperation:gDolphinLoadState name:@"Load State"];
}

- (void)saveScreenshot
{
    if (!gDolphinSaveScreenshot) {
        [self setStatusText:@"Screenshot is not available." keepsVisible:YES];
        [self showControlsTemporarily];
        return;
    }

    int result = gDolphinSaveScreenshot();
    [self setStatusText:result == 0 ? @"Screenshot queued" : AMDolphinLastErrorMessage()
           keepsVisible:result != 0];
    [self showControlsTemporarily];
}

- (void)performStateOperation:(AMDolphinStateFunction)operation name:(NSString *)name
{
    if (!operation) {
        [self setStatusText:[NSString stringWithFormat:@"%@ is not available.", name] keepsVisible:YES];
        [self showControlsTemporarily];
        return;
    }

    int result = operation((int)self.stateSlot);
    if (result == 0) {
        [self setStatusText:[NSString stringWithFormat:@"%@ queued: slot %ld", name, (long)self.stateSlot] keepsVisible:NO];
    } else {
        [self setStatusText:AMDolphinLastErrorMessage() keepsVisible:YES];
    }
    [self showControlsTemporarily];
}

- (void)startEmulation
{
    if (!gDolphinInitialize || !gDolphinRun) {
        NSLog(@"[Dolphin] Start failed: bridge is not loaded");
        [self setStatusText:@"Dolphin bridge is not loaded." keepsVisible:YES];
        [self showControlsTemporarily];
        return;
    }

    NSLog(@"[Dolphin] Starting game: %@", self.gameURL.path);
    NSLog(@"[Dolphin] User directory: %@", self.userDirectoryURL.path);
    NSLog(@"[Dolphin] JIT type: %d", self.jitType);
    [self setStatusText:@"Initializing Dolphin..." keepsVisible:YES];

    NSString *userDirectoryPath = self.userDirectoryURL.path;
    NSString *gamePath = self.gameURL.path;
    NSString *gameName = self.gameURL.lastPathComponent ?: @"";
    UIView *renderView = self.view;
    int jitType = self.jitType;
    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int initResult = gDolphinInitialize(userDirectoryPath.UTF8String, jitType);
        NSLog(@"[Dolphin] Initialize returned: %d", initResult);
        if (initResult != 0) {
            NSString *message = AMDolphinLastErrorMessage();
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setStatusText:message keepsVisible:YES];
                [weakSelf showControlsTemporarily];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setStatusText:@"Booting Dolphin..." keepsVisible:YES];
        });

        int runResult = gDolphinRun(renderView, gamePath.UTF8String);
        NSLog(@"[Dolphin] Run returned: %d", runResult);
        if (runResult != 0) {
            NSString *message = AMDolphinLastErrorMessage();
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setStatusText:message keepsVisible:YES];
                [weakSelf showControlsTemporarily];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setStatusText:[NSString stringWithFormat:@"Running\n%@", gameName] keepsVisible:NO];
            [weakSelf hideTransientControls];
        });
    });
}

- (void)stopEmulation
{
    if (gDolphinStop && (!gDolphinIsRunning || gDolphinIsRunning())) {
        gDolphinStop();
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

@end

typedef NS_ENUM(NSInteger, AMDolphinInputProfileKind) {
    AMDolphinInputProfileKindGCPad = 0,
    AMDolphinInputProfileKindWiimote = 1,
};

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinGCPadTouchBindings(void)
{
    return @[
        @{@"label": @"Device", @"key": @"Device", @"value": @"iOS/0/Touchscreen"},
        @{@"label": @"A", @"key": @"Buttons/A", @"value": @"`Button 0`"},
        @{@"label": @"B", @"key": @"Buttons/B", @"value": @"`Button 1`"},
        @{@"label": @"Start", @"key": @"Buttons/Start", @"value": @"`Button 2`"},
        @{@"label": @"X", @"key": @"Buttons/X", @"value": @"`Button 3`"},
        @{@"label": @"Y", @"key": @"Buttons/Y", @"value": @"`Button 4`"},
        @{@"label": @"Z", @"key": @"Buttons/Z", @"value": @"`Button 5`"},
        @{@"label": @"D-Pad Up", @"key": @"D-Pad/Up", @"value": @"`Button 6`"},
        @{@"label": @"D-Pad Down", @"key": @"D-Pad/Down", @"value": @"`Button 7`"},
        @{@"label": @"D-Pad Left", @"key": @"D-Pad/Left", @"value": @"`Button 8`"},
        @{@"label": @"D-Pad Right", @"key": @"D-Pad/Right", @"value": @"`Button 9`"},
        @{@"label": @"Main Stick Up", @"key": @"Main Stick/Up", @"value": @"`Axis 11`"},
        @{@"label": @"Main Stick Down", @"key": @"Main Stick/Down", @"value": @"`Axis 12`"},
        @{@"label": @"Main Stick Left", @"key": @"Main Stick/Left", @"value": @"`Axis 13`"},
        @{@"label": @"Main Stick Right", @"key": @"Main Stick/Right", @"value": @"`Axis 14`"},
        @{@"label": @"C-Stick Up", @"key": @"C-Stick/Up", @"value": @"`Axis 16`"},
        @{@"label": @"C-Stick Down", @"key": @"C-Stick/Down", @"value": @"`Axis 17`"},
        @{@"label": @"C-Stick Left", @"key": @"C-Stick/Left", @"value": @"`Axis 18`"},
        @{@"label": @"C-Stick Right", @"key": @"C-Stick/Right", @"value": @"`Axis 19`"},
        @{@"label": @"L", @"key": @"Triggers/L", @"value": @"`Axis 20`"},
        @{@"label": @"R", @"key": @"Triggers/R", @"value": @"`Axis 21`"},
        @{@"label": @"L Analog", @"key": @"Triggers/L-Analog", @"value": @"`Axis 20`"},
        @{@"label": @"R Analog", @"key": @"Triggers/R-Analog", @"value": @"`Axis 21`"},
        @{@"label": @"Trigger Threshold", @"key": @"Triggers/Threshold", @"value": @"90,000000"},
        @{@"label": @"Rumble", @"key": @"Rumble/Motor", @"value": @"`Rumble 700`"},
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinGCPadMFIBindings(void)
{
    return @[
        @{@"label": @"Device", @"key": @"Device", @"value": AMDolphinConnectedMFiDeviceIdentifier()},
        @{@"label": @"A", @"key": @"Buttons/A", @"value": @"`Button A`"},
        @{@"label": @"B", @"key": @"Buttons/B", @"value": @"`Button B`"},
        @{@"label": @"Start", @"key": @"Buttons/Start", @"value": @"`Menu`"},
        @{@"label": @"X", @"key": @"Buttons/X", @"value": @"`Button X`"},
        @{@"label": @"Y", @"key": @"Buttons/Y", @"value": @"`Button Y`"},
        @{@"label": @"Z", @"key": @"Buttons/Z", @"value": @"`R Shoulder`"},
        @{@"label": @"D-Pad Up", @"key": @"D-Pad/Up", @"value": @"`D-Pad Up`"},
        @{@"label": @"D-Pad Down", @"key": @"D-Pad/Down", @"value": @"`D-Pad Down`"},
        @{@"label": @"D-Pad Left", @"key": @"D-Pad/Left", @"value": @"`D-Pad Left`"},
        @{@"label": @"D-Pad Right", @"key": @"D-Pad/Right", @"value": @"`D-Pad Right`"},
        @{@"label": @"Main Stick Up", @"key": @"Main Stick/Up", @"value": @"`L Stick Y+`"},
        @{@"label": @"Main Stick Down", @"key": @"Main Stick/Down", @"value": @"`L Stick Y-`"},
        @{@"label": @"Main Stick Left", @"key": @"Main Stick/Left", @"value": @"`L Stick X-`"},
        @{@"label": @"Main Stick Right", @"key": @"Main Stick/Right", @"value": @"`L Stick X+`"},
        @{@"label": @"C-Stick Up", @"key": @"C-Stick/Up", @"value": @"`R Stick Y+`"},
        @{@"label": @"C-Stick Down", @"key": @"C-Stick/Down", @"value": @"`R Stick Y-`"},
        @{@"label": @"C-Stick Left", @"key": @"C-Stick/Left", @"value": @"`R Stick X-`"},
        @{@"label": @"C-Stick Right", @"key": @"C-Stick/Right", @"value": @"`R Stick X+`"},
        @{@"label": @"L", @"key": @"Triggers/L", @"value": @"`L Trigger`"},
        @{@"label": @"R", @"key": @"Triggers/R", @"value": @"`R Trigger`"},
        @{@"label": @"L Analog", @"key": @"Triggers/L-Analog", @"value": @"`L Trigger`"},
        @{@"label": @"R Analog", @"key": @"Triggers/R-Analog", @"value": @"`R Trigger`"},
        @{@"label": @"Trigger Threshold", @"key": @"Triggers/Threshold", @"value": @"90,000000"},
        @{@"label": @"Rumble", @"key": @"Rumble/Motor", @"value": @"`Rumble`"},
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinWiimoteTouchBindings(void)
{
    return @[
        @{@"label": @"Device", @"key": @"Device", @"value": @"iOS/4/Touchscreen"},
        @{@"label": @"A", @"key": @"Buttons/A", @"value": @"`Button 100`"},
        @{@"label": @"B", @"key": @"Buttons/B", @"value": @"`Button 101`"},
        @{@"label": @"Minus", @"key": @"Buttons/-", @"value": @"`Button 102`"},
        @{@"label": @"Plus", @"key": @"Buttons/+", @"value": @"`Button 103`"},
        @{@"label": @"Home", @"key": @"Buttons/Home", @"value": @"`Button 104`"},
        @{@"label": @"1", @"key": @"Buttons/1", @"value": @"`Button 105`"},
        @{@"label": @"2", @"key": @"Buttons/2", @"value": @"`Button 106`"},
        @{@"label": @"D-Pad Up", @"key": @"D-Pad/Up", @"value": @"`Button 107`"},
        @{@"label": @"D-Pad Down", @"key": @"D-Pad/Down", @"value": @"`Button 108`"},
        @{@"label": @"D-Pad Left", @"key": @"D-Pad/Left", @"value": @"`Button 109`"},
        @{@"label": @"D-Pad Right", @"key": @"D-Pad/Right", @"value": @"`Button 110`"},
        @{@"label": @"Extension", @"key": @"Extension", @"value": @"Nunchuk"},
        @{@"label": @"Nunchuk C", @"key": @"Nunchuk/Buttons/C", @"value": @"`Button 200`"},
        @{@"label": @"Nunchuk Z", @"key": @"Nunchuk/Buttons/Z", @"value": @"`Button 201`"},
        @{@"label": @"Nunchuk Stick Up", @"key": @"Nunchuk/Stick/Up", @"value": @"`Axis 202`"},
        @{@"label": @"Nunchuk Stick Down", @"key": @"Nunchuk/Stick/Down", @"value": @"`Axis 203`"},
        @{@"label": @"Nunchuk Stick Left", @"key": @"Nunchuk/Stick/Left", @"value": @"`Axis 204`"},
        @{@"label": @"Nunchuk Stick Right", @"key": @"Nunchuk/Stick/Right", @"value": @"`Axis 205`"},
        @{@"label": @"Classic A", @"key": @"Classic/Buttons/A", @"value": @"`Button 300`"},
        @{@"label": @"Classic B", @"key": @"Classic/Buttons/B", @"value": @"`Button 301`"},
        @{@"label": @"Classic X", @"key": @"Classic/Buttons/X", @"value": @"`Button 302`"},
        @{@"label": @"Classic Y", @"key": @"Classic/Buttons/Y", @"value": @"`Button 303`"},
        @{@"label": @"Classic Minus", @"key": @"Classic/Buttons/-", @"value": @"`Button 304`"},
        @{@"label": @"Classic Plus", @"key": @"Classic/Buttons/+", @"value": @"`Button 305`"},
        @{@"label": @"Classic Home", @"key": @"Classic/Buttons/Home", @"value": @"`Button 306`"},
        @{@"label": @"Classic ZL", @"key": @"Classic/Buttons/ZL", @"value": @"`Button 307`"},
        @{@"label": @"Classic ZR", @"key": @"Classic/Buttons/ZR", @"value": @"`Button 308`"},
        @{@"label": @"Classic D-Pad Up", @"key": @"Classic/D-Pad/Up", @"value": @"`Button 309`"},
        @{@"label": @"Classic D-Pad Down", @"key": @"Classic/D-Pad/Down", @"value": @"`Button 310`"},
        @{@"label": @"Classic D-Pad Left", @"key": @"Classic/D-Pad/Left", @"value": @"`Button 311`"},
        @{@"label": @"Classic D-Pad Right", @"key": @"Classic/D-Pad/Right", @"value": @"`Button 312`"},
        @{@"label": @"Classic Left Stick Up", @"key": @"Classic/Left Stick/Up", @"value": @"`Axis 314`"},
        @{@"label": @"Classic Left Stick Down", @"key": @"Classic/Left Stick/Down", @"value": @"`Axis 315`"},
        @{@"label": @"Classic Left Stick Left", @"key": @"Classic/Left Stick/Left", @"value": @"`Axis 316`"},
        @{@"label": @"Classic Left Stick Right", @"key": @"Classic/Left Stick/Right", @"value": @"`Axis 317`"},
        @{@"label": @"Classic Right Stick Up", @"key": @"Classic/Right Stick/Up", @"value": @"`Axis 319`"},
        @{@"label": @"Classic Right Stick Down", @"key": @"Classic/Right Stick/Down", @"value": @"`Axis 320`"},
        @{@"label": @"Classic Right Stick Left", @"key": @"Classic/Right Stick/Left", @"value": @"`Axis 321`"},
        @{@"label": @"Classic Right Stick Right", @"key": @"Classic/Right Stick/Right", @"value": @"`Axis 322`"},
        @{@"label": @"Classic L", @"key": @"Classic/Triggers/L", @"value": @"`Axis 323`"},
        @{@"label": @"Classic R", @"key": @"Classic/Triggers/R", @"value": @"`Axis 324`"},
        @{@"label": @"Classic L Analog", @"key": @"Classic/Triggers/L-Analog", @"value": @"`Axis 323`"},
        @{@"label": @"Classic R Analog", @"key": @"Classic/Triggers/R-Analog", @"value": @"`Axis 324`"},
        @{@"label": @"Classic Trigger Threshold", @"key": @"Classic/Triggers/Threshold", @"value": @"90,000000"},
        @{@"label": @"Rumble", @"key": @"Rumble/Motor", @"value": @"`Rumble 700`"},
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinWiimoteMFIBindings(void)
{
    return @[
        @{@"label": @"Device", @"key": @"Device", @"value": AMDolphinConnectedMFiDeviceIdentifier()},
        @{@"label": @"A", @"key": @"Buttons/A", @"value": @"`Button A`"},
        @{@"label": @"B", @"key": @"Buttons/B", @"value": @"`Button B`"},
        @{@"label": @"Minus", @"key": @"Buttons/-", @"value": @"`Options`"},
        @{@"label": @"Plus", @"key": @"Buttons/+", @"value": @"`Menu`"},
        @{@"label": @"Home", @"key": @"Buttons/Home", @"value": @"`Home`"},
        @{@"label": @"1", @"key": @"Buttons/1", @"value": @"`Button X`"},
        @{@"label": @"2", @"key": @"Buttons/2", @"value": @"`Button Y`"},
        @{@"label": @"D-Pad Up", @"key": @"D-Pad/Up", @"value": @"`D-Pad Up`"},
        @{@"label": @"D-Pad Down", @"key": @"D-Pad/Down", @"value": @"`D-Pad Down`"},
        @{@"label": @"D-Pad Left", @"key": @"D-Pad/Left", @"value": @"`D-Pad Left`"},
        @{@"label": @"D-Pad Right", @"key": @"D-Pad/Right", @"value": @"`D-Pad Right`"},
        @{@"label": @"Extension", @"key": @"Extension", @"value": @"Nunchuk"},
        @{@"label": @"Nunchuk C", @"key": @"Nunchuk/Buttons/C", @"value": @"`L Shoulder`"},
        @{@"label": @"Nunchuk Z", @"key": @"Nunchuk/Buttons/Z", @"value": @"`L Trigger`"},
        @{@"label": @"Nunchuk Stick Up", @"key": @"Nunchuk/Stick/Up", @"value": @"`L Stick Y+`"},
        @{@"label": @"Nunchuk Stick Down", @"key": @"Nunchuk/Stick/Down", @"value": @"`L Stick Y-`"},
        @{@"label": @"Nunchuk Stick Left", @"key": @"Nunchuk/Stick/Left", @"value": @"`L Stick X-`"},
        @{@"label": @"Nunchuk Stick Right", @"key": @"Nunchuk/Stick/Right", @"value": @"`L Stick X+`"},
        @{@"label": @"Classic A", @"key": @"Classic/Buttons/A", @"value": @"`Button A`"},
        @{@"label": @"Classic B", @"key": @"Classic/Buttons/B", @"value": @"`Button B`"},
        @{@"label": @"Classic X", @"key": @"Classic/Buttons/X", @"value": @"`Button X`"},
        @{@"label": @"Classic Y", @"key": @"Classic/Buttons/Y", @"value": @"`Button Y`"},
        @{@"label": @"Classic Minus", @"key": @"Classic/Buttons/-", @"value": @"`Options`"},
        @{@"label": @"Classic Plus", @"key": @"Classic/Buttons/+", @"value": @"`Menu`"},
        @{@"label": @"Classic Home", @"key": @"Classic/Buttons/Home", @"value": @"`Home`"},
        @{@"label": @"Classic ZL", @"key": @"Classic/Buttons/ZL", @"value": @"`L Shoulder`"},
        @{@"label": @"Classic ZR", @"key": @"Classic/Buttons/ZR", @"value": @"`R Shoulder`"},
        @{@"label": @"Classic D-Pad Up", @"key": @"Classic/D-Pad/Up", @"value": @"`D-Pad Up`"},
        @{@"label": @"Classic D-Pad Down", @"key": @"Classic/D-Pad/Down", @"value": @"`D-Pad Down`"},
        @{@"label": @"Classic D-Pad Left", @"key": @"Classic/D-Pad/Left", @"value": @"`D-Pad Left`"},
        @{@"label": @"Classic D-Pad Right", @"key": @"Classic/D-Pad/Right", @"value": @"`D-Pad Right`"},
        @{@"label": @"Classic Left Stick Up", @"key": @"Classic/Left Stick/Up", @"value": @"`L Stick Y+`"},
        @{@"label": @"Classic Left Stick Down", @"key": @"Classic/Left Stick/Down", @"value": @"`L Stick Y-`"},
        @{@"label": @"Classic Left Stick Left", @"key": @"Classic/Left Stick/Left", @"value": @"`L Stick X-`"},
        @{@"label": @"Classic Left Stick Right", @"key": @"Classic/Left Stick/Right", @"value": @"`L Stick X+`"},
        @{@"label": @"Classic Right Stick Up", @"key": @"Classic/Right Stick/Up", @"value": @"`R Stick Y+`"},
        @{@"label": @"Classic Right Stick Down", @"key": @"Classic/Right Stick/Down", @"value": @"`R Stick Y-`"},
        @{@"label": @"Classic Right Stick Left", @"key": @"Classic/Right Stick/Left", @"value": @"`R Stick X-`"},
        @{@"label": @"Classic Right Stick Right", @"key": @"Classic/Right Stick/Right", @"value": @"`R Stick X+`"},
        @{@"label": @"Classic L", @"key": @"Classic/Triggers/L", @"value": @"`L Trigger`"},
        @{@"label": @"Classic R", @"key": @"Classic/Triggers/R", @"value": @"`R Trigger`"},
        @{@"label": @"Classic L Analog", @"key": @"Classic/Triggers/L-Analog", @"value": @"`L Trigger`"},
        @{@"label": @"Classic R Analog", @"key": @"Classic/Triggers/R-Analog", @"value": @"`R Trigger`"},
        @{@"label": @"Classic Trigger Threshold", @"key": @"Classic/Triggers/Threshold", @"value": @"90,000000"},
        @{@"label": @"Rumble", @"key": @"Rumble/Motor", @"value": @"`Rumble`"},
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinWiimoteMFINunchukBindings(void)
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *rows = [AMDolphinWiimoteMFIBindings() mutableCopy];
    for (NSUInteger index = 0; index < rows.count; ++index) {
        if ([rows[index][@"key"] isEqualToString:@"Extension"]) {
            rows[index] = @{@"label": @"Extension", @"key": @"Extension", @"value": @"Nunchuk"};
            break;
        }
    }
    return rows;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinWiimoteMFIClassicBindings(void)
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *rows = [AMDolphinWiimoteMFIBindings() mutableCopy];
    for (NSUInteger index = 0; index < rows.count; ++index) {
        if ([rows[index][@"key"] isEqualToString:@"Extension"]) {
            rows[index] = @{@"label": @"Extension", @"key": @"Extension", @"value": @"Classic"};
            break;
        }
    }
    return rows;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *AMDolphinMFiChoicesForBinding(AMDolphinInputProfileKind kind, NSString *key)
{
    if ([key isEqualToString:@"Device"]) {
        return @[
            @{@"title": [NSString stringWithFormat:@"Connected MFi: %@", AMDolphinConnectedMFiDeviceIdentifier()],
              @"value": AMDolphinConnectedMFiDeviceIdentifier()},
            @{@"title": @"Touchscreen", @"value": kind == AMDolphinInputProfileKindGCPad ? @"iOS/0/Touchscreen" : @"iOS/4/Touchscreen"},
        ];
    }

    if ([key isEqualToString:@"Extension"]) {
        return @[
            @{@"title": @"None", @"value": @""},
            @{@"title": @"Nunchuk", @"value": @"Nunchuk"},
            @{@"title": @"Classic Controller", @"value": @"Classic"},
        ];
    }

    if ([key isEqualToString:@"Triggers/Threshold"]) {
        return @[
            @{@"title": @"90%", @"value": @"90,000000"},
            @{@"title": @"50%", @"value": @"50,000000"},
            @{@"title": @"25%", @"value": @"25,000000"},
        ];
    }

    if ([key hasPrefix:@"Rumble/"]) {
        return @[
            @{@"title": @"Rumble", @"value": @"`Rumble`"},
            @{@"title": @"Off", @"value": @""},
        ];
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *allInputs = @[
        @{@"title": @"Button A", @"value": @"`Button A`"},
        @{@"title": @"Button B", @"value": @"`Button B`"},
        @{@"title": @"Button X", @"value": @"`Button X`"},
        @{@"title": @"Button Y", @"value": @"`Button Y`"},
        @{@"title": @"Menu / Start", @"value": @"`Menu`"},
        @{@"title": @"Options / Select", @"value": @"`Options`"},
        @{@"title": @"Home", @"value": @"`Home`"},
        @{@"title": @"D-Pad Up", @"value": @"`D-Pad Up`"},
        @{@"title": @"D-Pad Down", @"value": @"`D-Pad Down`"},
        @{@"title": @"D-Pad Left", @"value": @"`D-Pad Left`"},
        @{@"title": @"D-Pad Right", @"value": @"`D-Pad Right`"},
        @{@"title": @"L Shoulder", @"value": @"`L Shoulder`"},
        @{@"title": @"R Shoulder", @"value": @"`R Shoulder`"},
        @{@"title": @"L Trigger", @"value": @"`L Trigger`"},
        @{@"title": @"R Trigger", @"value": @"`R Trigger`"},
        @{@"title": @"L Stick Up", @"value": @"`L Stick Y+`"},
        @{@"title": @"L Stick Down", @"value": @"`L Stick Y-`"},
        @{@"title": @"L Stick Left", @"value": @"`L Stick X-`"},
        @{@"title": @"L Stick Right", @"value": @"`L Stick X+`"},
        @{@"title": @"R Stick Up", @"value": @"`R Stick Y+`"},
        @{@"title": @"R Stick Down", @"value": @"`R Stick Y-`"},
        @{@"title": @"R Stick Left", @"value": @"`R Stick X-`"},
        @{@"title": @"R Stick Right", @"value": @"`R Stick X+`"},
        @{@"title": @"L Stick Press", @"value": @"`L Stick`"},
        @{@"title": @"R Stick Press", @"value": @"`R Stick`"},
        @{@"title": @"Touchpad", @"value": @"`Touchpad`"},
        @{@"title": @"Unassigned", @"value": @""},
    ];

    if ([key containsString:@"Stick/"] || [key containsString:@"Nunchuk/Stick/"]) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary<NSString *, NSString *> *choice, __unused NSDictionary *bindings) {
            NSString *value = choice[@"value"] ?: @"";
            return [value containsString:@"Stick"] || value.length == 0;
        }];
        return [allInputs filteredArrayUsingPredicate:predicate];
    }

    if ([key hasPrefix:@"D-Pad/"] || [key containsString:@"/D-Pad/"]) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary<NSString *, NSString *> *choice, __unused NSDictionary *bindings) {
            NSString *value = choice[@"value"] ?: @"";
            return [value containsString:@"D-Pad"] || value.length == 0;
        }];
        return [allInputs filteredArrayUsingPredicate:predicate];
    }

    return allInputs;
}

@interface AMDolphinBindingEditorViewController : UITableViewController

- (instancetype)initWithStorageDirectoryURL:(NSURL *)storageDirectoryURL kind:(AMDolphinInputProfileKind)kind;

@end

@interface AMDolphinBindingEditorViewController ()

@property(nonatomic) NSURL *storageDirectoryURL;
@property(nonatomic) AMDolphinInputProfileKind kind;
@property(nonatomic) NSMutableDictionary<NSString *, NSString *> *values;

@end

@implementation AMDolphinBindingEditorViewController

- (instancetype)initWithStorageDirectoryURL:(NSURL *)storageDirectoryURL kind:(AMDolphinInputProfileKind)kind
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _storageDirectoryURL = storageDirectoryURL;
        _kind = kind;
        self.title = kind == AMDolphinInputProfileKindGCPad ? @"GameCube Controls" : @"Wii Remote Controls";
        if (kind == AMDolphinInputProfileKindGCPad) {
            self.navigationItem.rightBarButtonItems = @[
                [[UIBarButtonItem alloc] initWithTitle:@"Touch" style:UIBarButtonItemStylePlain target:self action:@selector(applyTouchDefaults)],
                [[UIBarButtonItem alloc] initWithTitle:@"MFi" style:UIBarButtonItemStylePlain target:self action:@selector(applyMFIDefaults)],
            ];
        } else {
            UIBarButtonItem *presetButton = [[UIBarButtonItem alloc] initWithTitle:@"Preset"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
            UIAction *touchAction = [UIAction actionWithTitle:@"Touch + Nunchuk"
                                                        image:nil
                                                   identifier:nil
                                                      handler:^(__unused UIAction *action) {
                [self applyTouchDefaults];
            }];
            UIAction *nunchukAction = [UIAction actionWithTitle:@"MFi + Nunchuk"
                                                          image:nil
                                                     identifier:nil
                                                        handler:^(__unused UIAction *action) {
                [self applyMFINunchukDefaults];
            }];
            UIAction *classicAction = [UIAction actionWithTitle:@"MFi + Classic Controller"
                                                          image:nil
                                                     identifier:nil
                                                        handler:^(__unused UIAction *action) {
                [self applyMFIClassicDefaults];
            }];
            presetButton.menu = [UIMenu menuWithTitle:@"" children:@[touchAction, nunchukAction, classicAction]];
            self.navigationItem.rightBarButtonItem = presetButton;
        }
        [self loadValues];
    }
    return self;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)defaultRows
{
    return self.kind == AMDolphinInputProfileKindGCPad ? AMDolphinGCPadTouchBindings() : AMDolphinWiimoteTouchBindings();
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)mfiRows
{
    return self.kind == AMDolphinInputProfileKindGCPad ? AMDolphinGCPadMFIBindings() : AMDolphinWiimoteMFIBindings();
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)displayRows
{
    NSArray<NSDictionary<NSString *, NSString *> *> *rows = self.defaultRows;
    if (self.kind == AMDolphinInputProfileKindGCPad) {
        return rows;
    }

    NSString *extension = self.values[@"Extension"] ?: @"";
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *visibleRows = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *row in rows) {
        NSString *key = row[@"key"] ?: @"";
        BOOL isNunchuk = [key hasPrefix:@"Nunchuk/"];
        BOOL isClassic = [key hasPrefix:@"Classic/"];
        if (isNunchuk && ![extension isEqualToString:@"Nunchuk"]) {
            continue;
        }
        if (isClassic && ![extension isEqualToString:@"Classic"]) {
            continue;
        }
        [visibleRows addObject:row];
    }
    return visibleRows;
}

- (NSString *)profileEnabledKey
{
    return self.kind == AMDolphinInputProfileKindGCPad ? AMDolphinGCPadProfileEnabledKey : AMDolphinWiimoteProfileEnabledKey;
}

- (NSURL *)profileURL
{
    NSString *directoryName = self.kind == AMDolphinInputProfileKindGCPad ? @"GCPad" : @"Wiimote";
    NSURL *directoryURL = [[self.storageDirectoryURL URLByAppendingPathComponent:@"Config" isDirectory:YES]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"Profiles/%@", directoryName] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    return [directoryURL URLByAppendingPathComponent:@"Amethyst.ini"];
}

- (void)loadValues
{
    self.values = [NSMutableDictionary dictionary];
    for (NSDictionary<NSString *, NSString *> *row in self.defaultRows) {
        self.values[row[@"key"]] = row[@"value"];
    }

    NSString *contents = [NSString stringWithContentsOfURL:self.profileURL encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return;
    }

    BOOL inProfile = NO;
    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *rawLine in [contents componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:trimSet];
        if (line.length == 0 || [line hasPrefix:@";"] || [line hasPrefix:@"#"]) {
            continue;
        }
        if ([line hasPrefix:@"["] && [line hasSuffix:@"]"]) {
            inProfile = [line isEqualToString:@"[Profile]"];
            continue;
        }
        if (!inProfile) {
            continue;
        }
        NSRange separator = [line rangeOfString:@"="];
        if (separator.location == NSNotFound) {
            continue;
        }
        NSString *key = [[line substringToIndex:separator.location] stringByTrimmingCharactersInSet:trimSet];
        NSString *value = [[line substringFromIndex:separator.location + 1] stringByTrimmingCharactersInSet:trimSet];
        if (key.length > 0) {
            self.values[key] = value ?: @"";
        }
    }

    NSString *device = self.values[@"Device"];
    if ([device isEqualToString:@"MFi/0/Select Device"] && GCController.controllers.count > 0) {
        self.values[@"Device"] = AMDolphinConnectedMFiDeviceIdentifier();
        [self saveValues];
    }
}

- (void)saveValues
{
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:@"[Profile]"];
    NSMutableSet<NSString *> *writtenKeys = [NSMutableSet set];
    for (NSDictionary<NSString *, NSString *> *row in self.defaultRows) {
        NSString *key = row[@"key"];
        NSString *value = self.values[key] ?: row[@"value"] ?: @"";
        [lines addObject:[NSString stringWithFormat:@"%@ = %@", key, value]];
        [writtenKeys addObject:key];
    }

    for (NSString *key in [self.values.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        if ([writtenKeys containsObject:key]) {
            continue;
        }
        [lines addObject:[NSString stringWithFormat:@"%@ = %@", key, self.values[key] ?: @""]];
    }

    NSString *contents = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    [contents writeToURL:self.profileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:self.profileEnabledKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSLog(@"[Dolphin] Saved input profile: %@", self.profileURL.path);
}

- (void)applyRows:(NSArray<NSDictionary<NSString *, NSString *> *> *)rows
{
    [self.values removeAllObjects];
    for (NSDictionary<NSString *, NSString *> *row in rows) {
        self.values[row[@"key"]] = row[@"value"] ?: @"";
    }
    [self saveValues];
    [self.tableView reloadData];
}

- (void)applyTouchDefaults
{
    [self applyRows:self.defaultRows];
}

- (void)applyMFIDefaults
{
    [self applyRows:self.mfiRows];
}

- (void)applyMFINunchukDefaults
{
    [self applyRows:AMDolphinWiimoteMFINunchukBindings()];
}

- (void)applyMFIClassicDefaults
{
    [self applyRows:AMDolphinWiimoteMFIClassicBindings()];
}

- (void)presentChoices:(NSArray<NSDictionary<NSString *, NSString *> *> *)choices
                forRow:(NSDictionary<NSString *, NSString *> *)row
             indexPath:(NSIndexPath *)indexPath
{
    NSString *key = row[@"key"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:row[@"label"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary<NSString *, NSString *> *choice in choices) {
        [alert addAction:[UIAlertAction actionWithTitle:choice[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            self.values[key] = choice[@"value"] ?: @"";
            [self saveValues];
            if ([key isEqualToString:@"Extension"]) {
                [self.tableView reloadData];
            } else {
                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.displayRows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @"Tap a row and choose a controller button. Use MFi to bind the connected controller automatically.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DolphinBindingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DolphinBindingCell"];
    }

    NSDictionary<NSString *, NSString *> *row = self.displayRows[indexPath.row];
    NSString *key = row[@"key"];
    cell.textLabel.text = row[@"label"];
    cell.detailTextLabel.text = self.values[key] ?: @"";
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary<NSString *, NSString *> *row = self.displayRows[indexPath.row];
    NSString *key = row[@"key"];
    [self presentChoices:AMDolphinMFiChoicesForBinding(self.kind, key) forRow:row indexPath:indexPath];
}

@end

@interface AMDolphinSettingsViewController : UITableViewController

- (instancetype)initWithModule:(AMModule *)module;

@end

@interface AMDolphinSettingsViewController ()

@property(nonatomic) AMModule *module;

@end

@implementation AMDolphinSettingsViewController

- (instancetype)initWithModule:(AMModule *)module
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _module = module;
        self.title = @"Dolphin Settings";
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
    AMDolphinLogControllerDiagnostics();
    AMDolphinWriteControllerDiagnosticsSnapshot(@"settings appeared", AMDolphinExternalStorageURL());
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            AMDolphinLogControllerDiagnostics();
            AMDolphinWriteControllerDiagnosticsSnapshot(@"settings discovery completed", AMDolphinExternalStorageURL());
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
    if (section == 1) {
        return 3;
    }
    if (section == 2) {
        return 15;
    }
    if (section == 3) {
        return 5;
    }
    if (section == 4) {
        return 9;
    }
    if (section == 5) {
        return 14;
    }
    if (section == 6) {
        return 4;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return @"Overlay";
    }
    if (section == 1) {
        return @"Controls";
    }
    if (section == 2) {
        return @"Wii";
    }
    if (section == 3) {
        return @"Graphics";
    }
    if (section == 4) {
        return @"Enhancements";
    }
    if (section == 5) {
        return @"Hacks";
    }
    if (section == 6) {
        return @"Core";
    }
    return @"Notes";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return @"Bindings are saved into Dolphin profiles and applied the next time a game starts.";
    }
    if (section == 2) {
        return @"Wii system settings apply the next time a game starts.";
    }
    if (section >= 3 && section <= 5) {
        return @"Graphics settings apply the next time a game starts.";
    }
    if (section == 6) {
        return @"Core settings apply the next time a game starts. Defaults keep Fire Emblem stable.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DolphinSettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DolphinSettingsCell"];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;

    NSDictionary<NSString *, id> *row = [self rowForIndexPath:indexPath];
    cell.textLabel.text = row[@"title"];
        cell.detailTextLabel.text = row[@"detail"];

    NSString *key = row[@"key"];
    if (key.length > 0) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = AMDolphinBoolSetting(key, [row[@"default"] boolValue]);
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
        return @{@"title": @"Auto-hide In-game Controls",
                 @"detail": @"Tap the game screen to show Back, Stop and status for 3 seconds.",
                 @"key": AMDolphinOverlayAutoHideKey,
                 @"default": @YES};
    }

    if (indexPath.section == 1) {
        NSArray *rows = @[
            @{@"title": @"GameCube Port 1", @"detail": @"Bind GameCube buttons, sticks, triggers and MFi preset.", @"action": @"gc"},
            @{@"title": @"Wii Remote 1", @"detail": @"Bind Wii Remote, D-Pad and Nunchuk controls.", @"action": @"wii"},
            @{@"title": @"Connected Controllers",
              @"detail": AMDolphinControllerSummary(),
              @"action": @"controllers"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 2) {
        NSArray *rows = @[
            @{@"title": @"Aspect Ratio",
              @"detail": AMDolphinWiiAspectRatioTitle(AMDolphinBoolSetting(AMDolphinWiiWidescreenKey, NO)),
              @"action": @"wiiAspect"},
            @{@"title": @"System Language",
              @"detail": AMDolphinWiiLanguageTitle(AMDolphinIntegerSetting(AMDolphinWiiLanguageKey, 1)),
              @"action": @"wiiLanguage"},
            @{@"title": @"Audio Mode",
              @"detail": AMDolphinWiiSoundTitle(AMDolphinIntegerSetting(AMDolphinWiiSoundModeKey, 1)),
              @"action": @"wiiSound"},
            @{@"title": @"Sensor Bar Position",
              @"detail": AMDolphinWiiSensorBarTitle(AMDolphinIntegerSetting(AMDolphinWiiSensorBarPositionKey, 1)),
              @"action": @"wiiSensorBar"},
            @{@"title": @"IR Sensitivity",
              @"detail": [NSString stringWithFormat:@"%ld", (long)AMDolphinIntegerSetting(AMDolphinWiiSensorBarSensitivityKey, 3)],
              @"action": @"wiiSensitivity"},
            @{@"title": @"Speaker Volume",
              @"detail": [NSString stringWithFormat:@"%ld", (long)AMDolphinIntegerSetting(AMDolphinWiiSpeakerVolumeKey, 0x58)],
              @"action": @"wiiSpeakerVolume"},
            @{@"title": @"Rumble", @"detail": @"Wii Remote motor.", @"key": AMDolphinWiiRumbleKey, @"default": @YES},
            @{@"title": @"PAL60", @"detail": @"Use PAL60 for PAL software.", @"key": AMDolphinWiiPAL60Key, @"default": @YES},
            @{@"title": @"Screen Saver", @"detail": @"Wii system screen saver.", @"key": AMDolphinWiiScreenSaverKey, @"default": @NO},
            @{@"title": @"USB Keyboard", @"detail": @"Expose emulated Wii USB keyboard.", @"key": AMDolphinWiiKeyboardKey, @"default": @NO},
            @{@"title": @"WiiConnect24", @"detail": @"Enable WiiConnect24 via WiiLink.", @"key": AMDolphinWiiConnect24Key, @"default": @NO},
            @{@"title": @"Skylander Portal", @"detail": @"Emulate a Skylander portal.", @"key": AMDolphinSkylanderPortalKey, @"default": @NO},
            @{@"title": @"SD Card", @"detail": @"Insert emulated Wii SD card.", @"key": AMDolphinWiiSDCardKey, @"default": @YES},
            @{@"title": @"SD Writes", @"detail": @"Allow software to write to the emulated SD card.", @"key": AMDolphinWiiSDWritesKey, @"default": @YES},
            @{@"title": @"SD Folder Sync", @"detail": @"Sync the emulated SD card with a folder.", @"key": AMDolphinWiiSDFolderSyncKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 3) {
        NSArray *rows = @[
            @{@"title": @"Backend", @"detail": @"Metal", @"image": @"cpu"},
            @{@"title": @"Aspect Ratio",
              @"detail": AMDolphinAspectRatioTitle(AMDolphinIntegerSetting(AMDolphinAspectRatioKey, 0)),
              @"action": @"aspectRatio"},
            @{@"title": @"V-Sync", @"detail": @"Wait for vertical blank.", @"key": AMDolphinVSyncKey, @"default": @NO},
            @{@"title": @"Shader Compilation",
              @"detail": AMDolphinShaderModeTitle(AMDolphinIntegerSetting(AMDolphinShaderModeKey, 0)),
              @"action": @"shaderMode"},
            @{@"title": @"Wait for Shaders", @"detail": @"Wait before starting a game until shaders compile.", @"key": AMDolphinWaitForShadersKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 4) {
        NSArray *rows = @[
            @{@"title": @"Internal Resolution",
              @"detail": AMDolphinInternalResolutionTitle(AMDolphinIntegerSetting(AMDolphinEFBScaleKey, 1)),
              @"action": @"resolution"},
            @{@"title": @"Scaled EFB Copy", @"detail": @"Scale EFB copies with the internal resolution.", @"key": AMDolphinScaledEFBKey, @"default": @YES},
            @{@"title": @"Anisotropic Filtering",
              @"detail": AMDolphinAnisotropyTitle(AMDolphinIntegerSetting(AMDolphinAnisotropyKey, -1)),
              @"action": @"anisotropy"},
            @{@"title": @"Texture Filtering",
              @"detail": AMDolphinTextureFilteringTitle(AMDolphinIntegerSetting(AMDolphinTextureFilteringKey, 0)),
              @"action": @"textureFiltering"},
            @{@"title": @"Widescreen Hack", @"detail": @"Force Dolphin widescreen hack.", @"key": AMDolphinWidescreenHackKey, @"default": @NO},
            @{@"title": @"Disable Fog", @"detail": @"Turn off fog effects in the renderer.", @"key": AMDolphinDisableFogKey, @"default": @NO},
            @{@"title": @"Disable Copy Filter", @"detail": @"Sharpen EFB copies.", @"key": AMDolphinDisableCopyFilterKey, @"default": @YES},
            @{@"title": @"Per-pixel Lighting", @"detail": @"Calculate lighting per pixel.", @"key": AMDolphinPixelLightingKey, @"default": @NO},
            @{@"title": @"Force True Color", @"detail": @"Render RGB channels in 24-bit.", @"key": AMDolphinForceTrueColorKey, @"default": @YES},
            @{@"title": @"Arbitrary Mipmap Detection", @"detail": @"Detect custom mipmap effects.", @"key": AMDolphinArbitraryMipmapKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 5) {
        NSArray *rows = @[
            @{@"title": @"EFB Access from CPU", @"detail": @"Allow CPU reads and writes to EFB.", @"key": AMDolphinEFBAccessKey, @"default": @NO},
            @{@"title": @"EFB Copies to Texture", @"detail": @"Store EFB copies on GPU.", @"key": AMDolphinEFBToTextureKey, @"default": @YES},
            @{@"title": @"EFB Format Changes", @"detail": @"Emulate EFB format changes.", @"key": AMDolphinEFBFormatChangesKey, @"default": @YES},
            @{@"title": @"Defer EFB Copies", @"detail": @"Delay EFB RAM copies until GPU sync.", @"key": AMDolphinDeferEFBCopiesKey, @"default": @YES},
            @{@"title": @"GPU Texture Decoding", @"detail": @"Decode textures on GPU.", @"key": AMDolphinGPUTextureDecodingKey, @"default": @NO},
            @{@"title": @"XFB Copies to Texture", @"detail": @"Store XFB copies on GPU.", @"key": AMDolphinXFBToTextureKey, @"default": @YES},
            @{@"title": @"Immediately Present XFB", @"detail": @"Present XFB copies as soon as created.", @"key": AMDolphinImmediateXFBKey, @"default": @NO},
            @{@"title": @"Skip Duplicate XFBs", @"detail": @"Skip duplicate presented frames.", @"key": AMDolphinSkipDuplicateXFBsKey, @"default": @YES},
            @{@"title": @"Fast Depth Calculation", @"detail": @"Use faster depth calculation.", @"key": AMDolphinFastDepthKey, @"default": @YES},
            @{@"title": @"Vertex Rounding", @"detail": @"Round 2D vertices at high resolution.", @"key": AMDolphinVertexRoundingKey, @"default": @NO},
            @{@"title": @"Bounding Box", @"detail": @"Enable bounding box emulation.", @"key": AMDolphinBBoxKey, @"default": @NO},
            @{@"title": @"Texture Cache in Save States", @"detail": @"Include EFB and scaled copies in states.", @"key": AMDolphinSaveTextureCacheToStateKey, @"default": @YES},
            @{@"title": @"VI Skip", @"detail": @"Skip vertical interrupts when lagging.", @"key": AMDolphinVISkipKey, @"default": @NO},
            @{@"title": @"Texture Cache Accuracy",
              @"detail": AMDolphinTextureCacheAccuracyTitle(AMDolphinIntegerSetting(AMDolphinTextureCacheAccuracyKey, 128)),
              @"action": @"textureCacheAccuracy"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == 6) {
        NSArray *rows = @[
            @{@"title": @"Dual Core", @"detail": @"Off is safer on current iOS 26 JIT build.", @"key": AMDolphinCPUThreadKey, @"default": @NO},
            @{@"title": @"Synchronize GPU", @"detail": @"Leave off unless a game needs stricter GPU sync.", @"key": AMDolphinSyncGPUKey, @"default": @NO},
            @{@"title": @"DSP JIT", @"detail": @"Leave off for the current bundled core.", @"key": AMDolphinDSPJITKey, @"default": @NO},
            @{@"title": @"Fastmem", @"detail": @"Leave off with TXM JIT unless testing speed regressions.", @"key": AMDolphinFastmemKey, @"default": @NO},
        ];
        return rows[indexPath.row];
    }

    return @{@"title": @"Graphics Backend",
             @"detail": @"Metal is forced for the integrated renderer. Wii defaults to 4:3 unless changed here."};
}

- (void)settingChanged:(UISwitch *)sender
{
    NSString *key = sender.accessibilityIdentifier;
    if (key.length == 0) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)controllerListChanged:(NSNotification *)notification
{
    NSLog(@"[Dolphin] Controller notification: %@", notification.name);
    AMDolphinLogControllerDiagnostics();
    AMDolphinWriteControllerDiagnosticsSnapshot(notification.name, AMDolphinExternalStorageURL());
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)presentChoiceWithTitle:(NSString *)title
                           key:(NSString *)key
                       choices:(NSArray<NSDictionary<NSString *, id> *> *)choices
                     indexPath:(NSIndexPath *)indexPath
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
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

- (void)presentControllerDiagnosticsFromIndexPath:(NSIndexPath *)indexPath
{
    AMDolphinLogControllerDiagnostics();
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            AMDolphinLogControllerDiagnostics();
            AMDolphinWriteControllerDiagnosticsSnapshot(@"manual discovery completed", AMDolphinExternalStorageURL());
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Controller Diagnostics"
                                                                   message:AMDolphinControllerDiagnosticsText()
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Refresh"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        AMDolphinLogControllerDiagnostics();
        [self presentControllerDiagnosticsFromIndexPath:indexPath];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary<NSString *, id> *row = [self rowForIndexPath:indexPath];
    NSString *action = row[@"action"];

    if ([action isEqualToString:@"controllers"]) {
        [self presentControllerDiagnosticsFromIndexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"gc"] || [action isEqualToString:@"wii"]) {
        NSURL *storageURL = AMDolphinExternalStorageURL();
        if (!storageURL) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"External Folder Required"
                                                                           message:@"Select a Dolphin external folder first."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        AMDolphinInputProfileKind kind = [action isEqualToString:@"gc"] ? AMDolphinInputProfileKindGCPad : AMDolphinInputProfileKindWiimote;
        AMDolphinBindingEditorViewController *viewController =
            [[AMDolphinBindingEditorViewController alloc] initWithStorageDirectoryURL:storageURL kind:kind];
        [self.navigationController pushViewController:viewController animated:YES];
        return;
    }

    if ([action isEqualToString:@"wiiAspect"]) {
        [self presentChoiceWithTitle:@"Wii Aspect Ratio"
                                 key:AMDolphinWiiWidescreenKey
                             choices:@[
                                 @{@"title": @"4:3", @"value": @0},
                                 @{@"title": @"16:9", @"value": @1},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"wiiLanguage"]) {
        [self presentChoiceWithTitle:@"Wii Language"
                                 key:AMDolphinWiiLanguageKey
                             choices:@[
                                 @{@"title": @"Japanese", @"value": @0},
                                 @{@"title": @"English", @"value": @1},
                                 @{@"title": @"German", @"value": @2},
                                 @{@"title": @"French", @"value": @3},
                                 @{@"title": @"Spanish", @"value": @4},
                                 @{@"title": @"Italian", @"value": @5},
                                 @{@"title": @"Dutch", @"value": @6},
                                 @{@"title": @"Simplified Chinese", @"value": @7},
                                 @{@"title": @"Traditional Chinese", @"value": @8},
                                 @{@"title": @"Korean", @"value": @9},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"wiiSound"]) {
        [self presentChoiceWithTitle:@"Wii Audio Mode"
                                 key:AMDolphinWiiSoundModeKey
                             choices:@[
                                 @{@"title": @"Mono", @"value": @0},
                                 @{@"title": @"Stereo", @"value": @1},
                                 @{@"title": @"Surround", @"value": @2},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"wiiSensorBar"]) {
        [self presentChoiceWithTitle:@"Sensor Bar Position"
                                 key:AMDolphinWiiSensorBarPositionKey
                             choices:@[
                                 @{@"title": @"Bottom", @"value": @0},
                                 @{@"title": @"Top", @"value": @1},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"wiiSensitivity"]) {
        [self presentChoiceWithTitle:@"IR Sensitivity"
                                 key:AMDolphinWiiSensorBarSensitivityKey
                             choices:@[
                                 @{@"title": @"1", @"value": @1},
                                 @{@"title": @"2", @"value": @2},
                                 @{@"title": @"3", @"value": @3},
                                 @{@"title": @"4", @"value": @4},
                                 @{@"title": @"5", @"value": @5},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"wiiSpeakerVolume"]) {
        [self presentChoiceWithTitle:@"Speaker Volume"
                                 key:AMDolphinWiiSpeakerVolumeKey
                             choices:@[
                                 @{@"title": @"0", @"value": @0},
                                 @{@"title": @"40", @"value": @40},
                                 @{@"title": @"88", @"value": @88},
                                 @{@"title": @"128", @"value": @128},
                                 @{@"title": @"255", @"value": @255},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"aspectRatio"]) {
        [self presentChoiceWithTitle:@"Aspect Ratio"
                                 key:AMDolphinAspectRatioKey
                             choices:@[
                                 @{@"title": @"Auto", @"value": @0},
                                 @{@"title": @"Force 4:3", @"value": @1},
                                 @{@"title": @"Force 16:9", @"value": @2},
                                 @{@"title": @"Stretch to Window", @"value": @3},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"shaderMode"]) {
        [self presentChoiceWithTitle:@"Shader Compilation"
                                 key:AMDolphinShaderModeKey
                             choices:@[
                                 @{@"title": @"Specialized", @"value": @0},
                                 @{@"title": @"Exclusive Ubershaders", @"value": @1},
                                 @{@"title": @"Hybrid Ubershaders", @"value": @2},
                                 @{@"title": @"Skip Drawing", @"value": @3},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"resolution"]) {
        [self presentChoiceWithTitle:@"Internal Resolution"
                                 key:AMDolphinEFBScaleKey
                             choices:@[
                                 @{@"title": @"Auto", @"value": @0},
                                 @{@"title": @"1x Native", @"value": @1},
                                 @{@"title": @"2x Native", @"value": @2},
                                 @{@"title": @"3x Native", @"value": @3},
                                 @{@"title": @"4x Native", @"value": @4},
                                 @{@"title": @"5x Native", @"value": @5},
                                 @{@"title": @"6x Native", @"value": @6},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"anisotropy"]) {
        [self presentChoiceWithTitle:@"Anisotropic Filtering"
                                 key:AMDolphinAnisotropyKey
                             choices:@[
                                 @{@"title": @"Default", @"value": @-1},
                                 @{@"title": @"1x", @"value": @0},
                                 @{@"title": @"2x", @"value": @1},
                                 @{@"title": @"4x", @"value": @2},
                                 @{@"title": @"8x", @"value": @3},
                                 @{@"title": @"16x", @"value": @4},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"textureFiltering"]) {
        [self presentChoiceWithTitle:@"Texture Filtering"
                                 key:AMDolphinTextureFilteringKey
                             choices:@[
                                 @{@"title": @"Default", @"value": @0},
                                 @{@"title": @"Nearest", @"value": @1},
                                 @{@"title": @"Linear", @"value": @2},
                             ]
                           indexPath:indexPath];
        return;
    }

    if ([action isEqualToString:@"textureCacheAccuracy"]) {
        [self presentChoiceWithTitle:@"Texture Cache Accuracy"
                                 key:AMDolphinTextureCacheAccuracyKey
                             choices:@[
                                 @{@"title": @"Fast", @"value": @0},
                                 @{@"title": @"Safe", @"value": @512},
                                 @{@"title": @"Medium", @"value": @128},
                             ]
                           indexPath:indexPath];
    }
}

@end

@interface AMDolphinModuleViewController ()

@property(nonatomic) AMModule *module;
@property(nonatomic) void *dolphinHandle;
@property(nonatomic) NSString *loadStatus;
@property(nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *resourceRows;
@property(nonatomic) NSArray<NSURL *> *gameURLs;
@property(nonatomic) BOOL didHandleAutoBoot;
@property(nonatomic) AMDolphinDocumentPickerMode documentPickerMode;

@end

@implementation AMDolphinModuleViewController

- (instancetype)initWithModule:(AMModule *)module
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _module = module;
        self.title = module.name;
        _loadStatus = @"Not loaded";
        _resourceRows = @[];
        _gameURLs = @[];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSURL *externalStorageURL = self.dolphinUserDirectoryURL;
    if (externalStorageURL) {
        AMDolphinWriteSaveDiagnostics(externalStorageURL, @"module loaded");
    }
    AMDolphinLogControllerDiagnostics();
    AMDolphinWriteControllerDiagnosticsSnapshot(@"module loaded", externalStorageURL);
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

- (void)handleAutoBootIfNeeded
{
    const char *autoBootPath = getenv("AM_DOLPHIN_AUTO_BOOT");
    NSString *path = autoBootPath && autoBootPath[0] != '\0'
        ? @(autoBootPath)
        : [NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalDolphinAutoBootPath"];
    if (self.didHandleAutoBoot || path.length == 0) {
        return;
    }

    self.didHandleAutoBoot = YES;
    NSURL *softwareDirectoryURL = self.softwareDirectoryURL;
    if (!softwareDirectoryURL) {
        NSLog(@"[Dolphin] Auto boot blocked: no external folder for %@", path);
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a Dolphin external folder before booting games."];
        return;
    }

    NSURL *url = [path hasPrefix:@"/"] ? [NSURL fileURLWithPath:path] : [softwareDirectoryURL URLByAppendingPathComponent:path];
    NSLog(@"[Dolphin] Auto boot resolved: %@", url.path);
    [self showPendingBootForURL:url];
}

- (void)refreshDiagnostics
{
    [self loadDolphinCoreIfNeeded];
    [self reloadResourceRows];
    [self reloadGameRows];
    [self.tableView reloadData];
}

- (void)loadDolphinCoreIfNeeded
{
    if (self.dolphinHandle) {
        self.loadStatus = gDolphinInitialize && gDolphinRun ? @"Loaded; bridge ready" : @"Loaded; bridge missing";
        NSLog(@"[Dolphin] Core already loaded: %@", self.loadStatus);
        return;
    }

    self.dolphinHandle = dlopen("@rpath/libdolphin.dylib", RTLD_NOW | RTLD_GLOBAL);
    if (self.dolphinHandle) {
        gDolphinInitialize = (AMDolphinInitializeFunction)dlsym(self.dolphinHandle, "DOLAmethystInitialize");
        gDolphinRun = (AMDolphinRunFunction)dlsym(self.dolphinHandle, "DOLAmethystRun");
        gDolphinStop = (AMDolphinStopFunction)dlsym(self.dolphinHandle, "DOLAmethystStop");
        gDolphinIsRunning = (AMDolphinIsRunningFunction)dlsym(self.dolphinHandle, "DOLAmethystIsRunning");
        gDolphinLastError = (AMDolphinLastErrorFunction)dlsym(self.dolphinHandle, "DOLAmethystLastError");
        gDolphinSaveState = (AMDolphinStateFunction)dlsym(self.dolphinHandle, "DOLAmethystSaveState");
        gDolphinLoadState = (AMDolphinStateFunction)dlsym(self.dolphinHandle, "DOLAmethystLoadState");
        gDolphinSaveScreenshot = (AMDolphinSimpleFunction)dlsym(self.dolphinHandle, "DOLAmethystSaveScreenshot");
        self.loadStatus = gDolphinInitialize && gDolphinRun && gDolphinStop ? @"Loaded; bridge ready" : @"Loaded; bridge missing";
        NSLog(@"[Dolphin] Loaded libdolphin.dylib");
        return;
    }

    const char *error = dlerror();
    self.loadStatus = error ? @(error) : @"dlopen failed";
    NSLog(@"[Dolphin] Failed to load libdolphin.dylib: %@", self.loadStatus);
}

- (void)reloadResourceRows
{
    NSURL *resourceURL = [self.module resourceDirectoryURL];
    NSURL *resourcesURL = [resourceURL URLByAppendingPathComponent:@"Resources" isDirectory:YES];
    NSURL *sysURL = [resourcesURL URLByAppendingPathComponent:@"Sys" isDirectory:YES];
    NSURL *preferencesURL = [resourcesURL URLByAppendingPathComponent:@"DefaultPreferences.plist"];
    NSURL *assetsURL = [resourcesURL URLByAppendingPathComponent:@"Assets.car"];

    self.resourceRows = @[
        @{@"title": @"Module", @"value": [self existsAtURL:resourceURL] ? @"YES" : @"NO"},
        @{@"title": @"Resources", @"value": [self existsAtURL:resourcesURL] ? @"YES" : @"NO"},
        @{@"title": @"Sys", @"value": [self existsAtURL:sysURL] ? @"YES" : @"NO"},
        @{@"title": @"DefaultPreferences", @"value": [self existsAtURL:preferencesURL] ? @"YES" : @"NO"},
        @{@"title": @"Assets", @"value": [self existsAtURL:assetsURL] ? @"YES" : @"NO"},
    ];
}

- (void)reloadGameRows
{
    NSURL *softwareDirectoryURL = self.softwareDirectoryURL;
    if (!softwareDirectoryURL) {
        self.gameURLs = @[];
        return;
    }

    NSArray<NSURLResourceKey> *keys = @[NSURLIsRegularFileKey, NSURLContentModificationDateKey, NSURLFileSizeKey];
    NSArray<NSURL *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:softwareDirectoryURL
                                                             includingPropertiesForKeys:keys
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                  error:nil] ?: @[];
    NSMutableArray<NSURL *> *gameURLs = [NSMutableArray array];
    NSSet<NSString *> *extensions = [NSSet setWithArray:@[@"iso", @"gcm", @"tgc", @"gcz", @"ciso", @"wbfs", @"wia", @"rvz", @"dol", @"elf", @"wad"]];

    for (NSURL *url in contents) {
        NSNumber *isRegularFile = nil;
        if (![url getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil] || !isRegularFile.boolValue) {
            continue;
        }

        if ([extensions containsObject:url.pathExtension.lowercaseString]) {
            [gameURLs addObject:url];
        }
    }

    [gameURLs sortUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
        return [left.lastPathComponent localizedCaseInsensitiveCompare:right.lastPathComponent];
    }];
    self.gameURLs = gameURLs.copy;
}

- (NSURL *)dolphinUserDirectoryURL
{
    return AMDolphinExternalStorageURL();
}

- (NSURL *)softwareDirectoryURL
{
    NSURL *userDirectoryURL = self.dolphinUserDirectoryURL;
    if (!userDirectoryURL) {
        return nil;
    }

    NSURL *directoryURL = [userDirectoryURL URLByAppendingPathComponent:@"Software" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    return directoryURL;
}

- (BOOL)existsAtURL:(NSURL *)url
{
    return [NSFileManager.defaultManager fileExistsAtPath:url.path];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return AMDolphinSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case AMDolphinSectionActions:
            return 4;
        case AMDolphinSectionGames:
            return MAX(self.gameURLs.count, 1);
        case AMDolphinSectionStatus:
            return 2;
        case AMDolphinSectionRuntime:
            return 4;
        case AMDolphinSectionBundle:
            return self.resourceRows.count;
        case AMDolphinSectionNext:
            return 2;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case AMDolphinSectionActions:
            return @"Actions";
        case AMDolphinSectionGames:
            return @"Software";
        case AMDolphinSectionStatus:
            return @"Dolphin";
        case AMDolphinSectionRuntime:
            return @"Runtime";
        case AMDolphinSectionBundle:
            return @"Bundle";
        case AMDolphinSectionNext:
            return @"Integration";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DolphinDiagnosticCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DolphinDiagnosticCell"];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 3;

    NSDictionary<NSString *, NSString *> *row = [self rowForIndexPath:indexPath];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"value"];
    NSString *imageName = row[@"image"];
    cell.imageView.image = imageName.length > 0 ? [UIImage systemImageNamed:imageName] : nil;
    if (indexPath.section == AMDolphinSectionActions || (indexPath.section == AMDolphinSectionGames && self.gameURLs.count > 0)) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (NSDictionary<NSString *, NSString *> *)rowForIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == AMDolphinSectionActions) {
        NSString *externalPath = [NSUserDefaults.standardUserDefaults stringForKey:AMDolphinExternalFolderPathKey] ?: @"Not selected";
        NSArray *rows = @[
            @{@"title": @"External Folder", @"value": externalPath, @"image": @"folder.badge.gearshape"},
            @{@"title": @"Import Software", @"value": @"Copy selected files into the external Dolphin/Software folder.", @"image": @"square.and.arrow.down"},
            @{@"title": @"Settings", @"value": @"Configure Dolphin overlay and core options.", @"image": @"gearshape"},
            @{@"title": @"Refresh", @"value": @"Reload games, resources and core status.", @"image": @"arrow.clockwise"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == AMDolphinSectionGames) {
        if (self.gameURLs.count == 0) {
            NSURL *softwareDirectoryURL = self.softwareDirectoryURL;
            return @{@"title": softwareDirectoryURL ? @"No software found" : @"External folder not selected",
                     @"value": softwareDirectoryURL.path ?: @"Select an external Dolphin folder first.",
                     @"image": @"opticaldisc"};
        }

        NSURL *url = self.gameURLs[indexPath.row];
        NSNumber *fileSize = nil;
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        return @{@"title": url.lastPathComponent ?: @"Software",
                 @"value": fileSize ? [NSByteCountFormatter stringFromByteCount:fileSize.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : url.path,
                 @"image": @"opticaldiscdrive"};
    }

    if (indexPath.section == AMDolphinSectionStatus) {
        NSArray *rows = @[
            @{@"title": @"Core Library", @"value": self.loadStatus, @"image": @"cpu"},
            @{@"title": @"Entry", @"value": self.module.entrypoint ?: @"", @"image": @"point.3.connected.trianglepath.dotted"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == AMDolphinSectionRuntime) {
        NSArray *rows = @[
            @{@"title": @"JIT", @"value": AMDolphinHasHostJIT() ? @"ON" : @"OFF", @"image": @"bolt.fill"},
            @{@"title": @"Device JIT Flags", @"value": [NSString stringWithFormat:@"0x%X", DeviceGetJITFlags(NO)], @"image": @"flag"},
            @{@"title": @"Increased Memory", @"value": getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit") ? @"YES" : @"NO", @"image": @"memorychip"},
            @{@"title": @"Storage", @"value": self.dolphinUserDirectoryURL.path ?: @"External folder not selected", @"image": @"folder"},
        ];
        return rows[indexPath.row];
    }

    if (indexPath.section == AMDolphinSectionBundle) {
        return self.resourceRows[indexPath.row];
    }

    NSArray *rows = @[
        @{@"title": @"Prepared", @"value": @"libdolphin.dylib, resources and software storage are packaged.", @"image": @"checkmark.circle"},
        @{@"title": @"Boot", @"value": @"Selecting software opens the native Dolphin render view in-process.", @"image": @"play.circle"},
    ];
    return rows[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == AMDolphinSectionActions) {
        if (indexPath.row == 0) {
            [self selectExternalFolder];
        } else if (indexPath.row == 1) {
            [self importSoftware];
        } else if (indexPath.row == 2) {
            [self.navigationController pushViewController:[[AMDolphinSettingsViewController alloc] initWithModule:self.module] animated:YES];
        } else {
            [self refreshDiagnostics];
        }
        return;
    }

    if (indexPath.section == AMDolphinSectionGames && self.gameURLs.count > 0) {
        NSURL *url = self.gameURLs[indexPath.row];
        NSLog(@"[Dolphin] Selected software: %@", url.path);
        [self showPendingBootForURL:url];
    }
}

- (void)selectExternalFolder
{
    self.documentPickerMode = AMDolphinDocumentPickerModeExternalFolder;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importSoftware
{
    NSURL *userDirectoryURL = self.dolphinUserDirectoryURL;
    if (!userDirectoryURL) {
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a Dolphin external folder first."];
        return;
    }
    NSString *failureMessage = nil;
    if (!AMDolphinExternalStorageReady(userDirectoryURL, &failureMessage)) {
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: userDirectoryURL.path];
        return;
    }

    self.documentPickerMode = AMDolphinDocumentPickerModeSoftwareImport;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    if (self.documentPickerMode == AMDolphinDocumentPickerModeExternalFolder) {
        NSURL *url = urls.firstObject;
        if (!url) {
            self.documentPickerMode = AMDolphinDocumentPickerModeNone;
            return;
        }

        [url startAccessingSecurityScopedResource];
        NSString *failureMessage = nil;
        if (!AMDolphinExternalStorageReady(url, &failureMessage)) {
            self.documentPickerMode = AMDolphinDocumentPickerModeNone;
            [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: url.path];
            return;
        }

        AMDolphinStoreExternalFolderURL(url);
        self.documentPickerMode = AMDolphinDocumentPickerModeNone;
        NSLog(@"[Dolphin] External folder selected: %@", url.path);
        [self refreshDiagnostics];
        return;
    }

    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSURL *userDirectoryURL = self.dolphinUserDirectoryURL;
    if (!userDirectoryURL) {
        self.documentPickerMode = AMDolphinDocumentPickerModeNone;
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a Dolphin external folder first."];
        return;
    }
    NSString *failureMessage = nil;
    if (!AMDolphinExternalStorageReady(userDirectoryURL, &failureMessage)) {
        self.documentPickerMode = AMDolphinDocumentPickerModeNone;
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: userDirectoryURL.path];
        return;
    }

    NSURL *softwareDirectoryURL = [userDirectoryURL URLByAppendingPathComponent:@"Software" isDirectory:YES];

    for (NSURL *url in urls) {
        NSURL *destinationURL = [self uniqueDestinationURLForSourceURL:url inDirectoryURL:softwareDirectoryURL];
        NSError *error = nil;
        if (![NSFileManager.defaultManager copyItemAtURL:url toURL:destinationURL error:&error]) {
            [failures addObject:[NSString stringWithFormat:@"%@: %@", url.lastPathComponent, error.localizedDescription]];
        } else {
            NSLog(@"[Dolphin] Imported software %@ -> %@", url.path, destinationURL.path);
        }
    }

    self.documentPickerMode = AMDolphinDocumentPickerModeNone;
    [self refreshDiagnostics];

    if (failures.count > 0) {
        [self showAlertWithTitle:@"Import Failed" message:[failures componentsJoinedByString:@"\n"]];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    self.documentPickerMode = AMDolphinDocumentPickerModeNone;
}

- (NSURL *)uniqueDestinationURLForSourceURL:(NSURL *)sourceURL inDirectoryURL:(NSURL *)directoryURL
{
    NSString *baseName = sourceURL.URLByDeletingPathExtension.lastPathComponent ?: @"Software";
    NSString *extension = sourceURL.pathExtension;
    NSURL *candidateURL = [directoryURL URLByAppendingPathComponent:sourceURL.lastPathComponent ?: @"Software"];
    NSInteger index = 2;

    while ([NSFileManager.defaultManager fileExistsAtPath:candidateURL.path]) {
        NSString *fileName = extension.length > 0 ? [NSString stringWithFormat:@"%@ %ld.%@", baseName, (long)index, extension] : [NSString stringWithFormat:@"%@ %ld", baseName, (long)index];
        candidateURL = [directoryURL URLByAppendingPathComponent:fileName];
        index++;
    }

    return candidateURL;
}

- (void)showPendingBootForURL:(NSURL *)url
{
    NSURL *userDirectoryURL = self.dolphinUserDirectoryURL;
    if (!userDirectoryURL) {
        [self showAlertWithTitle:@"External Folder Required" message:@"Select a Dolphin external folder before booting games."];
        return;
    }
    NSString *failureMessage = nil;
    if (!AMDolphinExternalStorageReady(userDirectoryURL, &failureMessage)) {
        [self showAlertWithTitle:@"External Folder Not Writable" message:failureMessage ?: userDirectoryURL.path];
        return;
    }

    AMDolphinWriteSaveDiagnostics(userDirectoryURL, @"before boot");
    [self loadDolphinCoreIfNeeded];
    if (!gDolphinInitialize || !gDolphinRun || !gDolphinStop) {
        [self showAlertWithTitle:@"Dolphin Bridge Missing" message:self.loadStatus ?: @"Dolphin bridge is not available."];
        return;
    }

    if (!AMDolphinCanBootWithCurrentJIT()) {
        LauncherNavigationController *navigationController = (LauncherNavigationController *)self.navigationController;
        if (![navigationController isKindOfClass:LauncherNavigationController.class]) {
            [self showAlertWithTitle:@"JIT Required" message:@"Cannot find launcher navigation controller."];
            return;
        }

        self.didHandleAutoBoot = NO;
        __weak typeof(self) weakSelf = self;
        void (^completion)(void) = ^{
            gDolphinJITHandshakeComplete = YES;
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"AMInternalDolphinJITHandshakeComplete"];
            [NSUserDefaults.standardUserDefaults synchronize];
            [weakSelf showPendingBootForURL:url];
        };

        [navigationController runAfterJITEnabled:completion];
        return;
    }

    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"AMInternalDolphinAutoBootPath"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"AMInternalDolphinAutoBootSkipJIT"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"AMInternalDolphinJITHandshakeComplete"];
    [NSUserDefaults.standardUserDefaults synchronize];

    AMDolphinRenderViewController *viewController = [[AMDolphinRenderViewController alloc] initWithGameURL:url
                                                                                           userDirectoryURL:userDirectoryURL
                                                                                                    jitType:[self dolphinJITType]];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    NSLog(@"[Dolphin] Presenting render view for %@", url.lastPathComponent);
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (int)dolphinJITType
{
    if (!AMDolphinCanBootWithCurrentJIT()) {
        return 0;
    }

    if (@available(iOS 26, *)) {
        return DeviceHasJITFlags(JIT_FLAG_HAS_TXM) ? 3 : 2;
    }

    return 1;
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
