#!/usr/bin/env bash
# OpenBOR 6392 - Linux arm64 (aarch64) 构建
#
# 路线：Docker --platform linux/arm64 + QEMU(qemu-aarch64) 模拟，在 arm64 容器内
#       原生编译产出真 ELF aarch64。复用现有 scripts/Dockerfile（依赖清单无硬编码
#       架构，apt 会命中 :arm64 包），无需交叉工具链与交叉版第三方库。
# 前提：Makefile Linux 段已加 aarch64 优先门控（否则 aarch64-linux-gnu 被
#       findstring '64' 误判成 amd64，塞进 x86 专有 -m64/yasm）。见 docs/BUILD.md。
#
# 用法: bash scripts/build-linux-arm64.sh [输出目录]
#   产物: <输出目录>/OpenBOR  （默认 $HOME/obor-linux-arm64-build）
# 说明: 挂载整仓库进容器、由 build-linux.sh 原地编译（其 trap 会 git checkout 还原
#       Makefile 等临时补丁）；产物抽取到输出目录后清掉源码树残留，树保持干净。
#       QEMU 模拟较慢，请耐心。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="obor-build-arm64:6392"
OUT_DIR="${1:-$HOME/obor-linux-arm64-build}"

# 1) 确保 arm64 binfmt/QEMU 已注册（幂等；Docker Desktop 通常自带）
if ! docker run --rm --platform linux/arm64 debian:bookworm-slim true >/dev/null 2>&1; then
  echo ">> 注册 qemu-aarch64 binfmt 模拟器"
  docker run --privileged --rm tonistiigi/binfmt --install arm64 >/dev/null
fi

# 2) 构建 arm64 构建镜像（与 amd64 共用 scripts/Dockerfile，仅 --platform 不同）
echo ">> 构建 arm64 镜像 $IMAGE（QEMU 模拟下 apt 装依赖，较慢）"
docker build --platform linux/arm64 -t "$IMAGE" -f "$REPO/scripts/Dockerfile" "$REPO/scripts"

# 3) 挂载整仓库，arm64 容器内原生编译（build-linux.sh 会临时改 Makefile 再 git checkout 还原）
echo ">> arm64 容器内原生编译（QEMU 模拟，较慢）"
MSYS_NO_PATHCONV=1 docker run --rm --platform linux/arm64 \
  -v "$REPO":/src -w /src "$IMAGE" bash scripts/build-linux.sh

# 4) 抽出产物到 OUT_DIR，并清掉源码树里的编译残留，保持树干净
mkdir -p "$OUT_DIR"
cp -f "$REPO/engine/OpenBOR" "$OUT_DIR/OpenBOR"
chmod +x "$OUT_DIR/OpenBOR" 2>/dev/null || true
rm -f "$REPO/engine/OpenBOR" "$REPO/engine/OpenBOR.elf"

# 5) 验证产物架构：ELF header e_machine 偏移 18、2 字节小端 = 183 => EM_AARCH64
echo ">> 完成: $OUT_DIR/OpenBOR"
MSYS_NO_PATHCONV=1 docker run --rm --platform linux/arm64 \
  -v "$OUT_DIR":/out -w /out "$IMAGE" \
  sh -c 'printf "e_machine(小端字节) = "; od -An -tu1 -j18 -N2 OpenBOR' 2>/dev/null || true
echo "   (e_machine=183 => EM_AARCH64，即真 arm64 ELF；x86-64=62、i386=3)"
