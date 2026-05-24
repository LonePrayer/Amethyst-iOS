#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const AMAmethystExternalFolderPathKey;

NSURL * _Nullable AMAmethystExternalHomeURL(BOOL startAccessing);
void AMAmethystApplyExternalHomeURL(NSURL *url);
BOOL AMAmethystPrepareExternalHomeURL(NSURL *url, NSString *_Nullable *_Nullable failureMessage);
BOOL AMAmethystStoreExternalHomeURL(NSURL *url, NSString *_Nullable *_Nullable failureMessage);
BOOL AMAmethystApplyStoredExternalHomeIfAvailable(void);

NS_ASSUME_NONNULL_END
