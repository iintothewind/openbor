#!/usr/bin/env bash
# OpenBOR 6392 - PSP 构建（官方 PSPDev 镜像，宿主无需装 PSPSDK）
# 用 pspdev/pspdev:latest 内 psp-gcc(GCC15) 交叉产出 EBOOT.PBP。
# 现代交叉工具链对 2014 移植代码的严格性放宽与符号映射已固化进 engine/Makefile
# 的 ifdef BUILD_PSP 段与 psp/*.c，无需在脚本里 sed（详见 docs/BUILD.md）。
# 编译在容器内 /work 副本上进行，只把最终 EBOOT.PBP 拷回 OUT_DIR，不污染源码树。
#
# 用法: bash scripts/build-psp.sh [输出目录]   # 默认输出到仓库外 temp
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${OBOR_PSP_IMAGE:-pspdev/pspdev:latest}"
OUT_DIR="${1:-${OBOR_PSP_OUT:-$HOME/obor-psp-build}}"
mkdir -p "$OUT_DIR"

echo ">> 用镜像 $IMAGE 构建 PSP，产物目录: $OUT_DIR"
# MSYS/Git-Bash 下 docker -v/-w 路径会被误转成 Windows 路径，禁之
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$REPO":/src:ro -v "$OUT_DIR":/out \
  "$IMAGE" bash -c '
    set -e
    export PATH=/usr/local/pspdev/bin:$PATH
    export PSPSDK="$(psp-config --pspsdk-path)"
    cp -a /src /work && cd /work/engine
    find . -name "*.o" -delete
    make BUILD_PSP=1 PSPSDK="$PSPSDK"
    cp -f EBOOT.PBP /out/EBOOT.PBP
  '

echo ">> 完成: $OUT_DIR/EBOOT.PBP"
