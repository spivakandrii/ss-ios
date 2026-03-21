#!/bin/bash
set -e

THEOS=$HOME/theos
SDK=$THEOS/sdks/iPhoneOS9.3.sdk
TOOLCHAIN=$THEOS/toolchain/linux/iphone/bin
OPENSSL_DIR=$HOME/openssl-build/openssl-1.1.1w
WORKDIR=$HOME/curl-build

rm -rf $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

echo "=== Downloading curl 7.88.1 ==="
wget -q https://curl.se/download/curl-7.88.1.tar.gz
tar xzf curl-7.88.1.tar.gz
cd curl-7.88.1

# Create a minimal curl_config.h for cross-compile
cat > lib/curl_config.h << 'CONF'
#define HAVE_ARPA_INET_H 1
#define HAVE_FCNTL_H 1
#define HAVE_NETDB_H 1
#define HAVE_NETINET_IN_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_UNISTD_H 1
#define HAVE_RECV 1
#define HAVE_SEND 1
#define HAVE_SOCKET 1
#define HAVE_SELECT 1
#define HAVE_FCNTL_O_NONBLOCK 1
#define HAVE_GETADDRINFO 1
#define HAVE_FREEADDRINFO 1
#define HAVE_STRUCT_TIMEVAL 1
#define HAVE_SYS_UN_H 1
#define HAVE_STRTOLL 1
#define HAVE_LONGLONG 1
#define HAVE_BOOL_T 1
#define HAVE_STDBOOL_H 1
#define HAVE_STRERROR_R 1
#define HAVE_SIGNAL 1
#define HAVE_SIGACTION 1
#define HAVE_POLL_H 1
#define HAVE_POLL_FINE 1
#define HAVE_ALARM 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_INET_PTON 1
#define HAVE_INET_NTOP 1

#define USE_OPENSSL 1
#define USE_SSLEAY 1
#define HAVE_OPENSSL_CRYPTO_H 1
#define HAVE_OPENSSL_ERR_H 1
#define HAVE_OPENSSL_PEM_H 1
#define HAVE_OPENSSL_RSA_H 1
#define HAVE_OPENSSL_SSL_H 1
#define HAVE_OPENSSL_X509_H 1
#define HAVE_LIBSSL 1
#define HAVE_LIBCRYPTO 1

#define OS "arm-apple-darwin11"
#define SIZEOF_INT 4
#define SIZEOF_SHORT 2
#define SIZEOF_LONG 4
#define SIZEOF_SIZE_T 4
#define SIZEOF_CURL_OFF_T 8
#define SIZEOF_TIME_T 4

#define CURL_DISABLE_LDAP 1
#define CURL_DISABLE_LDAPS 1
#define CURL_DISABLE_DICT 1
#define CURL_DISABLE_TELNET 1
#define CURL_DISABLE_TFTP 1
#define CURL_DISABLE_POP3 1
#define CURL_DISABLE_IMAP 1
#define CURL_DISABLE_SMTP 1
#define CURL_DISABLE_GOPHER 1
#define CURL_DISABLE_MQTT 1
#define CURL_DISABLE_RTSP 1
#define CURL_DISABLE_SMB 1
#define CURL_DISABLE_FTP 1
#define CURL_DISABLE_FILE 1
CONF

CC="$TOOLCHAIN/clang -target arm-apple-darwin11 -arch armv7 -isysroot $SDK -miphoneos-version-min=5.1 -Wno-unused-command-line-argument"
AR="$TOOLCHAIN/llvm-ar"
RANLIB="$TOOLCHAIN/ranlib"

CFLAGS="-I$OPENSSL_DIR/include -Iinclude -Ilib -DHAVE_CONFIG_H -DBUILDING_LIBCURL -DCURL_STATICLIB -Os"

echo "=== Compiling curl source files ==="

# Get all .c files in lib/ and lib/vtls/ (excluding stuff we don't need)
OBJS=""
for f in lib/*.c lib/vtls/*.c lib/vauth/*.c; do
    base=$(basename "$f" .c)
    # Skip files we don't need
    case "$base" in
        curl_ntlm_core|curl_ntlm_wb|openldap|ldap|telnet|dict|tftp|imap|pop3|smtp|gopher|mqtt|rtsp|pingpong|bufq|bufref)
            continue ;;
    esac
    echo -n "."
    $CC $CFLAGS -c "$f" -o "lib/${base}.o" 2>/dev/null || true
    if [ -f "lib/${base}.o" ]; then
        OBJS="$OBJS lib/${base}.o"
    fi
done
echo ""

echo "=== Creating libcurl.a ==="
$AR rc libcurl.a $OBJS
$RANLIB libcurl.a 2>/dev/null || true

echo "=== Result ==="
ls -lh libcurl.a

echo "=== Copying to project ==="
cp libcurl.a /mnt/c/Source/ss_ios/lib/
mkdir -p /mnt/c/Source/ss_ios/include/curl
cp include/curl/curl.h include/curl/curlver.h include/curl/easy.h \
   include/curl/header.h include/curl/multi.h include/curl/options.h \
   include/curl/system.h include/curl/typecheck-gcc.h include/curl/urlapi.h \
   include/curl/websockets.h \
   /mnt/c/Source/ss_ios/include/curl/ 2>/dev/null || true

echo "=== DONE ==="
ls -lh /mnt/c/Source/ss_ios/lib/
