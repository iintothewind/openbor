#!/usr/bin/env bash
# OpenBOR 6392 - 用 Docker 在 Linux(GCC 12) 里构建，宿主无需装依赖
# 用法: bash scripts/docker-build.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="obor-build:6392"

echo ">> 构建镜像 $IMAGE"
docker build -t "$IMAGE" -f "$REPO/scripts/Dockerfile" "$REPO/scripts"

echo ">> 容器内编译（挂载整仓库，容器里 build-linux.sh 会临时改再还原）"
# MSYS 下若从 Git-Bash 跑，docker -w 会被误转 Windows 路径，加 NO_PATHCONV
# 同一容器内先编 Linux 原生，再交叉编 Windows（装齐两套依赖）
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$REPO":/src -w /src \
  "$IMAGE" bash -c "bash scripts/build-linux.sh && bash scripts/build-win-docker.sh"

echo ">> 产物: $REPO/engine/OpenBOR (Linux), $REPO/engine/OpenBOR.exe (Windows)"
