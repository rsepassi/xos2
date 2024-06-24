#!/usr/bin/env sh
# https://github.com/libuv/libuv/archive/refs/tags/v1.48.0.tar.gz
# 8c253adb0f800926a6cbd1c6576abae0bc8eb86a4f891049b72f9e5b7dc58f33

set -e

src=$SRCDIR
cd $src

unix_files="
src/unix/async.c
src/unix/core.c
src/unix/dl.c
src/unix/fs.c
src/unix/getaddrinfo.c
src/unix/getnameinfo.c
src/unix/loop-watcher.c
src/unix/loop.c
src/unix/pipe.c
src/unix/poll.c
src/unix/process.c
src/unix/random-devurandom.c
src/unix/signal.c
src/unix/stream.c
src/unix/tcp.c
src/unix/thread.c
src/unix/tty.c
src/unix/udp.c
"

case "$TARGET_OS" in
  linux)
    files="
      $unix_files
      src/unix/linux.c
      src/unix/procfs-exepath.c
      src/unix/proctitle.c
      src/unix/random-getrandom.c
      src/unix/random-sysctl-linux.c
    "
    flags="-I./src/unix -D_GNU_SOURCE -DHAVE_DLFCN_H=1 -DHAVE_PTHREAD_PRIO_INHERIT=1"
    headers="
    $src/include/uv/linux.h
    $src/include/uv/unix.h
    "
    ;;
  macos)
    files="
      $unix_files
      src/unix/bsd-ifaddrs.c
      src/unix/darwin-proctitle.c
      src/unix/darwin.c
      src/unix/fsevents.c
      src/unix/kqueue.c
      src/unix/proctitle.c
      src/unix/random-getentropy.c
    "
    flags="-I./src/unix -D_DARWIN_USE_64_BIT_INODE=1 -D_DARWIN_UNLIMITED_SELECT=1 -DHAVE_DLFCN_H=1 -DHAVE_PTHREAD_PRIO_INHERIT=1"
    headers="
    $src/include/uv/darwin.h
    $src/include/uv/unix.h
    "
    ;;
esac

zig build-lib -target $TARGET -O $OPT \
  --name uv \
  -DPACKAGE_NAME="libuv" \
  -DPACKAGE_TARNAME="libuv" \
  -DPACKAGE_VERSION="1.48.0" \
  -DPACKAGE_STRING="libuv 1.48.0" \
  -DPACKAGE_BUGREPORT="https://github.com/libuv/libuv/issues" \
  -DPACKAGE_URL="" \
  -DPACKAGE="libuv" \
  -DVERSION="1.48.0" \
  -DSUPPORT_ATTRIBUTE_VISIBILITY_DEFAULT=1 \
  -DSUPPORT_FLAG_VISIBILITY=1 \
  -DHAVE_STDIO_H=1 \
  -DHAVE_STDLIB_H=1 \
  -DHAVE_STRING_H=1 \
  -DHAVE_INTTYPES_H=1 \
  -DHAVE_STDINT_H=1 \
  -DHAVE_STRINGS_H=1 \
  -DHAVE_SYS_STAT_H=1 \
  -DHAVE_SYS_TYPES_H=1 \
  -DHAVE_UNISTD_H=1 \
  -DSTDC_HEADERS=1 \
  $flags \
  -I./include -I./src \
  -lc \
  -cflags -std=gnu89 -- \
  src/*.c $files

cd "$BUILD_OUT"
mkdir -p lib include/uv pkgconfig zig
mv $src/libuv.a lib
cp $src/include/uv.h include
cp \
  $src/include/uv/version.h \
  $src/include/uv/threadpool.h \
  $src/include/uv/errno.h \
  $headers \
  include/uv
