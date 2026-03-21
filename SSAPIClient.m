#import "SSAPIClient.h"
#import "SSHTTPClient.h"

#define SS_API_BASE @"https://sabbath-school.adventech.io/api/v2"

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

- (NSString *)bundlePath {
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"data"];
}

- (NSString *)cachePath {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *cache = [docs stringByAppendingPathComponent:@"ssdata"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:nil error:nil];
    return cache;
}

#pragma mark - Public API

- (void)fetchQuarterlies:(SSAPICompletion)completion {
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@/quarterlies.json", [self cachePath], self.language];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@/quarterlies.json", [self bundlePath], self.language];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/index.json", SS_API_BASE, self.language];
    [self loadCachePath:cachePath bundlePath:bundlePath remoteURL:remoteURL completion:completion];
}

- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion {
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@/%@/lessons.json", [self cachePath], self.language, quarterlyId];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@/%@/lessons.json", [self bundlePath], self.language, quarterlyId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/index.json", SS_API_BASE, self.language, quarterlyId];
    [self loadCachePath:cachePath bundlePath:bundlePath remoteURL:remoteURL completion:completion];
}

- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion {
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@/%@/%@/index.json", [self cachePath], self.language, quarterlyId, lessonId];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@/%@/%@/index.json", [self bundlePath], self.language, quarterlyId, lessonId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/index.json", SS_API_BASE, self.language, quarterlyId, lessonId];
    [self loadCachePath:cachePath bundlePath:bundlePath remoteURL:remoteURL completion:completion];
}

- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion {
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@/%@/%@/%@.json", [self cachePath], self.language, quarterlyId, lessonId, dayId];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@/%@/%@/%@.json", [self bundlePath], self.language, quarterlyId, lessonId, dayId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/days/%@/read/index.json", SS_API_BASE, self.language, quarterlyId, lessonId, dayId];
    [self loadCachePath:cachePath bundlePath:bundlePath remoteURL:remoteURL completion:completion];
}

#pragma mark - Smart loading: cache → bundle → network

- (void)loadCachePath:(NSString *)cachePath bundlePath:(NSString *)bundlePath remoteURL:(NSString *)remoteURL completion:(SSAPICompletion)completion {
    // 1. Try cache (Documents — newest data)
    id cached = [self loadJSON:cachePath];
    if (cached) {
        if (completion) completion(cached, nil);
        // Silently refresh in background — no callback to avoid reload loops
        [self backgroundFetch:remoteURL saveTo:cachePath];
        return;
    }

    // 2. Try bundle (shipped data)
    id bundled = [self loadJSON:bundlePath];
    if (bundled) {
        if (completion) completion(bundled, nil);
        // Silently cache in background — no callback
        [self backgroundFetch:remoteURL saveTo:cachePath];
        return;
    }

    // 3. No local data — fetch from network (user sees spinner)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [SSHTTPClient fetchURL:remoteURL];
        id json = nil;
        if (data) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                [self saveData:data toPath:cachePath];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(json, json ? nil : [self errorWithMessage:@"Не вдалося завантажити дані"]);
            }
        });
    });
}

- (void)backgroundFetch:(NSString *)remoteURL saveTo:(NSString *)cachePath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSData *data = [SSHTTPClient fetchURL:remoteURL];
        if (data) {
            [self saveData:data toPath:cachePath];
        }
    });
}

#pragma mark - Helpers

- (void)saveData:(NSData *)data toPath:(NSString *)path {
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [data writeToFile:path atomically:YES];
}

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
