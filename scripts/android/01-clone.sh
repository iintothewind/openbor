#!/usr/bin/env bash
# OpenBOR 6392 Android - 克隆构建所需第三方源码到 $WORK
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-env.sh"

clone() { # clone <url> <目录名> [分支/tag]
  local url="$1" dir="$2" ref="${3:-}"
  if [ -d "$WORK/$dir/.git" ]; then echo ">> 已存在: $dir"; return; fi
  echo ">> 克隆 $dir"; git clone --depth 1 ${ref:+--branch "$ref"} "$url" "$WORK/$dir"
}

clone https://github.com/libsdl-org/SDL.git        sdl2    SDL2
clone https://github.com/xiph/ogg.git              ogg
clone https://github.com/glennrp/libpng.git     libpng  v1.6.44
clone https://git.xiph.org/tremor.git              tremor
clone https://github.com/webmproject/libvpx.git    libvpx  v1.14.1

echo ">> 源码就绪于 $WORK"; ls -d "$WORK"/{sdl2,ogg,libpng,tremor,libvpx} 2>/dev/null
