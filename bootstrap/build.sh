#!/usr/bin/env sh

set -e

srcdir=$PWD/src
bootstrapdir=$PWD/bootstrap
depsdir=$PWD/deps
outdir=$bootstrapdir/build
supportdir=$outdir/support
scriptsdir=$supportdir/scripts
target=${TARGET:-"aarch64-macos"}
target_os=$(echo $target | cut -d'-' -f2)
opt=ReleaseSmall

tmp=$(mktemp -d)
cd $tmp
>&2 echo "bootstrapping xos for $target $opt"
>&2 echo "workdir=$tmp"
>&2 echo "outdir=$outdir"

rm -rf $outdir
mkdir $outdir
mkdir -p $scriptsdir

# Main launcher
zig build-exe -target $target -O $opt --name xos $srcdir/main.zig
mv xos $outdir

# Deps
mkdir -p libuv/xos
tar xf $depsdir/libuv/libuv-1.48.0.tar.gz -C libuv --strip-components=1
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/libuv \
BUILD_OUT=$PWD/libuv/xos \
  $bootstrapdir/build_uv.sh

mkdir -p wren/xos
cp -r $depsdir/wren/* wren/
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/wren \
BUILD_OUT=$PWD/wren/xos \
  $bootstrapdir/build_wren.sh

mkdir -p ucl/xos
tar xf $depsdir/ucl/ucl-0.9.2.tar.gz -C ucl --strip-components=1
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/ucl \
BUILD_OUT=$PWD/ucl/xos \
  $bootstrapdir/build_ucl.sh

mkdir -p lmdb/xos
tar xf $depsdir/lmdb/lmdb-0.9.31.tar.gz -C lmdb --strip-components=1
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/lmdb \
BUILD_OUT=$PWD/lmdb/xos \
  $bootstrapdir/build_lmdb.sh

mkdir -p libglob/xos
cp -r $depsdir/libglob/* libglob/
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/libglob \
BUILD_OUT=$PWD/libglob/xos \
  $bootstrapdir/build_glob.sh

# Wren CLI
mkdir -p wrencli/xos
cp -r $depsdir/wrencli/* wrencli/
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/wrencli \
BUILD_OUT=$PWD/wrencli/xos \
  $bootstrapdir/build_wrencli.sh
mv wrencli/xos/bin/wren $supportdir

# Scripts
scripts="
main.wren
"
for script in $scripts
do
ln -s $srcdir/$script $scriptsdir
done
ln -s $srcdir/wren_modules $scriptsdir

# Links
bbtools="
tar
wget
"
bb=$(which busybox)
for tool in $bbtools
do
  ln -s $bb $supportdir/$tool
done


# Identifying the xos build by its sources + zig version
src_files=$(find $srcdir -type f | sort)
deps_files=$(find $depsdir -type f | sort)
zig version > zigversion
xos_id=$(echo $src_files $deps_files zigversion | cat | sha256sum | cut -d' ' -f1)
printf $xos_id > $supportdir/xos_id

rm -rf $tmp
echo "xos=$outdir/xos"
>&2 echo ok
