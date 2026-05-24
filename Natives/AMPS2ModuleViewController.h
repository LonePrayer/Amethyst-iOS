#import <UIKit/UIKit.h>

@class AMModule;

NS_ASSUME_NONNULL_BEGIN

@interface AMPS2ModuleViewController : UITableViewController <UIDocumentPickerDelegate>

- (instancetype)initWithModule:(AMModule *)module;

@end

NS_ASSUME_NONNULL_END
