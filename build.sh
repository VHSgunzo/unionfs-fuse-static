#!/bin/bash
set -e
HERE="$(dirname "$(readlink -f "$0")")"
cd "$HERE"

WITH_UPX=1
VENDOR_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"
export MAKEFLAGS="-j$(nproc)"

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
        exit 1
fi

if [ -x "$(which apt 2>/dev/null)" ]
    then
        export DEBIAN_PRIORITY=critical
        export DEBIAN_FRONTEND=noninteractive
        apt update && apt install --yes --quiet \
            --option Dpkg::Options::=--force-confold --option Dpkg::Options::=--force-confdef \
            build-essential clang pkg-config git fuse3 po4a meson ninja-build cmake \
            libfuse3-dev autoconf libtool upx wget autopoint
fi

if [ "$WITH_UPX" == 1 ]
    then
        if [[ "$VENDOR_UPX" == 1 || ! -x "$(which upx 2>/dev/null)" ]]
            then
                upx_ver=4.2.4
                case "$platform_arch" in
                   x86_64) upx_arch=amd64 ;;
                   aarch64) upx_arch=arm64 ;;
                esac
                wget https://github.com/upx/upx/releases/download/v${upx_ver}/upx-${upx_ver}-${upx_arch}_linux.tar.xz
                tar xvf upx-${upx_ver}-${upx_arch}_linux.tar.xz
                mv upx-${upx_ver}-${upx_arch}_linux/upx /usr/bin/
                rm -rf upx-${upx_ver}-${upx_arch}_linux*
        fi
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

# if [ -d release ]
#     then
#         echo "= removing previous release directory"
#         rm -rf release
# fi

echo "=  create build and release directory"
mkdir -p build
mkdir -p release

(cd build

export CFLAGS="$CFLAGS -Os -g0 -ffunction-sections -fdata-sections -fvisibility=hidden -fmerge-all-constants"
export LDFLAGS="$LDFLAGS -Wl,--gc-sections -Wl,--strip-all"

echo "= build static deps"
(export CC=gcc

[ -d "/usr/lib/$platform_arch-linux-gnu" ] && \
    libdir="/usr/lib/$platform_arch-linux-gnu/"||\
    libdir="/usr/lib/"

echo "= build fuse lib"
(git clone https://github.com/libfuse/libfuse.git && cd libfuse
git checkout fuse-3.16.2
mkdir build && cd build
export CC=clang
meson setup .. --default-library=static
ninja
mv -fv lib/libfuse3.a $libdir))

echo "= download unionfs-fuse"
git clone https://github.com/rpodgorny/unionfs-fuse.git
unionfs_fuse_version="$(cd unionfs-fuse && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
unionfs_fuse_dir="${HERE}/build/unionfs-fuse-${unionfs_fuse_version}"
mv "unionfs-fuse" "${unionfs_fuse_dir}"
echo "= unionfs-fuse v${unionfs_fuse_version}"

echo "= build unionfs-fuse"
(cd "${unionfs_fuse_dir}"
export CC=gcc
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
make DESTDIR="${unionfs_fuse_dir}/install" install)

echo "= extracting unionfs-fuse binaries and libraries"
for bin in "${unionfs_fuse_dir}"/install/usr/local/bin/*
    do [[ ! -L "$bin" && -f "$bin" ]] && \
        mv -fv "$bin" "${HERE}"/release/"$(basename "${bin}")-${platform_arch}"
done)

echo "= build super-strip"
(cd build && git clone https://github.com/aunali1/super-strip.git && cd super-strip
make
mv -fv sstrip /usr/bin/)

echo "= super-strip release binaries"
sstrip release/*-"${platform_arch}"

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        find release -name "*-${platform_arch}"|\
        xargs -I {} upx --force-overwrite -9 --best {} -o {}-upx
fi

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rfv build
fi

echo "= unionfs-fuse done"
