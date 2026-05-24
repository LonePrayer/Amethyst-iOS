#import "SceneDelegate.h"
#import "LauncherNavigationController.h"
#import "LauncherSplitViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

extern UIWindow *mainWindow;

static NSString *SideStoreSignedBundleIdentifier(void) {
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

@interface SceneDelegate ()

@property (nonatomic, assign) BOOL pendingSideJITLaunch;

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.frame = windowScene.coordinateSpace.bounds;
    mainWindow = self.window;
    launchInitialViewController(self.window);
    [self.window makeKeyAndVisible];

    NSURL *url = connectionOptions.URLContexts.allObjects.firstObject.URL;
    if (url) {
        [self handleURL:url];
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
    CallbackBridge_pauseGameIfNeed();
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (url) {
        [self handleURL:url];
    }
}

- (void)handleURL:(NSURL *)url {
    NSString *sideStoreScheme = [NSString stringWithFormat:@"sidestore-%@", NSBundle.mainBundle.bundleIdentifier];
    NSString *signedSideStoreScheme = [NSString stringWithFormat:@"sidestore-%@", SideStoreSignedBundleIdentifier()];
    if (![url.scheme isEqualToString:@"amethyst"] && ![url.scheme isEqualToString:sideStoreScheme] && ![url.scheme isEqualToString:signedSideStoreScheme]) {
        return;
    }

    if ([url.host isEqualToString:@"jit-enabled"]) {
        NSLog(@"[SideJIT] Received JIT return URL: %@", url.absoluteString);
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"AMInternalDolphinJITHandshakeComplete"];
        [NSUserDefaults.standardUserDefaults synchronize];
        [NSNotificationCenter.defaultCenter postNotificationName:@"AMJITStatusDidChangeNotification" object:nil];
        if ([NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalDolphinAutoBootPath"].length > 0) {
            [NSNotificationCenter.defaultCenter postNotificationName:@"AMDolphinAutoBootRequestedNotification" object:nil];
        }
        if ([NSUserDefaults.standardUserDefaults stringForKey:@"AMInternalPS2AutoBootPath"].length > 0) {
            [NSNotificationCenter.defaultCenter postNotificationName:@"AMPS2AutoBootRequestedNotification" object:nil];
        }
        return;
    }

    if ([url.host isEqualToString:@"launch-dolphin"]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *path = nil;
        BOOL skipJIT = NO;
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"path"]) {
                path = item.value;
            } else if ([item.name isEqualToString:@"skip-jit"]) {
                skipJIT = [item.value isEqualToString:@"1"];
            }
        }

        if (path.length > 0) {
            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
            [defaults setObject:path forKey:@"AMInternalDolphinAutoBootPath"];
            [defaults setBool:skipJIT forKey:@"AMInternalDolphinAutoBootSkipJIT"];
            [defaults synchronize];
            NSLog(@"[Dolphin] Queued URL auto boot: %@", path);
            [NSNotificationCenter.defaultCenter postNotificationName:@"AMDolphinAutoBootRequestedNotification" object:nil];
        }
        return;
    }

    if ([url.host isEqualToString:@"launch-minecraft"]) {
        NSLog(@"[SideJIT] Received return URL: %@", url.absoluteString);
        self.pendingSideJITLaunch = YES;
        [self runPendingSideJITLaunch];
    }
}

- (void)runPendingSideJITLaunch {
    if (!self.pendingSideJITLaunch) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        LauncherNavigationController *launcher = [self launcherNavigationController];
        if (launcher) {
            self.pendingSideJITLaunch = NO;
            [launcher launchMinecraftFromURL];
            return;
        }

        NSLog(@"[SideJIT] Launcher is not ready; retrying return URL launch");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runPendingSideJITLaunch];
        });
    });
}

- (LauncherNavigationController *)launcherNavigationController {
    UIViewController *rootViewController = self.window.rootViewController;
    if (![rootViewController isKindOfClass:LauncherSplitViewController.class]) {
        return nil;
    }

    UISplitViewController *splitViewController = (UISplitViewController *)rootViewController;
    for (UIViewController *viewController in splitViewController.viewControllers) {
        if ([viewController isKindOfClass:LauncherNavigationController.class]) {
            return (LauncherNavigationController *)viewController;
        }
    }
    return nil;
}

@end
