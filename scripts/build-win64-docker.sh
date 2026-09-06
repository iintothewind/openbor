#!/usr/bin/env bash
# OpenBOR 6392 - Windows x64 交叉编译（在 Debian 容器内进行）
#
# 与 scripts/build-win-docker.sh（i686 / win32）互补：本脚本用
# x86_64-w64-mingw32-gcc 产出真正的 64 位 PE32+ OpenBOR-x64.exe。
#
# 第三方库（zlib / SDL2 / SDL2_gfx / libpng / libogg / libvorbis / libvpx）：
# 自带 tools/win-sdk 只有 32 位 .a，且 Debian 源无这些库的 x86_64 mingw 交叉版。
# 首选由 scripts/Dockerfile.win64 预先把它们交叉编好烘进镜像 sysroot
# （/opt/win64sysroot），pull 镜像即用；若 sysroot 不在（裸 debian 容器），下面
# 会调 scripts/xbuild-win64-libs.sh 现场交叉编一份兜底。两条路径共用同一份脚本
# 与同一批锁定版本，产物一致、可复现。
#
# Makefile 的 x86_64 交叉分支见 engine/Makefile Windows 段（由
# GCC_TARGET=x86_64-w64-mingw32 触发，关 -m32/MMX、上 -m64/AMD64）。
#
# 用法: bash scripts/build-win64-docker.sh
#   镜像内: docker run --rm -v "$PWD":/src -w /src obor-build-win64:6392 \
#             bash -c 'git config --global --add safe.directory /src && \
#                      bash scripts/build-win64-docker.sh'
#   产物: engine/OpenBOR.exe（64 位；与 win32 同名，由外层脚本改名区分）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRIP="x86_64-w64-mingw32"
# 默认与 scripts/Dockerfile.win64 预置的 sysroot 同路径：pull 该镜像即用，
# 下面的就绪判断成立 -> 不再现场重编第三方库。
SDK="${WINSDK:-/opt/win64sysroot}"

# 第三方库（zlib/SDL2/SDL2_gfx/libpng/libogg/libvorbis/libvpx）的版本锁定与
# 交叉编译方式收敛在 scripts/xbuild-win64-libs.sh —— 镜像构建与这里的兜底
# 共用同一份实现，避免版本/参数漂移。
XBUILD_LIBS="$REPO/scripts/xbuild-win64-libs.sh"

# OpenBOR 本体的交叉 env（第三方库由 xbuild-win64-libs.sh 自带一份）
export CC="$TRIP-gcc" CXX="$TRIP-g++" AR="$TRIP-ar" RANLIB="$TRIP-ranlib" \
       STRIP="$TRIP-strip" WINDRES="$TRIP-windres" NM="$TRIP-nm"

if [ ! -f "$SDK/lib/libSDL2.a" ] || [ ! -f "$SDK/lib/libvpx.a" ]; then
  echo ">> $SDK 无预置第三方库，现场交叉编译兜底"
  WINSDK="$SDK" bash "$XBUILD_LIBS"
  cd "$REPO"
fi

# 组装 OpenBOR 编译环境（与 build-win-docker.sh 对齐，仅换 x86_64 交叉链）
cd "$REPO/engine"

restore() {
  git -C "$REPO" checkout -- engine/Makefile engine/resources/Info.plist engine/resources/OpenBOR.res 2>/dev/null || true
  tracked_o="$(git -C "$REPO" ls-files '*.o')"
  [ -n "$tracked_o" ] && git -C "$REPO" checkout -- $tracked_o 2>/dev/null || true
}
trap restore EXIT

# 现代交叉 GCC 放宽：-Werror→-Wno-error + -fcommon（同 win32/linux）
sed -i 's/-Werror/-Wno-error/; s/\(-std=gnu99\)/\1 -fcommon/' Makefile
find . -name '*.o' -delete

# 重新生成 64 位资源文件：入库的 engine/resources/OpenBOR.res 是预编译 i386
# COFF（win32 交叉链专用），x86_64 链接器会因架构不符拒收。用交叉 windres 从
# 最小 .rc（内嵌同目录 .ico）现场编一份 PE32+ 版覆盖它（该文件被 git 跟踪，
# trap restore 会还原，不污染源码树）。
( cd resources
  printf '1 ICON "OpenBOR_Icon_32x32.ico"\n' > _win64.rc
  "${TRIP}-windres" --output-format=coff _win64.rc OpenBOR.res
  rm -f _win64.rc )

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
