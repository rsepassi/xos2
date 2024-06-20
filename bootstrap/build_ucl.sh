#!/usr/bin/env sh
# https://github.com/vstakhov/libucl/archive/refs/tags/0.9.2.tar.gz
# f63ddee1d7f5217cac4f9cdf72b9c5e8fe43cfe5725db13f1414b0d8a369bbe0

set -e

src=$SRCDIR
cd $src

zig build-lib -target $TARGET -O $OPT \
  --name ucl \
  -Iinclude -Isrc -Iklib -Iuthash \
  src/*.c \
  -lc

# install
cd $BUILD_OUT
mkdir lib include
cp "$src/include/ucl.h" include
cp $src/libucl.a lib
