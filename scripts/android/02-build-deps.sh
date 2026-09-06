#!/usr/bin/env bash
# OpenBOR 6392 Android - 交叉编译全部第三方库为 $ABI
# 产物：$WORK/out/{libSDL2.so,libogg.a,libpng.a,libvorbisidec.a,libvpx.a} + $WORK/inc/tremor
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-env.sh"
OUT="$WORK/out"; INC="$WORK/inc"; mkdir -p "$OUT" "$INC/tremor"

# ---------- SDL2（源码根 Android.mk 直接编 shared libSDL2.so）----------
# 注意：入口必须是 SDL 源码根的 Android.mk（LOCAL_MODULE := SDL2），
# 不是 android-project 里的示例 app（那个只有 main 模块、依赖未定义的 SDL2 -> undefined modules）。
echo ">>>>>> SDL2"
"$NDB" NDK_PROJECT_PATH="$(topath "$WORK/sdl2")" \
  APP_BUILD_SCRIPT="$(topath "$WORK/sdl2/Android.mk")" \
  NDK_OUT="$(topath "$WORK/sdl_out/obj")" NDK_LIBS_OUT="$(topath "$WORK/sdl_out/libs")" \
  APP_PLATFORM="android-$API" APP_ABI="$ABI"
cp "$WORK/sdl_out/libs/$ABI/libSDL2.so" "$OUT/"

# ---------- libogg / libpng（NDK CMake，static）----------
echo ">>>>>> ogg + png (CMake)"
command -v cmake >/dev/null || { echo "X 需要 cmake"; exit 1; }
TOOL="$NDK/build/cmake/android.toolchain.cmake"
cmake -G "Unix Makefiles" -DCMAKE_MAKE_PROGRAM="$(topath "$NDKMAKE")" \
  -DCMAKE_TOOLCHAIN_FILE="$(topath "$TOOL")" -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="android-$API" -DBUILD_SHARED_LIBS=OFF \
  -S "$(topath "$WORK/ogg")" -B "$(topath "$WORK/ogg-build")" >/dev/null
