#!/usr/bin/env bash
# OpenBOR 6392 - PSP + Vita 一键构建（官方预编译工具链镜像，宿主无需装任何 SDK）
# 与 scripts/docker-build.sh（Linux+Win，用自建 obor-build 镜像）互补：
# 掌机两平台用官方 PSPDev / Vitasdk 镜像交叉编译，产物统一导出到 OUT_DIR。
#
# 用法: bash scripts/docker-build-pspvita.sh [输出目录]   # 默认仓库外 temp
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-${OBOR_PSPVITA_OUT:-$HOME/obor-pspvita-build}}"
mkdir -p "$OUT_DIR"

echo ">> PSP 构建"
bash "$HERE/build-psp.sh"  "$OUT_DIR"
echo
echo ">> Vita 构建"
bash "$HERE/build-vita.sh" "$OUT_DIR"

echo
echo ">> 完成，产物目录: $OUT_DIR"
ls -la "$OUT_DIR"/EBOOT.PBP "$OUT_DIR"/OpenBOR.vpk 2>/dev/null || true
