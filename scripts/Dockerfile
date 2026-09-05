# OpenBOR 6392 - Linux 构建镜像（Debian bookworm, GCC 12）
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git pkg-config \
      libsdl2-dev libsdl2-gfx-dev libpng-dev zlib1g-dev yasm \
      libvorbis-dev libogg-dev libvpx-dev \
      gcc-mingw-w64-i686 p7zip-full \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
