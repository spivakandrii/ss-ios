#import <Foundation/Foundation.h>

@interface SSHTTPClient : NSObject

+ (NSData *)fetchURL:(NSString *)urlString;
+ (void)logToFile:(NSString *)msg;

@end
