#!/usr/bin/env sh

set -ex

get_target() {
  case $(uname -m) in
    x86_64)
      arch=x86_64
      ;;
    arm64)
      arch=aarch64
      ;;
    *)
      >&2 echo "unsupported arch"
      exit 1
      ;;
  esac
  case $(uname -o) in
    Linux)
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

target=${TARGET:-"$(get_target)"}
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

  export XOS_BOOTSTRAP=1
  export XOS_BOOTSTRAP_ROOT=$rootdir
  export PATH="$toolsdir"
  export TARGET="$target"
  exec $bootstrapdir/build.sh "$@"
fi

>&2 echo "bootstrapping xos for $target $opt"
>&2 echo "workdir=$tmpdir"
>&2 echo "outdir=$outdir"

mkdir -p $outdir
mkdir -p $supportdir

# Deps
cp busybox/xos/bin/busybox $supportdir

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

# Main launcher
zig build-exe -target $target -O $opt --name xos \
  -Iwrencli/xos/include \
  -Iwren/xos/include \
  $srcdir/main.zig \
  wrencli/xos/lib/libwrencli.a \
  wrencli/xos/lib/libxos.a \
  libuv/xos/lib/libuv.a \
  wren/xos/lib/libwren.a \
  lmdb/xos/lib/liblmdb.a \
  ucl/xos/lib/libucl.a \
  libglob/xos/lib/libglob.a \
  -lc
mv xos $outdir

# Scripts
ln -s $srcdir/wren_modules $supportdir

# Links
bbtools="
tar
wget
"
for tool in $bbtools
do
  ln -s busybox $supportdir/$tool
done

# Identify a bootstrap build by timestamp
echo -n "Bootstrap $(date)" > $supportdir/xos_id
echo "" > $supportdir/bootstrap


if [ "$1" = "full" ]
then
  cd $rootdir
  mkdir -p .xos-cache
  rm -rf .xos-cache/label
  rm -rf .xos-cache/tools

  # Build xos with bootstrap
  LOG=0 $outdir/xos build --opt=Small :xos

  # Build xos with xos built by bootstrap
  mv xos-out $tmpdir/xos1
  LOG=0 $tmpdir/xos1/xos build --opt=Small :xos

  # Build xos with xos built by xos
  mv xos-out $tmpdir/xos2
  LOG=0 $tmpdir/xos2/xos build --opt=Small :xos

  mv $tmpdir/xos1 $builddir/
  mv $tmpdir/xos2 $builddir/
  >&2 echo "xos1=$builddir/xos1"
  >&2 echo "xos2=$builddir/xos2"
fi

rm -rf $tmpdir
echo "xos=$outdir/xos"
>&2 echo ok
