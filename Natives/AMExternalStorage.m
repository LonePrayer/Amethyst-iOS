#import "AMExternalStorage.h"

NSString * const AMAmethystExternalFolderPathKey = @"AMAmethystExternalFolderPath";

static NSString * const AMAmethystExternalFolderBookmarkKey = @"AMAmethystExternalFolderBookmark";

static NSArray<NSString *> *AMAmethystHomeSubdirectories(void)
{
    return @[
        @"accounts",
        @"controlmap",
        @"controlmap/gamepads",
        @"instances",
        @"java_runtimes",
        @"Library",
        @"Library/Application Support",
        @"Library/Application Support/minecraft",
        @".demo",
    ];
}

static BOOL AMWriteProbeAtDirectory(NSURL *directoryURL, NSString **failureMessage)
{
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
            NSError *error = directoryCreateError ?: coordinationError;
            *failureMessage = [NSString stringWithFormat:@"%@: %@", directoryURL.path, error.localizedDescription ?: @"create failed"];
        }
        return NO;
    }

    NSURL *probeURL = [directoryURL URLByAppendingPathComponent:@".amethyst-write-test" isDirectory:NO];
    __block NSError *writeError = nil;
    __block BOOL writeOK = NO;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateWritingItemAtURL:probeURL options:0 error:&writeError byAccessor:^(NSURL *newURL) {
        NSString *content = [NSString stringWithFormat:@"write-test %@\n", NSDate.date];
        writeOK = [content writeToURL:newURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    }];
    if (!writeOK) {
        if (failureMessage) {
            *failureMessage = [NSString stringWithFormat:@"%@: %@", probeURL.path, writeError.localizedDescription ?: @"write failed"];
        }
        return NO;
    }

    __block NSError *removeError = nil;
    [coordinator coordinateWritingItemAtURL:probeURL options:NSFileCoordinatorWritingForDeleting error:&removeError byAccessor:^(NSURL *newURL) {
        [fileManager removeItemAtURL:newURL error:&removeError];
    }];
    return YES;
}

NSURL *AMAmethystExternalHomeURL(BOOL startAccessing)
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *bookmarkData = [defaults dataForKey:AMAmethystExternalFolderBookmarkKey];
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
        NSLog(@"[AmethystStorage] External home bookmark failed: stale=%d error=%@", stale, error.localizedDescription);
    }

    NSString *forcedPath = @(getenv("AM_AMETHYST_HOME") ?: "");
    return forcedPath.length > 0 ? [NSURL fileURLWithPath:forcedPath isDirectory:YES] : nil;
}

void AMAmethystApplyExternalHomeURL(NSURL *url)
{
    if (!url.path.length) {
        return;
    }
    setenv("POJAV_HOME", url.path.UTF8String, 1);
    NSLog(@"[AmethystStorage] Minecraft home: %@", url.path);
}

BOOL AMAmethystPrepareExternalHomeURL(NSURL *url, NSString **failureMessage)
{
    if (!url) {
        if (failureMessage) {
            *failureMessage = @"External Amethyst folder is not selected.";
        }
        return NO;
    }

    if (![url startAccessingSecurityScopedResource]) {
        NSLog(@"[AmethystStorage] startAccessing returned NO for %@", url.path);
    }

    for (NSString *relativePath in AMAmethystHomeSubdirectories()) {
        NSURL *directoryURL = [url URLByAppendingPathComponent:relativePath isDirectory:YES];
        if (!AMWriteProbeAtDirectory(directoryURL, failureMessage)) {
            return NO;
        }
    }

    return AMWriteProbeAtDirectory(url, failureMessage);
}

BOOL AMAmethystStoreExternalHomeURL(NSURL *url, NSString **failureMessage)
{
    if (!AMAmethystPrepareExternalHomeURL(url, failureMessage)) {
        return NO;
    }

    NSError *error = nil;
    NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil
                                                  error:&error];
    if (bookmarkData.length == 0) {
        if (failureMessage) {
            *failureMessage = [NSString stringWithFormat:@"%@: %@", url.path, error.localizedDescription ?: @"bookmark failed"];
        }
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:bookmarkData forKey:AMAmethystExternalFolderBookmarkKey];
    [defaults setObject:url.path ?: @"" forKey:AMAmethystExternalFolderPathKey];
    [defaults synchronize];
    AMAmethystApplyExternalHomeURL(url);
    return YES;
}

BOOL AMAmethystApplyStoredExternalHomeIfAvailable(void)
{
    NSURL *url = AMAmethystExternalHomeURL(YES);
    if (!url) {
        return NO;
    }

    NSString *failureMessage = nil;
    if (!AMAmethystPrepareExternalHomeURL(url, &failureMessage)) {
        NSLog(@"[AmethystStorage] Stored external home not writable: %@", failureMessage);
        return NO;
    }

    AMAmethystApplyExternalHomeURL(url);
    return YES;
}
