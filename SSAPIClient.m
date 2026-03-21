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

- (NSString *)dataPath {
    NSString *bundle = [[NSBundle mainBundle] resourcePath];
    return [bundle stringByAppendingPathComponent:@"data"];
}

#pragma mark - Public API

- (void)fetchQuarterlies:(SSAPICompletion)completion {
    NSString *localPath = [NSString stringWithFormat:@"%@/%@/quarterlies.json", [self dataPath], self.language];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/index.json", SS_API_BASE, self.language];
    [self loadLocalPath:localPath orRemoteURL:remoteURL completion:completion];
}

- (void)fetchLessonsForQuarterly:(NSString *)quarterlyId completion:(SSAPICompletion)completion {
    NSString *localPath = [NSString stringWithFormat:@"%@/%@/%@/lessons.json", [self dataPath], self.language, quarterlyId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/index.json", SS_API_BASE, self.language, quarterlyId];
    [self loadLocalPath:localPath orRemoteURL:remoteURL completion:completion];
}

- (void)fetchLessonDetailForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId completion:(SSAPICompletion)completion {
    NSString *localPath = [NSString stringWithFormat:@"%@/%@/%@/%@/index.json", [self dataPath], self.language, quarterlyId, lessonId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/index.json", SS_API_BASE, self.language, quarterlyId, lessonId];
    [self loadLocalPath:localPath orRemoteURL:remoteURL completion:completion];
}

- (void)fetchDayReadForQuarterly:(NSString *)quarterlyId lesson:(NSString *)lessonId day:(NSString *)dayId completion:(SSAPICompletion)completion {
    NSString *localPath = [NSString stringWithFormat:@"%@/%@/%@/%@/%@.json", [self dataPath], self.language, quarterlyId, lessonId, dayId];
    NSString *remoteURL = [NSString stringWithFormat:@"%@/%@/quarterlies/%@/lessons/%@/days/%@/read/index.json", SS_API_BASE, self.language, quarterlyId, lessonId, dayId];
    [self loadLocalPath:localPath orRemoteURL:remoteURL completion:completion];
}

#pragma mark - Load with fallback

- (void)loadLocalPath:(NSString *)localPath orRemoteURL:(NSString *)remoteURL completion:(SSAPICompletion)completion {
    // Try local first
    [SSHTTPClient logToFile:[NSString stringWithFormat:@"APIClient: trying local: %@", localPath]];
    id json = [self loadJSON:localPath];
    if (json) {
        [SSHTTPClient logToFile:@"APIClient: found local, returning"];
        if (completion) completion(json, nil);
        return;
    }
    [SSHTTPClient logToFile:[NSString stringWithFormat:@"APIClient: no local, trying remote: %@", remoteURL]];

    // Try network in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [SSHTTPClient fetchURL:remoteURL];
        id remoteJson = nil;
        if (data) {
            remoteJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(remoteJson, remoteJson ? nil : [self errorWithMessage:@"Не вдалося завантажити дані"]);
            }
        });
    });
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
