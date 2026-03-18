#import "SSHTTPClient.h"

// Ensure wolfSSL features before including
#ifndef HAVE_SNI
#define HAVE_SNI
#endif
#ifndef WOLFSSL_TLS12
#define WOLFSSL_TLS12
#endif
#ifndef HAVE_TLS_EXTENSIONS
#define HAVE_TLS_EXTENSIONS
#endif

#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/ssl.h>
#include <wolfssl/wolfcrypt/types.h>
#include <sys/socket.h>
#include <Security/SecRandom.h>

/* Custom RNG for iOS - use SecRandomCopyBytes */
int custom_rand_generate_block(unsigned char *output, unsigned int sz) {
    return SecRandomCopyBytes(kSecRandomDefault, sz, output) == 0 ? 0 : -1;
}
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>

static BOOL _wolfInited = NO;

@implementation SSHTTPClient

+ (BOOL)ensureInit {
    if (_wolfInited) return YES;
    @try {
        int ret = wolfSSL_Init();
        _wolfInited = (ret == SSL_SUCCESS || ret == 0);
    } @catch (NSException *e) {
        _wolfInited = NO;
    }
    return _wolfInited;
}

+ (NSData *)httpsGetURL:(NSString *)urlString error:(NSError **)outError {
    if (![self ensureInit]) {
        if (outError) *outError = [self errorWithMsg:@"wolfSSL init failed"];
        return nil;
    }
    // Parse URL
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = [url host];
    NSString *path = [url path];
    if ([url query]) {
        path = [NSString stringWithFormat:@"%@?%@", path, [url query]];
    }
    int port = [url port] ? [[url port] intValue] : 443;

    // TCP connect
    int sock = [self connectToHost:host port:port];
    if (sock < 0) {
        if (outError) *outError = [self errorWithMsg:@"TCP connection failed"];
        return nil;
    }

    // wolfSSL setup
    WOLFSSL_CTX *ctx = wolfSSL_CTX_new(wolfTLSv1_2_client_method());
    if (!ctx) {
        close(sock);
        if (outError) *outError = [self errorWithMsg:@"wolfSSL CTX failed"];
        return nil;
    }

    // Don't verify certs (we don't have CA bundle on iOS 5)
    wolfSSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, NULL);

    WOLFSSL *ssl = wolfSSL_new(ctx);
    if (!ssl) {
        wolfSSL_CTX_free(ctx);
        close(sock);
        if (outError) *outError = [self errorWithMsg:@"wolfSSL new failed"];
        return nil;
    }

    // SNI (Server Name Indication) - required by most modern servers
    wolfSSL_UseSNI(ssl, WOLFSSL_SNI_HOST_NAME,
                   [host UTF8String], (unsigned short)[host length]);

    wolfSSL_set_fd(ssl, sock);

    // TLS handshake
    int ret = wolfSSL_connect(ssl);
    if (ret != SSL_SUCCESS) {
        int err = wolfSSL_get_error(ssl, ret);
        NSString *msg = [NSString stringWithFormat:@"TLS handshake failed: %d", err];
        wolfSSL_free(ssl);
        wolfSSL_CTX_free(ctx);
        close(sock);
        if (outError) *outError = [self errorWithMsg:msg];
        return nil;
    }

    // Send HTTP request
    NSString *request = [NSString stringWithFormat:
        @"GET %@ HTTP/1.1\r\n"
        @"Host: %@\r\n"
        @"User-Agent: SabbathSchool/1.0\r\n"
        @"Accept: application/json\r\n"
        @"Connection: close\r\n"
        @"\r\n",
        path, host];

    const char *reqBytes = [request UTF8String];
    wolfSSL_write(ssl, reqBytes, (int)strlen(reqBytes));

    // Read response
    NSMutableData *responseData = [NSMutableData data];
    char buf[4096];
    int bytesRead;
    while ((bytesRead = wolfSSL_read(ssl, buf, sizeof(buf))) > 0) {
        [responseData appendBytes:buf length:bytesRead];
    }

    wolfSSL_shutdown(ssl);
    wolfSSL_free(ssl);
    wolfSSL_CTX_free(ctx);
    close(sock);

    // Parse HTTP response - find body after \r\n\r\n
    NSData *body = [self extractBodyFromHTTPResponse:responseData];
    if (!body) {
        if (outError) *outError = [self errorWithMsg:@"Invalid HTTP response"];
        return nil;
    }

    return body;
}

+ (int)connectToHost:(NSString *)host port:(int)port {
    struct addrinfo hints, *res, *p;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    NSString *portStr = [NSString stringWithFormat:@"%d", port];
    int status = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res);
    if (status != 0) return -1;

    int sock = -1;
    for (p = res; p != NULL; p = p->ai_next) {
        sock = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sock < 0) continue;

        // Set timeout
        struct timeval tv;
        tv.tv_sec = 15;
        tv.tv_usec = 0;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

        if (connect(sock, p->ai_addr, p->ai_addrlen) == 0) break;
        close(sock);
        sock = -1;
    }

    freeaddrinfo(res);
    return sock;
}

+ (NSData *)extractBodyFromHTTPResponse:(NSData *)response {
    const char *bytes = [response bytes];
    NSUInteger len = [response length];

    // Find \r\n\r\n
    for (NSUInteger i = 0; i + 3 < len; i++) {
        if (bytes[i] == '\r' && bytes[i+1] == '\n' && bytes[i+2] == '\r' && bytes[i+3] == '\n') {
            NSUInteger bodyStart = i + 4;
            if (bodyStart < len) {
                return [response subdataWithRange:NSMakeRange(bodyStart, len - bodyStart)];
            }
        }
    }
    return nil;
}

+ (NSError *)errorWithMsg:(NSString *)msg {
    NSDictionary *info = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"SSHTTPClient" code:-1 userInfo:info];
}

@end
