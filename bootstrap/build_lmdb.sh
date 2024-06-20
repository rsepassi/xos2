#!/usr/bin/env sh
# https://github.com/LMDB/lmdb/archive/refs/tags/LMDB_0.9.31.tar.gz
# dd70a8c67807b3b8532b3e987b0a4e998962ecc28643e1af5ec77696b081c9b0

set -e

src=$SRCDIR/libraries/liblmdb
cd $src

zig build-lib -target $TARGET -O $OPT \
  --name lmdb \
  mdb.c midl.c -lc

cd $BUILD_OUT
mkdir lib include
cp $src/lmdb.h include
cp $src/liblmdb.a lib
