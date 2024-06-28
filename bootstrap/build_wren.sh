#!/usr/bin/env sh
# https://github.com/wren-lang/wren/archive/refs/tags/0.4.0.tar.gz
# 23c0ddeb6c67a4ed9285bded49f7c91714922c2e7bb88f42428386bf1cf7b339

set -e

src=$SRCDIR
cd $src

zig build-exe -O ReleaseSafe wren_to_c_string.c -lc
< src/optional/wren_opt_meta.wren ./wren_to_c_string wren_opt_meta > src/optional/wren_opt_meta.wren.inc
< src/vm/wren_core.wren ./wren_to_c_string wren_core > src/vm/wren_core.wren.inc

zig build-lib -target $TARGET -O $OPT \
  --name wren \
  -DWREN_OPT_META=1 \
  -DWREN_OPT_RANDOM=0 \
  src/vm/*.c \
  src/optional/*.c \
  -I src/include \
  -I src/optional \
  -I src/vm \
  -lc

# install
cd $BUILD_OUT
mkdir lib include bin
cp $src/src/include/wren.h include
cp $src/libwren.a lib
cp $src/wren_to_c_string bin
