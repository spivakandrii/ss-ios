#import <UIKit/UIKit.h>

@interface SSReadVC : UIViewController

@property (nonatomic, copy) NSString *quarterlyId;
@property (nonatomic, copy) NSString *lessonId;
@property (nonatomic, copy) NSString *lessonTitle;
@property (nonatomic, strong) NSArray *days;
@property (nonatomic, assign) NSInteger initialDayIndex; // 0-based, for auto-open

@end
