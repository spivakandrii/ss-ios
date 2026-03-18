#import <Foundation/Foundation.h>

#define SS_API_BASE @"https://sabbath-school.adventech.io/api/v2"

typedef void (^SSAPICompletion)(id result, NSError *error);

@interface SSAPIClient : NSObject

@property (nonatomic, copy) NSString *language; // "uk" or "ro"
@property (nonatomic, assign) BOOL useNetwork; // YES = online, NO = offline (default)

+ (instancetype)shared;

- (void)fetchQuarterlies:(SSAPICompletion)completion;
- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion;
- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion;
- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion;

// Test TLS 1.2 connectivity
- (void)testOnlineConnection:(void(^)(BOOL success))completion;

@end
