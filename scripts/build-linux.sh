#!/usr/bin/env bash
# OpenBOR 6392 - Linux 构建（现代 GCC，需放宽 -Werror + 加 -fcommon）
# 现代工具链两处必改（详见 docs/BUILD.md 第 2/0.3 节）：
#   1) engine/Makefile:446 的 -Werror 放宽为 -Wno-error
#   2) openbor.h 裸定义全局变量 -> 需 -fcommon，否则 multiple definition
# 本脚本用临时补丁实现，编完自动 git checkout 还原，不污染源码树。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO/engine"

export LNXDEV="${LNXDEV:-/usr/bin}"
export PREFIX="${PREFIX:-}"
export SDKPATH="${SDKPATH:-/usr}"
export GCC_TARGET="${GCC_TARGET:-$(gcc -dumpmachine)}"
export TARGET_ARCH="${TARGET_ARCH:-amd64}"

# 统一还原函数：Makefile + 可能被 make version 覆盖的 Info.plist
# + 被 find -delete 误删的 git 跟踪 .o（如 engine/sdl/gp2x/modules/mmuhack.o）
restore() {
  git -C "$REPO" checkout -- engine/Makefile engine/resources/Info.plist 2>/dev/null || true
  tracked_o="$(git -C "$REPO" ls-files '*.o')"
  # 路径无空格，故意不加引号以按行分词
  [ -n "$tracked_o" ] && git -C "$REPO" checkout -- $tracked_o 2>/dev/null || true
}
trap restore EXIT

# 临时放宽：-Werror -> -Wno-error，并给主 CFLAGS 追加 -fcommon
sed -i 's/-Werror/-Wno-error/; s/\(-std=gnu99\)/\1 -fcommon/' Makefile

# 强制清 .o：增量复用旧 .o 会绕过 -fcommon 导致链接失败（务必）
# 注意别误删被 git 跟踪的 gp2x .o，编完一并还原
find . -name '*.o' -delete

make BUILD_LINUX=1

echo ">> 完成: $(ls -la OpenBOR 2>/dev/null || echo '未找到 OpenBOR')"
