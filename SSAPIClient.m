#import "SSAPIClient.h"

@implementation SSAPIClient

+ (instancetype)shared {
    static SSAPIClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SSAPIClient alloc] init];
        instance.language = @"uk";
    });
    return instance;
}

- (NSString *)dataPath {
    NSString *bundle = [[NSBundle mainBundle] resourcePath];
    return [bundle stringByAppendingPathComponent:@"data"];
}

#pragma mark - Public API

- (void)fetchQuarterlies:(SSAPICompletion)completion {
    NSString *path = [NSString stringWithFormat:@"%@/%@/quarterlies.json", [self dataPath], self.language];
    id json = [self loadJSON:path];
    if (completion) completion(json, json ? nil : [self errorWithMessage:@"Файл не знайдено"]);
}

- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion {
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/lessons.json", [self dataPath], self.language, quarterlyId];
    id json = [self loadJSON:path];
    if (completion) completion(json, json ? nil : [self errorWithMessage:@"Уроки не знайдено"]);
}

- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion {
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@/index.json", [self dataPath], self.language, quarterlyId, lessonId];
    id json = [self loadJSON:path];
    if (completion) completion(json, json ? nil : [self errorWithMessage:@"Урок не знайдено"]);
}

- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion {
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@/%@.json", [self dataPath], self.language, quarterlyId, lessonId, dayId];
    id json = [self loadJSON:path];
    if (completion) completion(json, json ? nil : [self errorWithMessage:@"День не знайдено"]);
}

#pragma mark - Helpers

- (id)loadJSON:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (NSError *)errorWithMessage:(NSString *)msg {
    NSDictionary *info = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"SSAPIClient" code:404 userInfo:info];
}

@end
