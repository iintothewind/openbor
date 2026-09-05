#!/usr/bin/env bash
# OpenBOR 6392 - Vita(PSV) 构建（官方 Vitasdk 镜像，宿主无需装 Vitasdk）
# 用 vitasdk/vitasdk:latest 内 arm-vita-eabi-gcc(GCC15) 交叉产出 OpenBOR.vpk。
# 严格性放宽、符号映射与 Vita LIBS 修正(去 -lSceKernel_stub、补 -lSceAppMgr_stub)
# 均已固化进 engine/Makefile 的 ifdef BUILD_VITA 段与 vita/video.c，无需脚本 sed。
# 编译在容器内 /work 副本上进行，只把最终 OpenBOR.vpk 拷回 OUT_DIR，不污染源码树。
#
# 用法: bash scripts/build-vita.sh [输出目录]   # 默认输出到仓库外 temp
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${OBOR_VITA_IMAGE:-vitasdk/vitasdk:latest}"
OUT_DIR="${1:-${OBOR_VITA_OUT:-$HOME/obor-vita-build}}"
mkdir -p "$OUT_DIR"

echo ">> 用镜像 $IMAGE 构建 Vita，产物目录: $OUT_DIR"
# MSYS/Git-Bash 下 docker -v/-w 路径会被误转成 Windows 路径，禁之
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$REPO":/src:ro -v "$OUT_DIR":/out \
  "$IMAGE" bash -c '
    set -e
    export PATH=/usr/local/vitasdk/bin:$PATH
    cp -a /src /work && cd /work/engine
    find . -name "*.o" -delete
    make BUILD_VITA=1
    cp -f OpenBOR.vpk /out/OpenBOR.vpk
  '

echo ">> 完成: $OUT_DIR/OpenBOR.vpk"
