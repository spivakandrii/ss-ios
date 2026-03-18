#import "SSAPIClient.h"
#import <CFNetwork/CFNetwork.h>
#import <Security/Security.h>

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

#pragma mark - CFNetwork TLS 1.2

- (void)networkRequestURL:(NSString *)urlStr completion:(SSAPICompletion)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:urlStr];
        NSData *data = [self cfnetworkRequestWithURL:url];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data) {
                if (completion) completion(nil, [self errorWithMessage:@"Мережева помилка"]);
                return;
            }
            NSError *jsonErr = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (completion) completion(json, jsonErr);
        });
    });
}

- (NSData *)cfnetworkRequestWithURL:(NSURL *)url {
    // Create HTTP request
    CFStringRef method = CFSTR("GET");
    CFURLRef cfURL = (__bridge CFURLRef)url;
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, method, cfURL, kCFHTTPVersion1_1);

    NSString *host = [url host];
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Host"), (__bridge CFStringRef)host);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("User-Agent"), CFSTR("SabbathSchool/1.0"));

    // Create read stream
    CFReadStreamRef readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
    CFRelease(request);

    if (!readStream) return nil;

    // Enable TLS 1.2
    NSDictionary *sslSettings = [NSDictionary dictionaryWithObjectsAndKeys:
        @"kCFStreamSocketSecurityLevelTLSv1_2", (NSString *)kCFStreamSSLLevel,
        (id)kCFBooleanFalse, (NSString *)kCFStreamSSLValidatesCertificateChain,
        nil];
    CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef)sslSettings);

    // Also try setting SSL protocol directly
    CFReadStreamSetProperty(readStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);

    // Enable auto-redirect
    CFReadStreamSetProperty(readStream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);

    if (!CFReadStreamOpen(readStream)) {
        CFRelease(readStream);
        return nil;
    }

    // Read data
    NSMutableData *responseData = [NSMutableData data];
    UInt8 buffer[4096];
    CFIndex bytesRead;

    // Wait for stream to have data (with timeout)
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:30.0];
    while ([[NSDate date] compare:timeout] == NSOrderedAscending) {
        CFStreamStatus status = CFReadStreamGetStatus(readStream);
        if (status == kCFStreamStatusError || status == kCFStreamStatusAtEnd) break;

        if (CFReadStreamHasBytesAvailable(readStream)) {
            bytesRead = CFReadStreamRead(readStream, buffer, sizeof(buffer));
            if (bytesRead > 0) {
                [responseData appendBytes:buffer length:bytesRead];
            } else if (bytesRead == 0) {
                break; // EOF
            } else {
                responseData = nil;
                break; // Error
            }
        } else {
            // Small sleep to avoid busy loop
            [NSThread sleepForTimeInterval:0.05];
        }
    }

    // Check HTTP status
    CFHTTPMessageRef response = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    if (response) {
        CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(response);
        CFRelease(response);
        if (statusCode < 200 || statusCode >= 300) {
            responseData = nil;
        }
    }

    CFReadStreamClose(readStream);
    CFRelease(readStream);

    return responseData;
}

@end
