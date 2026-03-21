#import <Foundation/Foundation.h>

@interface SSHTTPClient : NSObject

+ (NSData *)fetchURL:(NSString *)urlString;

@end
