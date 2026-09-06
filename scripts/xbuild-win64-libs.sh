#!/usr/bin/env bash
# OpenBOR 6392 - Windows x64 第三方库交叉编译（在 Debian 容器内进行）
#
# 从上游锁 tag 源码交叉编出 x86_64-w64-mingw32 静态版全套第三方库
# （zlib / SDL2 / SDL2_gfx / libpng / libogg / libvorbis / libvpx），
# 组装进一个 sysroot（默认 /opt/win64sysroot），供 engine/Makefile 的
# SDKPATH 使用。不碰 OpenBOR 源码，因此被两处复用：
#   1) scripts/Dockerfile.win64 在镜像构建时调用 -> 依赖预编译烘进镜像层，
#      CI/本地 pull 即用，免每次发布重编（这是它存在的主要原因）；
#   2) scripts/build-win64-docker.sh 在没有预置 sysroot 时现场调用兜底。
#
# 版本全部锁定保证可复现。Makefile 的 x86_64 交叉分支见 engine/Makefile
# Windows 段（由 GCC_TARGET=x86_64-w64-mingw32 触发，关 -m32/MMX、上 -m64/AMD64）。
#
# 用法: WINSDK=/opt/win64sysroot bash scripts/xbuild-win64-libs.sh
set -euo pipefail

TRIP="x86_64-w64-mingw32"
SDK="${WINSDK:-/opt/win64sysroot}"

# 上游锁定版本（可复现）
VER_ZLIB=v1.3.1
VER_SDL=release-2.30.12
COMMIT_SDLGFX=c4aca6b9700ec0db0abd316809e7e6038c511ce2
VER_LIBPNG=v1.6.44
VER_OGG=v1.3.5
VER_VORBIS=v1.3.7
VER_VPX=v1.14.1

# 交叉工具链 env
export CC="$TRIP-gcc" CXX="$TRIP-g++" AR="$TRIP-ar" RANLIB="$TRIP-ranlib" \
       STRIP="$TRIP-strip" WINDRES="$TRIP-windres" NM="$TRIP-nm"
export PKG_CONFIG_LIBDIR="$SDK/lib/pkgconfig"
# 交叉下各 autotools 库（libpng 找 zlib、vorbis 找 ogg）默认搜 host /usr/{include,lib}
# （那是 host ELF，交叉链不能用）。显式把 sysroot 加进 CPPFLAGS/LDFLAGS，
# 让它们命中先前装进 $SDK 的交叉 .a/.h。
export CPPFLAGS="-I$SDK/include"
export LDFLAGS="-L$SDK/lib"
MAKEJ="-j$(nproc 2>/dev/null || echo 4)"

echo ">> 交叉编译 64 位第三方库到 $SDK"
rm -rf "$SDK"; mkdir -p "$SDK"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cd "$BUILD"

# zlib（libpng/SDL 依赖）
git clone --depth 1 --branch "$VER_ZLIB" https://github.com/madler/zlib zlib
( cd zlib
  CHOST="$TRIP" ./configure --static --prefix="$SDK" >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null )
# zlib 的 configure 不产出 pkg-config 文件；libpng 靠 pkg-config 找 zlib，
# 手写一个 zlib.pc 进 sysroot（PKG_CONFIG_LIBDIR 已指向此处）。
mkdir -p "$SDK/lib/pkgconfig"
cat > "$SDK/lib/pkgconfig/zlib.pc" <<PCEOF
prefix=$SDK
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: ${VER_ZLIB#v}
Requires:
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
PCEOF

# SDL2（autotools，静态）。SDL 禁止在 git clone 目录内 in-tree 构建，
# 故在其内部建 build 目录做 out-of-tree 构建。
git clone --depth 1 --branch "$VER_SDL" https://github.com/libsdl-org/SDL sdl
( cd sdl
  ./autogen.sh >/dev/null 2>&1 || autoreconf -fi >/dev/null 2>&1
  mkdir -p build && cd build
  ../configure --host="$TRIP" --build="$(gcc -dumpmachine)" \
    --prefix="$SDK" --enable-static --disable-shared >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null )

# SDL2_gfx（仅 .c + 头，无 autotools，手写编译成 .a）。官方仓库无 tag，
# 锁 main 的 commit 保证可复现。依赖已装好的 SDL 头。
git clone https://github.com/ferzkopp/SDL2_gfx sdlgfx
( cd sdlgfx
  git checkout "$COMMIT_SDLGFX" >/dev/null 2>&1
  mkdir -p "$SDK/include/SDL2"
  cp SDL2_framerate.h SDL2_gfxPrimitives.h SDL2_imageFilter.h SDL2_rotozoom.h "$SDK/include/SDL2/"
  for c in SDL2_framerate SDL2_gfxPrimitives SDL2_imageFilter SDL2_rotozoom; do
    "$CC" -O2 -DGM_EH= -I"$SDK/include" -I"$SDK/include/SDL2" -c "$c.c" -o "$c.o"
  done
  "$AR" rcs "$SDK/lib/libSDL2_gfx.a" SDL2_framerate.o SDL2_gfxPrimitives.o SDL2_imageFilter.o SDL2_rotozoom.o )

# libpng
git clone --depth 1 --branch "$VER_LIBPNG" https://github.com/glennrp/libpng libpng
( cd libpng
  ./autogen.sh >/dev/null 2>&1 || autoreconf -fi >/dev/null 2>&1
  ./configure --host="$TRIP" --build="$(gcc -dumpmachine)" \
    --prefix="$SDK" --enable-static --disable-shared >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null )

# libogg
git clone --depth 1 --branch "$VER_OGG" https://github.com/xiph/ogg ogg
( cd ogg
  ./autogen.sh >/dev/null 2>&1 || autoreconf -fi >/dev/null 2>&1
  ./configure --host="$TRIP" --build="$(gcc -dumpmachine)" \
    --prefix="$SDK" --enable-static --disable-shared >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null )

# libvorbis
git clone --depth 1 --branch "$VER_VORBIS" https://github.com/xiph/vorbis vorbis
( cd vorbis
  ./autogen.sh >/dev/null 2>&1 || autoreconf -fi >/dev/null 2>&1
  ./configure --host="$TRIP" --build="$(gcc -dumpmachine)" \
    --prefix="$SDK" --enable-static --disable-shared >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null )

# libvpx（libvpx 自带 win64 交叉 target）
git clone --depth 1 --branch "$VER_VPX" https://github.com/webmproject/libvpx vpx
( cd vpx
  ./configure --target=x86_64-win64-gcc --prefix="$SDK" \
    --disable-shared --enable-static --disable-examples --disable-tools --disable-docs \
    --disable-unit-tests >/dev/null
  make $MAKEJ >/dev/null && make install >/dev/null
  # libvpx 装成 libvpx.a 或带版本号名，统一软链一份 libvpx.a 供 -lvpx
  [ -f "$SDK/lib/libvpx.a" ] || ln -sf "$(basename "$(find "$SDK/lib" -name 'libvpx*.a'|head -1)")" "$SDK/lib/libvpx.a" )

echo ">> 第三方库产出："
ls "$SDK"/lib/*.a
