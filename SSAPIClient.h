#import <Foundation/Foundation.h>

typedef void (^SSAPICompletion)(id result, NSError *error);

@interface SSAPIClient : NSObject

@property (nonatomic, copy) NSString *language; // "uk" or "ro"

+ (instancetype)shared;

- (void)fetchQuarterlies:(SSAPICompletion)completion;
- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion;
- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion;
- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion;

@end
