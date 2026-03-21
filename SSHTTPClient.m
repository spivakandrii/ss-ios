#import "SSHTTPClient.h"
#include <curl/curl.h>

static size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    NSMutableData *data = (__bridge NSMutableData *)userdata;
    [data appendBytes:ptr length:size * nmemb];
    return size * nmemb;
}

@implementation SSHTTPClient

+ (void)initialize {
    curl_global_init(CURL_GLOBAL_SSL);
}

+ (void)logToFile:(NSString *)msg {
    NSString *path = @"/tmp/ss_debug.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [fh seekToEndOfFile];
    [fh writeData:[[msg stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

+ (NSData *)fetchURL:(NSString *)urlString {
    [self logToFile:[NSString stringWithFormat:@"fetchURL called: %@", urlString]];
    CURL *curl = curl_easy_init();
    if (!curl) {
        [self logToFile:@"curl_easy_init failed!"];
        return nil;
    }

    NSMutableData *responseData = [[NSMutableData alloc] init];

    curl_easy_setopt(curl, CURLOPT_URL, [urlString UTF8String]);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (__bridge void *)responseData);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 15L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

    NSLog(@"SSHTTPClient: fetching %@", urlString);

    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        [self logToFile:[NSString stringWithFormat:@"curl error %d - %s for URL: %@",
              res, curl_easy_strerror(res), urlString]];
        curl_easy_cleanup(curl);
        return nil;
    }

    long httpCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
    curl_easy_cleanup(curl);

    [self logToFile:[NSString stringWithFormat:@"HTTP %ld, data size: %lu for URL: %@", httpCode, (unsigned long)[responseData length], urlString]];

    if (httpCode != 200) {
        return nil;
    }

    return responseData;
}

@end
