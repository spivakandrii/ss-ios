#!/bin/bash
set -e

THEOS=$HOME/theos
SDK=$THEOS/sdks/iPhoneOS9.3.sdk
TOOLCHAIN=$THEOS/toolchain/linux/iphone/bin
WORKDIR=$HOME/openssl-build

rm -rf $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

echo "=== Downloading OpenSSL 1.1.1w ==="
wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar xzf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w

echo "=== Configuring for armv7 cross-compile ==="

export CC="$TOOLCHAIN/clang -target arm-apple-darwin11 -arch armv7 -isysroot $SDK -miphoneos-version-min=5.1"
export AR="$TOOLCHAIN/ar"
export RANLIB="$TOOLCHAIN/ranlib"

./Configure linux-generic32 no-shared no-dso no-engine no-tests no-asm no-async \
  --prefix=$WORKDIR/output \
  -DOPENSSL_NO_SECURE_MEMORY \
  -Wno-unused-command-line-argument

echo "=== Building ==="
make -j$(nproc) libcrypto.a libssl.a 2>&1 | tail -5

echo "=== Result ==="
ls -lh libssl.a libcrypto.a

echo "=== Copying to project ==="
mkdir -p /mnt/c/Source/ss_ios/lib
mkdir -p /mnt/c/Source/ss_ios/include
cp libssl.a libcrypto.a /mnt/c/Source/ss_ios/lib/
cp -r include/openssl /mnt/c/Source/ss_ios/include/

echo "=== DONE ==="
ls -lh /mnt/c/Source/ss_ios/lib/
