#!/usr/bin/env bash
# OpenBOR 6392 Android 构建 - 公共环境。被 01~04 脚本 source。
# 所有路径参数化，可用环境变量覆盖：
#   OBOR_WORK   工作目录(放下载的源码/中间产物)，默认 $HOME/obor-android-build
#   NDK         NDK 根(需含 ndk-build)，默认探测 $ANDROID_HOME/ndk/最新 或 $HOME 下 r26d
#   ANDROID_HOME/ANDROID_SDK_ROOT  Android SDK
#   OBOR_ABI    目标 ABI，默认 arm64-v8a
set -euo pipefail

_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$_ENV_DIR" rev-parse --show-toplevel)"
ENG="$REPO/engine"
WORK="${OBOR_WORK:-$HOME/obor-android-build}"
ABI="${OBOR_ABI:-arm64-v8a}"
API=21

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WIN=1 ;;
  *)                    WIN=0 ;;
esac
# 给 NDK ndk-build 用的路径：Windows 要 C:/ 风格(cygpath -w)，Linux 原样
topath() { if [ "$WIN" = 1 ]; then cygpath -w "$1"; else echo "$1"; fi; }

# --- NDK ---
if [ -z "${NDK:-}" ]; then
  if [ -d "${ANDROID_HOME:-}/ndk" ]; then
    NDK="$(ls -1 "${ANDROID_HOME}/ndk" | sort -V | tail -1)"; NDK="${ANDROID_HOME}/ndk/$NDK"
  else
    # 找含 ndk-build(.cmd) 的目录，避免误匹配同名 .zip
    for d in $(find "$WORK" "$HOME" -maxdepth 1 -type d -name 'android-ndk-*' 2>/dev/null | sort -V); do
      [ -f "$d/ndk-build" ] || [ -f "$d/ndk-build.cmd" ] && NDK="$d"
    done
  fi
fi
[ -n "${NDK:-}" ] || { echo "X 找不到 NDK，请设 NDK 环境变量指向 NDK 根目录"; exit 1; }
LLVM="$NDK/toolchains/llvm/prebuilt/$( [ "$WIN" = 1 ] && echo windows-x86_64 || echo linux-x86_64 )/bin"
[ "$ABI" = arm64-v8a ] && TRIPLE=aarch64-linux-android
[ "$ABI" = armeabi-v7a ] && TRIPLE=armv7a-linux-androideabi
CC="$LLVM/${TRIPLE}${API}-clang"; CXX="$LLVM/${TRIPLE}${API}-clang++"
AR="$LLVM/llvm-ar"; RANLIB="$LLVM/llvm-ranlib"; NM="$LLVM/llvm-nm"
NDB="$NDK/ndk-build$( [ "$WIN" = 1 ] && echo .cmd || true )"
NDKMAKE="$NDK/prebuilt/$( [ "$WIN" = 1 ] && echo windows-x86_64 || echo linux-x86_64 )/bin/make$( [ "$WIN" = 1 ] && echo .exe || true )"

# --- MSYS2（仅 Windows，编 vpx/tremor 需要 host gcc + POSIX make） ---
MSYS="${XMSYS:-}"
if [ "$WIN" = 1 ] && [ -z "$MSYS" ]; then
  MSYS="$(find "$WORK" "$HOME" /c/tools -maxdepth 4 -path '*/usr/bin/bash.exe' 2>/dev/null | grep -i msys | head -1)"
fi

echo ">> 环境: WIN=$WIN ABI=$ABI"
echo "   REPO=$REPO"; echo "   WORK=$WORK"; echo "   NDK=$NDK"
[ -n "$MSYS" ] && echo "   MSYS=$MSYS"
mkdir -p "$WORK"

# ---- 供 02 脚本传给 MSYS 子进程(Windows)的变量(均为 POSIX 风格 /c/... 路径) ----
export XWORK="$WORK"; [ "$WIN" = 1 ] && XWORK="$(cygpath -u "$WORK")"
export XLLVM="$LLVM"; [ "$WIN" = 1 ] && XLLVM="$(cygpath -u "$LLVM")"
export XTRIPLE="$TRIPLE" XAPI="$API" XABI="$ABI" XWIN="$WIN" XMSYS="$MSYS"
