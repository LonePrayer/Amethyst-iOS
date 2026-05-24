#import <UIKit/UIKit.h>

NSMutableArray<NSDictionary *> *localVersionList, *remoteVersionList;

@interface LauncherNavigationController : UINavigationController

@property(nonatomic) UIProgressView *progressViewMain, *progressViewSub;
@property(nonatomic) UILabel* progressText;

- (void)enterModInstallerWithPath:(NSString *)path hitEnterAfterWindowShown:(BOOL)hitEnter;
- (void)fetchLocalVersionList;
- (void)setInteractionEnabled:(BOOL)enable forDownloading:(BOOL)downloading;
- (void)launchMinecraftFromURL;
- (void)initializeJITWithCompletion:(void(^)(void))handler;
- (void)runAfterJITEnabled:(void(^)(void))handler;
- (void)forceInitializeJITWithCompletion:(void(^)(void))handler;

@end
