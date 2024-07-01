#!/usr/bin/env sh
# https://github.com/wren-lang/wren-cli/archive/refs/tags/0.4.0.tar.gz
# fafdc5d6615114d40de3956cd3a255e8737dadf8bd758b48bac00db61563cb4c

set -e

root=$PWD

src=$SRCDIR
cd $src

wren_to_c_string="$root/wren/xos/bin/wren_to_c_string"

wren_modules="
glob
io
os
repl
scheduler
timer
"
for m in $wren_modules
do
  < module/${m}.wren $wren_to_c_string ${m} > module/${m}.wren.inc
done

cflags="
  -Imodule \
  -Icli \
  -I $root/libuv/xos/include \
  -I $root/wren/xos/include \
  -I $root/lmdb/xos/include \
  -I $root/ucl/xos/include \
  -I $root/libglob/xos/include \
"

libs="
  $root/libuv/xos/lib/libuv.a \
  $root/wren/xos/lib/libwren.a \
  $root/lmdb/xos/lib/liblmdb.a \
  $root/ucl/xos/lib/libucl.a \
  $root/libglob/xos/lib/libglob.a \
"

zig build-lib -target $TARGET -O $OPT \
  --name wrencli \
  $cflags \
  cli/cli.c \
  cli/modules.c \
  cli/path.c \
  cli/vm.c \
  module/*.c \
  -Mzig=xos/xos.zig \
  -lc

zig build-exe -target $TARGET -O $OPT \
  --name wren \
  $cflags \
  cli/main.c \
  libwrencli.a \
  $libs \
  -lc

cd $BUILD_OUT
mkdir bin lib include
mv $src/wren bin
mv $src/libwrencli.a lib
mv $src/cli/cli.h include
