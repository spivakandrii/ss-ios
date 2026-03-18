#import <Foundation/Foundation.h>

// Simple HTTPS client using wolfSSL for TLS 1.2 on iOS 5
@interface SSHTTPClient : NSObject

+ (NSData *)httpsGetURL:(NSString *)urlString error:(NSError **)outError;

@end
