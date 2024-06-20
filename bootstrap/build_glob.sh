#!/usr/bin/env sh
# https://api.github.com/repos/void-linux/libglob/tarball/55ae662
# 4236e4e00ea0824882dc9f80fc2e1f9aaf40451ef787104c099a96ad9dc09e32

set -e

src=$SRCDIR
cd $src

zig build-lib -target $TARGET -O $OPT \
  glob.c \
  -lc

cd $BUILD_OUT
mkdir include lib
mv $src/libglob.a lib
mv $src/glob.h include