cmake --build "$(topath "$WORK/ogg-build")" -j4; cp "$WORK/ogg-build"/*.a "$OUT/"
cmake -G "Unix Makefiles" -DCMAKE_MAKE_PROGRAM="$(topath "$NDKMAKE")" \
  -DCMAKE_TOOLCHAIN_FILE="$(topath "$TOOL")" -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="android-$API" -DBUILD_SHARED_LIBS=OFF \
  -DPNG_STATIC=ON -DPNG_SHARED=OFF -DPNG_TESTS=OFF \
  -S "$(topath "$WORK/libpng")" -B "$(topath "$WORK/libpng-build")" >/dev/null
cmake --build "$(topath "$WORK/libpng-build")" -j4; cp "$WORK/libpng-build"/libpng*.a "$OUT/"

# tremor 需 ogg 头(含构建生成的 config_types.h)；缺失按 .in 手写
OGGH="$WORK/ogg/include/ogg"
[ -f "$OGGH/config_types.h" ] || sed \
  -e 's/@INCLUDE_[A-Z_]*@/1/g' \
  -e 's/@SIZE16@/int16_t/;s/@USIZE16@/uint16_t/' \
  -e 's/@SIZE32@/int32_t/;s/@USIZE32@/uint32_t/' \
  -e 's/@SIZE64@/int64_t/;s/@USIZE64@/uint64_t/' \
  "$OGGH/config_types.h.in" > "$OGGH/config_types.h"

# ---------- tremor / vorbisidec（本 shell 直接用 NDK clang，无需 MSYS）----------
echo ">>>>>> tremor (NDK clang)"
cp "$WORK/tremor/ivorbisfile.h" "$WORK/tremor/ivorbiscodec.h" "$INC/tremor/"
O="$WORK/tremor-arm64"; rm -rf "$O"; mkdir -p "$O"
cat > "$O/config.h" <<'CFG'
#define LITTLE_ENDIAN 1234
#define BIG_ENDIAN    4321
#define BYTE_ORDER    LITTLE_ENDIAN
#define HAVE_ALLOCA 1
#define HAVE_ALLOCA_H 1
#define HAVE_DLFCN_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define STDC_HEADERS 1
#define PACKAGE "vorbisidec"
#define VERSION "1.2.1"
CFG
# HAVE_CONFIG_H 必需：sezero/tremor 的 os.h 用 #ifdef HAVE_CONFIG_H 守卫 include "config.h"，
# 缺它则 config.h 里的 HAVE_ALLOCA 不被识别，os.h 直接 #error。官方 tremor 结构不同不需要。
CF="-O2 -fPIC -fcommon -DHAVE_CONFIG_H -DUSE_MEMORY_H -DBYTE_ORDER=1234 -DLITTLE_ENDIAN=1234 -DBIG_ENDIAN=4321 -I$O -I$WORK/tremor -I$WORK/ogg/include"
for f in mdct block window synthesis info floor1 floor0 vorbisfile res012 mapping0 registry codebook sharedbook; do
  "$CC" $CF -c "$WORK/tremor/$f.c" -o "$O/$f.o"
done
"$AR" rcs "$O/libvorbisidec.a" "$O"/*.o
cp "$O/libvorbisidec.a" "$OUT/"

# ---------- libvpx（需 host gcc + POSIX make -> Windows 走 MSYS）----------
echo ">>>>>> libvpx"
# 跨 Git-Bash<->MSYS2 边界既不能靠 mktemp 的 /tmp(两边 /tmp 不互通)，也不能靠 env 传参
# (MSYS bash -c 起的子 shell 丢外层 env)。故把脚本写到 $WORK 下(两环境同盘符路径)，
# 生成时把绝对路径直接 echo 成字面量写入，执行不再依赖任何外部变量。
VPXSH="$WORK/vpxbuild.sh"
# Windows 下从 $MSYS(=.../msys64/usr/bin/bash.exe) 反推 msys 的 usr/bin 绝对 POSIX 路径,
# 写进生成脚本 PATH; 否则从 Git-Bash 起 MSYS 子 bash 时裸 /usr/bin 会误解析到 Git 的 usr/bin(无 make)。
if [ "$WIN" = 1 ]; then MSBIN="$(cygpath -u "$(dirname "$MSYS")")"; else MSBIN="/usr/bin"; fi
{
  echo "set -e"
  echo "cd '$XWORK/libvpx'"
  echo "git clean -xfd >/dev/null 2>&1 || true"
  # 规整临时目录: 从 Git-Bash 起 MSYS 子 bash 会带入宿主 TEMP/TMPDIR(Win 路径),
  # libvpx 的 configure 在其下建 .c 又读不回 -> Unable to invoke compiler。
  echo "export TMPDIR=/tmp TMP=/tmp TEMP=/tmp"
  echo "export PATH='$XLLVM:$MSBIN:\$PATH'"
  echo "export CC='$XLLVM/${XTRIPLE}${XAPI}-clang'"
  echo "export CXX='$XLLVM/${XTRIPLE}${XAPI}-clang++'"
  echo "export AR='$XLLVM/llvm-ar'; export RANLIB='$XLLVM/llvm-ranlib'"
  echo "./configure --target=arm64-android-gcc --enable-static --disable-shared --enable-pic \\"
  echo "  --disable-examples --disable-unit-tests --disable-tools --disable-docs --disable-libyuv >/tmp/vpxcfg.log 2>&1"
  echo "make -j4 >/tmp/vpxmake.log 2>&1 || { tail -15 /tmp/vpxmake.log; exit 1; }"
  echo "cp libvpx.a '$XWORK/out/'"
  echo "echo libvpx OK"
} > "$VPXSH"
if [ "$WIN" = 1 ]; then
  [ -n "$MSYS" ] || { echo "X Windows 编 libvpx 需 MSYS2(含 gcc/make)，设 XMSYS 或装 MSYS2"; exit 1; }
  # 用 env -i 起干净 MSYS 子 shell: 甩开 Git-Bash 传入的 PATH/TEMP/TMPDIR 污染。
  # 否则绝对 /usr/bin 与 /tmp 会解析到 Git 的同名目录, 导致 libvpx configure
  # 写临时 .c 到 msys /tmp 却用 Git 的 cat 读不到 -> Unable to invoke compiler。
  # PATH 给 msys 原生 usr/bin(含 git/make/cat)+纯 /usr/bin:/bin, 保证路径解析自洽。
  env -i MSYSTEM=MINGW64 HOME="$MSBIN" TMPDIR=/tmp TMP=/tmp TEMP=/tmp \
    PATH="$MSBIN:/usr/bin:/bin" \
    "$MSYS" -c "bash '$(cygpath -u "$VPXSH")'"
else
  bash "$VPXSH"
fi
rm -f "$VPXSH"

echo ">>>>>> 全部第三方库完成:"; ls -la "$OUT"
