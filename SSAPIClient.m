#import "SSAPIClient.h"
#import "SSHTTPClient.h"

@implementation SSAPIClient

+ (instancetype)shared {
    static SSAPIClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SSAPIClient alloc] init];
        instance.language = @"uk";
        instance.useNetwork = NO;
    });
    return instance;
}

#pragma mark - Data path (offline)

- (NSString *)dataPath {
    NSString *bundle = [[NSBundle mainBundle] resourcePath];
    return [bundle stringByAppendingPathComponent:@"data"];
}

#pragma mark - Public API

- (void)fetchQuarterlies:(SSAPICompletion)completion {
    if (self.useNetwork) {
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@/quarterlies/index.json", SS_API_BASE, self.language];
        [self networkRequestURL:urlStr completion:completion];
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@/quarterlies.json", [self dataPath], self.language];
        id json = [self loadJSON:path];
        if (completion) completion(json, json ? nil : [self errorWithMessage:@"Файл не знайдено"]);
    }
}

- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion {
    if (self.useNetwork) {
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/index.json", SS_API_BASE, self.language, quarterlyId];
        [self networkRequestURL:urlStr completion:completion];
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@/%@/lessons.json", [self dataPath], self.language, quarterlyId];
        id json = [self loadJSON:path];
        if (completion) completion(json, json ? nil : [self errorWithMessage:@"Уроки не знайдено"]);
    }
}

- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion {
    if (self.useNetwork) {
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/index.json", SS_API_BASE, self.language, quarterlyId, lessonId];
        [self networkRequestURL:urlStr completion:completion];
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@/index.json", [self dataPath], self.language, quarterlyId, lessonId];
        id json = [self loadJSON:path];
        if (completion) completion(json, json ? nil : [self errorWithMessage:@"Урок не знайдено"]);
    }
}

- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion {
    if (self.useNetwork) {
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/days/%@/read/index.json", SS_API_BASE, self.language, quarterlyId, lessonId, dayId];
        [self networkRequestURL:urlStr completion:completion];
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@/%@.json", [self dataPath], self.language, quarterlyId, lessonId, dayId];
        id json = [self loadJSON:path];
        if (completion) completion(json, json ? nil : [self errorWithMessage:@"День не знайдено"]);
    }
}

- (void)testOnlineConnection:(void(^)(BOOL success))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/%@/quarterlies/index.json", SS_API_BASE, self.language];
    [self networkRequestURL:urlStr completion:^(id result, NSError *error) {
        if (completion) completion(result != nil && error == nil);
    }];
}

#pragma mark - Offline JSON

- (id)loadJSON:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (NSError *)errorWithMessage:(NSString *)msg {
    NSDictionary *info = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"SSAPIClient" code:404 userInfo:info];
}

#pragma mark - Network (wolfSSL TLS 1.2)

- (void)networkRequestURL:(NSString *)urlStr completion:(SSAPICompletion)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *netErr = nil;
        NSData *data = [SSHTTPClient httpsGetURL:urlStr error:&netErr];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data) {
                if (completion) completion(nil, netErr ? netErr : [self errorWithMessage:@"Мережева помилка"]);
                return;
            }
            NSError *jsonErr = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (completion) completion(json, jsonErr);
        });
    });
}

@end
