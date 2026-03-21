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

+ (NSData *)fetchURL:(NSString *)urlString {
    CURL *curl = curl_easy_init();
    if (!curl) return nil;

    NSMutableData *responseData = [[NSMutableData alloc] init];

    curl_easy_setopt(curl, CURLOPT_URL, [urlString UTF8String]);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (__bridge void *)responseData);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 15L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);

    // Use Mozilla CA bundle path (or skip verification for now)
    // curl_easy_setopt(curl, CURLOPT_CAINFO, "/path/to/cacert.pem");
    // For testing, disable cert verification:
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);

    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        NSLog(@"SSHTTPClient: curl error %d - %s for URL: %@",
              res, curl_easy_strerror(res), urlString);
        curl_easy_cleanup(curl);
        return nil;
    }

    long httpCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
    curl_easy_cleanup(curl);

    if (httpCode != 200) {
        NSLog(@"SSHTTPClient: HTTP %ld for URL: %@", httpCode, urlString);
        return nil;
    }

    return responseData;
}

@end
