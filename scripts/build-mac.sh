#!/usr/bin/env bash
# OpenBOR 6392 - macOS (Darwin) 构建
# 只能在真实 macOS 上运行：链接 Cocoa/AudioUnit/IOKit 需要 Apple SDK，
# Linux/Docker 无法交叉编译 macOS 产物（见 docs/BUILD.md 说明）。
# 目标 Apple Silicon arm64：clang 用 host 默认 arch，无需 -arch（已去 i386/MMX）。
# 依赖 Homebrew：sdl2(sdl2-compat) sdl2_gfx libvorbis libpng（libogg/libz 随之）。
# 全部 arm64 门控补丁（CC=clang、去 Carbon、-lSDL2main、-Wno-error 白名单、
# mac/malloc.h 兼容头、source/webmlib include、去 -freorder-blocks、
# -headerpad_max_install_names 移到链接期）均已固化进 engine/Makefile 与源码，
# 无需脚本 sed。编译在仓库外 temp 副本上进行，只把 OpenBOR.app 拷回 OUT_DIR，
# 不污染源码树。
#
# 用法: bash scripts/build-mac.sh [输出目录]   # 默认 $HOME/obor-mac-build
set -euo pipefail

[ "$(uname -s)" = "Darwin" ] || {
  echo "错误: macOS 构建只能在真实 macOS 上运行（当前 $(uname -s)）。" >&2
  echo "      Linux/Docker 无法交叉编译 macOS；请在 Apple Silicon Mac 上执行。" >&2
  exit 1
}

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${OBOR_MAC_OUT:-$HOME/obor-mac-build}}"
TMP="${OBOR_MAC_TMP:-$(mktemp -d "${TMPDIR:-/tmp}/openbor-mac.XXXXXX")}"
mkdir -p "$OUT_DIR"

command -v brew >/dev/null 2>&1 || {
  echo "错误: 需要 Homebrew。装法见 https://brew.sh" >&2
  exit 1
}
BREW_PREFIX="$(brew --prefix)"

echo ">> 安装/确认 Homebrew 依赖"
brew install sdl2 sdl2_gfx libvorbis libpng libogg >/dev/null

echo ">> 在 temp 副本 $TMP 上构建 macOS(arm64)，产物目录: $OUT_DIR"
cp -a "$REPO"/. "$TMP"/
(
  cd "$TMP/engine"
  find . -name '*.o' -delete
  export DWNDEV="$BREW_PREFIX"
  export SDKPATH="$(xcrun --show-sdk-path)"
  export PREFIX=
  export PATH="$BREW_PREFIX/bin:$PATH"
  make clean BUILD_DARWIN=1 >/dev/null 2>&1 || true
  make BUILD_DARWIN=1
)

# 组 .app bundle（对齐 engine/build.sh 的 darwin() 布局）
APP="$OUT_DIR/OpenBOR.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Libraries"
cp "$TMP/engine/OpenBOR"                 "$APP/Contents/MacOS/OpenBOR"
cp "$TMP/engine/resources/PkgInfo"        "$APP/Contents/PkgInfo"
cp "$TMP/engine/resources/Info.plist"     "$APP/Contents/Info.plist"
cp "$TMP/engine/resources/OpenBOR.icns"   "$APP/Contents/Resources/OpenBOR.icns"

# adhoc 签名（本机直接运行；非对外分发签名）
codesign --force --deep -s - "$APP" 2>/dev/null || true

rm -rf "$TMP"

echo ">> 完成: $APP"
echo "   运行: open \"$APP\"   （需自备游戏 pak，默认放 Contents/Resources/Paks/bor.pak）"
