#!/usr/bin/env bash
# OpenBOR 6392 - Windows 交叉编译（在 Docker 容器内进行）
# 用容器内 i686-w64-mingw32-gcc(GCC12) 交叉产出 OpenBOR.exe；
# 自带 tools/win-sdk/win-sdk.7z 仅作为 Windows 版第三方库/头(SDL2/png/vorbis/vpx)的来源，
# 在容器内解压到 /tmp/winsdk（不入库）。现代交叉 GCC 同样需放宽 -Werror + -fcommon。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${WINSDK:-/tmp/winsdk}"

# 1) 解压自带 win-sdk（Windows 版 .a 与头）
if [ ! -f "$SDK/lib/libSDL2.a" ]; then
  echo ">> 解压 tools/win-sdk/win-sdk.7z 到 $SDK"
  mkdir -p "$SDK"
  7z x "$REPO/tools/win-sdk/win-sdk.7z" -o"$SDK" -y >/dev/null
fi

# 1b) win-sdk 把 zlib 头/库存放在 mingw sysroot 子目录 (SDK/i686-w64-mingw32/{include,lib})，
#     而 Makefile Windows 段只搜 $(SDKPATH)/include 与 $(SDKPATH)/lib（且 LIBRARIES 经
#     addprefix -L"..." 展开，追加目录会退化成裸路径喂给 ld）。直接把它并入顶层这两个目录，
#     绕开搜索路径改动。cp -n 幂等，重复跑安全。
for f in zlib.h zconf.h; do
  [ -f "$SDK/i686-w64-mingw32/include/$f" ] && cp -n "$SDK/i686-w64-mingw32/include/$f" "$SDK/include/" || true
done
[ -f "$SDK/i686-w64-mingw32/lib/libz.a" ] && cp -n "$SDK/i686-w64-mingw32/lib/libz.a" "$SDK/lib/" || true

cd "$REPO/engine"

# 2) 交叉工具链：容器内 mingw-w64 i686（TARGET_ARCH=x86, OBJTYPE=win32）
export WINDEV="/usr/bin"
export PREFIX="i686-w64-mingw32-"
export EXTENSION=""
export SDKPATH="$SDK"
export GCC_TARGET="i686-w64-mingw32"
export TARGET_ARCH="x86"

restore() {
  git -C "$REPO" checkout -- engine/Makefile engine/resources/Info.plist 2>/dev/null || true
  tracked_o="$(git -C "$REPO" ls-files '*.o')"
  [ -n "$tracked_o" ] && git -C "$REPO" checkout -- $tracked_o 2>/dev/null || true
}
trap restore EXIT

# 3) 临时放宽现代交叉 GCC 的严格性（与 build-linux.sh 一致）：-Werror→-Wno-error + -fcommon
#    （zlib 头/库已在步骤 1b 并入顶层 include/lib，无需再改 Makefile 搜索路径）
sed -i 's/-Werror/-Wno-error/; s/\(-std=gnu99\)/\1 -fcommon/' Makefile
find . -name '*.o' -delete   # 清掉 Linux 段残留 .o（ELF/COFF 不能混），并含汇编 .o

make BUILD_WIN=1

echo ">> 完成: $(ls -la "$REPO/engine/OpenBOR.exe" 2>/dev/null || echo '未找到 engine/OpenBOR.exe')"
