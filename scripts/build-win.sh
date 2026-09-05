#!/usr/bin/env bash
# OpenBOR 6392 - Windows 构建（原生 Git-Bash + 仓库自带 win-sdk）
# 用法: bash scripts/build-win.sh [SDK解压目录]
#   默认把 SDK 解压到 ../obor_winsdk（仓库外）
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"
SDK="${1:-$REPO/../obor_winsdk}"
SDK="$(cygpath -u "$SDK" 2>/dev/null || echo "$SDK")"

# 1) 解压自带 SDK（GCC 8.1.0 + Make 4.2.1 + SDL2）
# 解压器自动探测：不同环境 7z 可执行名各异，且 Git-Bash 里未必在 PATH。
# 依次试 7za / 7z / 7zz，再退回 bsdtar（libarchive 支持 7z）。全缺则清晰报错。
extract_7z() {
  local archive="$1" dest="$2"
  local awin; awin="$(cygpath -w "$dest" 2>/dev/null || echo "$dest")"
  if command -v 7za  >/dev/null 2>&1; then 7za  x "$archive" -o"$awin" -y
  elif command -v 7z >/dev/null 2>&1; then 7z   x "$archive" -o"$awin" -y
  elif command -v 7zz >/dev/null 2>&1; then 7zz  x "$archive" -o"$awin" -y
  elif command -v bsdtar >/dev/null 2>&1; then bsdtar -xf "$archive" -C "$dest"
  elif command -v tar  >/dev/null 2>&1 && tar -xf "$archive" -C "$dest" 2>/dev/null; then :
  else
    echo "错误: 找不到可解压 7z 的工具 (7za/7z/7zz/bsdtar/tar)。" >&2
    echo "请安装 7-Zip 并加入 PATH，或手动解压后以第 2 个参数传入已解压目录:" >&2
    echo "  bash scripts/build-win.sh <已含 bin/mingw32-make.exe 的目录>" >&2
    exit 1
  fi
}
if [ ! -x "$SDK/bin/mingw32-make.exe" ]; then
  echo ">> 解压 tools/win-sdk/win-sdk.7z 到 $SDK"
  mkdir -p "$SDK"
  extract_7z tools/win-sdk/win-sdk.7z "$SDK"
fi

# 2) 配置环境（与仓库 environ.sh 约定一致）
export SDKPATH="$SDK"
export WINDEV="$SDKPATH/bin"
export EXTENSION=".exe"
export PREFIX=""
export PATH="$SDKPATH/bin:$REPO/tools/bin:$PATH"

# 3) 编译（GCC 8 无 -fno-common/新告警，-Werror 原样通过，无需改源码）
# Makefile 在 engine/，产物 engine/OpenBOR.exe（与 Linux 产物 engine/OpenBOR 对称）
cd "$REPO/engine"
"$SDKPATH/bin/mingw32-make.exe" BUILD_WIN=1

echo ">> 完成: $(ls -la "$REPO/engine/OpenBOR.exe" 2>/dev/null || echo '未找到 engine/OpenBOR.exe')"
