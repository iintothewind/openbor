#!/usr/bin/env bash
# OpenBOR 6392 - Windows x64 交叉编译（在 Debian 容器内进行）
#
# 与 scripts/build-win-docker.sh（i686 / win32）互补：本脚本用
# x86_64-w64-mingw32-gcc 产出真正的 64 位 PE32+ OpenBOR-x64.exe。
#
# 第三方库来源：自带 tools/win-sdk 只有 32 位 .a，且 Debian 源无这些库的
# x86_64 mingw 交叉版，故本脚本在容器内从上游 tag 源码现场交叉编译出全套
# 64 位静态库（zlib / SDL2 / SDL2_gfx / libpng / libogg / libvorbis / libvpx），
# 组装成 /tmp/win64sysroot 后作为 SDKPATH 喂给 engine/Makefile。完全可复现，
# 不依赖任何外部零散预编译包。
#
# 版本全部锁定，保证可复现；Makefile 的 x86_64 交叉分支见 engine/Makefile
# Windows 段（由 GCC_TARGET=x86_64-w64-mingw32 触发，关 -m32/MMX、上 -m64/AMD64）。
#
# 用法: bash scripts/build-win64-docker.sh
#   产物: engine/OpenBOR.exe（64 位；与 win32 同名，由外层脚本改名区分）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRIP="x86_64-w64-mingw32"
SDK="${WINSDK:-/tmp/win64sysroot}"

# 上游锁定版本（可复现）
VER_ZLIB=v1.3.1
VER_SDL=release-2.30.12
VER_SDLGFX=2.0.26
VER_LIBPNG=v1.6.44
VER_OGG=v1.3.5
VER_VORBIS=v1.3.7
VER_VPX=v1.14.1

# 交叉工具链 env
export CC="$TRIP-gcc" CXX="$TRIP-g++" AR="$TRIP-ar" RANLIB="$TRIP-ranlib" \
       STRIP="$TRIP-strip" WINDRES="$TRIP-windres" NM="$TRIP-nm"
export PKG_CONFIG_LIBDIR="$SDK/lib/pkgconfig"
MAKEJ="-j$(nproc 2>/dev/null || echo 4)"

if [ ! -f "$SDK/lib/libSDL2.a" ] || [ ! -f "$SDK/lib/libvpx.a" ]; then
  echo ">> 现场交叉编译 64 位第三方库到 $SDK"
  rm -rf "$SDK"; mkdir -p "$SDK"
  BUILD=$(mktemp -d)
  cd "$BUILD"

  # zlib（libpng/SDL 依赖）
  git clone --depth 1 --branch "$VER_ZLIB" https://github.com/madler/zlib zlib
  ( cd zlib
    CHOST="$TRIP" ./configure --static --prefix="$SDK" >/dev/null
    make $MAKEJ >/dev/null && make install >/dev/null )

  # SDL2（autotools，静态）
  git clone --depth 1 --branch "$VER_SDL" https://github.com/libsdl-org/SDL sdl
  ( cd sdl
    ./autogen.sh >/dev/null 2>&1 || autoreconf -fi >/dev/null 2>&1
    ./configure --host="$TRIP" --build="$(gcc -dumpmachine)" \
      --prefix="$SDK" --enable-static --disable-shared >/dev/null
    make $MAKEJ >/dev/null && make install >/dev/null )

  # SDL2_gfx（仅 .c + Makefile.minimal，手写编译成 .a）
  git clone --depth 1 --branch "$VER_SDLGFX" https://github.com/scottschiller/SDL2_gfx sdlgfx
  ( cd sdlgfx
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
      --disable-shared --enable-static --disable-examples --disable-tools --disable-docs >/dev/null
    make $MAKEJ >/dev/null && make install >/dev/null
    # libvpx 装成 libvpx.a 或带版本号名，统一软链一份 libvpx.a 供 -lvpx
    [ -f "$SDK/lib/libvpx.a" ] || ln -sf "$(basename "$(find "$SDK/lib" -name 'libvpx*.a'|head -1)")" "$SDK/lib/libvpx.a" )

  echo ">> 第三方库产出："
  ls "$SDK"/lib/*.a
fi

# 组装 OpenBOR 编译环境（与 build-win-docker.sh 对齐，仅换 x86_64 交叉链）
cd "$REPO/engine"

restore() {
  git -C "$REPO" checkout -- engine/Makefile engine/resources/Info.plist 2>/dev/null || true
  tracked_o="$(git -C "$REPO" ls-files '*.o')"
  [ -n "$tracked_o" ] && git -C "$REPO" checkout -- $tracked_o 2>/dev/null || true
}
trap restore EXIT

# 现代交叉 GCC 放宽：-Werror→-Wno-error + -fcommon（同 win32/linux）
sed -i 's/-Werror/-Wno-error/; s/\(-std=gnu99\)/\1 -fcommon/' Makefile
find . -name '*.o' -delete

export WINDEV="/usr/bin"
export PREFIX="${TRIP}-"
export EXTENSION=""
export SDKPATH="$SDK"
export GCC_TARGET="$TRIP"
export TARGET_ARCH="amd64"

make BUILD_WIN=1

# 校验：产物必须是 PE32+（64 位），否则视为失败
if command -v file >/dev/null 2>&1; then
  file "$REPO/engine/OpenBOR.exe" | grep -q "PE32+" \
    || { echo "!! 产物不是 PE32+（64位）：$(file "$REPO/engine/OpenBOR.exe")" >&2; exit 1; }
fi

echo ">> 完成(64位): $(ls -la "$REPO/engine/OpenBOR.exe")"
