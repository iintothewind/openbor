#!/usr/bin/env bash
# OpenBOR 6392 Android 自包含构建（Docker 重路线）
# 一条命令：建镜像 → 容器内 seed 预置源码 + 01→04 全编 → 产 APK。
# 用法: bash scripts/android/docker-build.sh
# 依赖宿主仅有 Docker，无需本地 NDK/SDK/Gradle/MSYS。
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE="obor-android:6392"
# 宿主工作卷：五库源码 seed、产物 .a/.so/.apk 都落这里（不入库），下次复用跳过。
WORK_VOL="${OBOR_WORK:-$HOME/obor-android-build}"
mkdir -p "$WORK_VOL"

# ---- tremor 预置（特殊）----
# tremor 权威源 git.xiph.org 是 IPv6-only 域名，多数 Docker 容器无 IPv6 出口会 DNS 失败，
# 故不进镜像 clone，改由宿主（可能可达，或复用已验证完好源）预置进工作卷。
# 优先 OBOR_TREMOR 指定的完好源目录；否则探测常见位置；都没有且容器也无 IPv6 时，
# 01-clone 会退回尝试 git.xiph.org 并在失败时给出清晰指引。
TREMOR_SEED=""
if [ -n "${OBOR_TREMOR:-}" ]; then TREMOR_SEED="$OBOR_TREMOR"; fi
if [ -z "$TREMOR_SEED" ]; then
  for c in "$WORK_VOL/tremor" \
           "$HOME/AppData/Local/Temp/obor_android/tremor" \
           "$HOME/obor-android-build/tremor"; do
    [ -f "$c/ivorbisfile.h" ] && { TREMOR_SEED="$c"; break; }
  done
fi

echo ">> [1/2] 构建镜像 $IMAGE（首次联网拉 JDK/SDK/NDK/Gradle/四库源码，之后 docker cache 命中秒级）"
docker build -t "$IMAGE" -f "$REPO/scripts/android/Dockerfile" "$REPO/scripts/android"

# tremor 落到工作卷（宿主侧，路径与容器内 /work 同盘符映射）
if [ ! -f "$WORK_VOL/tremor/ivorbisfile.h" ]; then
  if [ -n "$TREMOR_SEED" ] && [ "$TREMOR_SEED" != "$WORK_VOL/tremor" ]; then
    echo ">> 预置 tremor: $TREMOR_SEED -> $WORK_VOL/tremor"
    rm -rf "$WORK_VOL/tremor"          # 清掉可能遗留的空/残缺目录，避免 cp 拷成 tremor/tremor
    cp -a "$TREMOR_SEED" "$WORK_VOL/tremor"
  elif [ -z "$TREMOR_SEED" ]; then
    echo "!! 未找到可复用 tremor 源，将依赖容器内 01-clone 访问 git.xiph.org（需宿主容器有 IPv6 出口）。"
    echo "!! 若失败：设 OBOR_TREMOR=/path/to/完好/tremor 重跑（tremor 源域名 git.xiph.org 仅 IPv6）。"
  fi
fi

echo ">> [2/2] 容器内端到端构建（seed 四库 → 01-clone 跳过已存在 → 编库 → 重链 → APK）"
# MSYS_NO_PATHCONV 防 Git-Bash 路径误转（同 Linux 版 docker-build.sh）
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$REPO":/src \
  -v "$WORK_VOL":/work \
  -e OBOR_WORK=/work \
  -e ANDROID_HOME=/opt/android-sdk \
  -w /src \
  "$IMAGE" bash -c '
set -e
# ---- seed: 镜像预置四库源码 → 工作卷（01-clone 检测到 .git 存在则跳过联网） ----
DEPS=/opt/openbor-deps
for d in sdl2 ogg libpng libvpx; do
  [ -d "/work/$d/.git" ] || cp -a "$DEPS/$d" "/work/$d"
done
echo ">> seed 完成"

# ---- 按序构建 ----
bash scripts/android/01-clone.sh
bash scripts/android/02-build-deps.sh
bash scripts/android/03-build-native.sh
bash scripts/android/04-build-apk.sh

# ---- 验证产物 ----
APK=/work/apk/app/build/outputs/apk/debug/app-debug.apk
[ -f "$APK" ] || { echo "X APK 未找到"; exit 1; }
echo ">> 产物: $APK ($(stat -c%s "$APK") bytes)"
"$ANDROID_HOME/build-tools/34.0.0/aapt2" dump badging "$APK" 2>/dev/null \
  | grep -E "native-code|package: name"
echo ">> Android Docker 构建成功!"
'

echo ">> 产物保留在 $WORK_VOL/apk/app/build/outputs/apk/debug/app-debug.apk"
echo ">> 可 adb install -r 该 APK 到 arm64 设备验证运行。"
