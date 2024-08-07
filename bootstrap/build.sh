#!/usr/bin/env sh

set -ex

get_host() {
  case $(uname -m) in
    x86_64)
      arch=x86_64
      ;;
    arm64|aarch64)
      arch=aarch64
      ;;
    *)
      >&2 echo "unsupported arch"
      exit 1
      ;;
  esac
  case $(uname -o) in
    *Linux)
      os=linux
      abi=musl
      ;;
    Darwin)
      os=macos
      abi=none
      ;;
    *)
      >&2 echo "unsupported os"
      exit 1
      ;;
  esac
  echo $arch-$os-$abi
}

host=${HOST:-$(get_host)}
target=${TARGET:-$host}
target_os=$(echo $target | cut -d'-' -f2)
opt=ReleaseSmall

rootdir=${XOS_BOOTSTRAP_ROOT:-$PWD}
srcdir=$rootdir/src
depsdir=$rootdir/deps
bootstrapdir=$rootdir/bootstrap

builddir=$bootstrapdir/build
outdir=$builddir/out
tmpdir=$builddir/tmp
toolsdir=$tmpdir/tools
supportdir=$outdir/support

if [ "$XOS_BOOTSTRAP" != "1" ]
then
  rm -rf $builddir
  mkdir -p $tmpdir
  mkdir -p $toolsdir

  cd $tmpdir

  mkdir -p busybox/xos
  tar xf $bootstrapdir/busybox.tar.gz -C busybox --strip-components=1
  TARGET=$target \
  SRCDIR=$PWD/busybox \
  BUILD_OUT=$PWD/busybox/xos \
    $bootstrapdir/fetch_busybox.sh

  bb="$PWD/busybox/xos/bin/busybox"
  tools="
  sh
  cut
  rm
  mkdir
  tar
  cp
  mv
  ln
  date
  "

  for tool in $tools
  do
    ln -s $bb $toolsdir/$tool
  done

  if [ "$(zig version)" != "0.12.0" ]
  then
    >&2 echo "zig must be v0.12.0"
    exit 1
  fi

  zig=$(which zig)
  ln -s $zig $toolsdir/zig

  exec env -i \
    XOS_BOOTSTRAP=1 \
    XOS_BOOTSTRAP_ROOT=$rootdir \
    PATH="$toolsdir" \
    HOST="$host" \
    TARGET="$target" \
    HOME="$HOME" \
    $bootstrapdir/build.sh "$@"
fi

>&2 echo "bootstrapping xos for $target $opt"
>&2 echo "workdir=$tmpdir"
>&2 echo "outdir=$outdir"

mkdir -p $outdir
mkdir -p $supportdir/bin

# Deps
cp busybox/xos/bin/busybox $supportdir/bin

mkdir -p libuv/xos
tar xf $depsdir/libuv/libuv-1.48.0.tar.gz -C libuv --strip-components=1
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/libuv \
BUILD_OUT=$PWD/libuv/xos \
  $bootstrapdir/build_uv.sh

mkdir -p wren/xos
cp -r $depsdir/wren/* wren/
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/wren \
BUILD_OUT=$PWD/wren/xos \
  $bootstrapdir/build_wren.sh

mkdir -p ucl/xos
tar xf $depsdir/ucl/ucl-0.9.2.tar.gz -C ucl --strip-components=1
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/ucl \
BUILD_OUT=$PWD/ucl/xos \
  $bootstrapdir/build_ucl.sh

mkdir -p lmdb/xos
tar xf $depsdir/lmdb/lmdb-0.9.31.tar.gz -C lmdb --strip-components=1
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/lmdb \
BUILD_OUT=$PWD/lmdb/xos \
  $bootstrapdir/build_lmdb.sh

mkdir -p libglob/xos
cp -r $depsdir/libglob/* libglob/
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/libglob \
BUILD_OUT=$PWD/libglob/xos \
  $bootstrapdir/build_glob.sh

# Wren CLI
mkdir -p wrencli/xos
cp -r $depsdir/wrencli/* wrencli/
HOST=$host \
TARGET=$target \
TARGET_OS=$target_os \
OPT=$opt \
SRCDIR=$PWD/wrencli \
BUILD_OUT=$PWD/wrencli/xos \
  $bootstrapdir/build_wrencli.sh
mv wrencli/xos/bin/wren $supportdir/bin

# Main launcher
zig build-exe -target $target -O $opt --name xos \
  $srcdir/main.zig \
  -lc
mv xos $outdir

# Scripts
ln -s $srcdir/wren_modules $supportdir
ln -s $srcdir/main.wren $supportdir

# Links
bbtools="
tar
wget
"
for tool in $bbtools
do
  ln -s busybox $supportdir/bin/$tool
done

# Identify a bootstrap build by timestamp
echo -n "Bootstrap $(date)" > $supportdir/xos_id
echo "" > $supportdir/bootstrap


if [ "$1" = "full" ]
then
  cd $rootdir

  # Build xos with bootstrap
  # TODO: Double runs because sometimes the first one fails???
  LOG=0 $outdir/xos build --opt=Small :xos
  LOG=0 $outdir/xos build --opt=Small :xos

  # Build xos with xos built by bootstrap
  mv xos-out $tmpdir/xos1
  LOG=0 $tmpdir/xos1/xos build --opt=Small :xos
  LOG=0 $tmpdir/xos1/xos build --opt=Small :xos

  # Build xos with xos built by xos
  mv xos-out $tmpdir/xos2
  LOG=0 $tmpdir/xos2/xos build --opt=Small :xos
  LOG=0 $tmpdir/xos2/xos build --opt=Small :xos

  mv $tmpdir/xos1 $builddir/
  mv $tmpdir/xos2 $builddir/
  >&2 echo "xos1=$builddir/xos1"
  >&2 echo "xos2=$builddir/xos2"
fi

rm -rf $tmpdir
echo "xos=$outdir/xos"
>&2 echo ok
