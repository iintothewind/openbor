# OpenBOR 6392 Android 自包含构建镜像（重路线）
# 一次 docker build 联网装齐：JDK17 + Android SDK(platform-34/build-tools34) + NDK r26d + Gradle 8.7
# + 预置五库源码(SDL2/ogg/libpng/tremor/libvpx)。容器内 Linux 原生交叉编，vpx 不再需跨 MSYS 边界补丁。
# 之后 docker run 全离线复用镜像（仅产 APK 时按需连 Google Maven 拉 AGP 依赖，可缓存）。
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# --- 基础工具链（含 vpx 需要的 nasm/make/autoconf、tremor/ogg 需要的 make、file 校验）---
RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless unzip git curl ca-certificates cmake pkg-config \
      build-essential \
      make autoconf automake libtool nasm yasm python3 file xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Android commandline-tools + SDK 组件 + NDK r26d（build 时联网装）---
ENV CMDLINE_VER=11076708_latest
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" && cd /tmp \
    && curl -fsSLO "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VER}.zip" \
    && unzip -q "commandlinetools-linux-${CMDLINE_VER}.zip" -d "$ANDROID_HOME/cmdline-tools" \
    && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
    && rm "commandlinetools-linux-${CMDLINE_VER}.zip"
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
RUN yes | sdkmanager --licenses >/dev/null 2>&1 || true \
    && sdkmanager --install \
         "platform-tools" "platforms;android-34" "build-tools;34.0.0" \
    && rm -rf "$HOME/.android"

# --- NDK r26d：直接 curl 官方 zip（cmdline-tools 的 sdkmanager 索引查不到该包，改用官方直链）---
# 解压到 $ANDROID_HOME/ndk/26.3.10750924，目录名=版本号，供 00-env.sh sort -V 探测命中。
RUN mkdir -p "$ANDROID_HOME/ndk" && cd /tmp \
    && curl -fsSLO "https://dl.google.com/android/repository/android-ndk-r26d-linux.zip" \
    && unzip -q "android-ndk-r26d-linux.zip" \
    && mv android-ndk-r26d "$ANDROID_HOME/ndk/26.3.10750924" \
    && rm "android-ndk-r26d-linux.zip"

# --- Gradle 8.7（与 AGP 8.6 配套，官方 distribution 解压进镜像）---
ENV GRADLE_VER=8.7
RUN cd /opt && curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip" -o g.zip \
    && unzip -q g.zip && rm g.zip && mv "gradle-${GRADLE_VER}" /opt/gradle
ENV PATH="/opt/gradle/bin:$PATH"

# --- 预置第三方源码（固定 ref，容器内现编，离线可复现）---
# 落在 /opt/openbor-deps，驱动脚本启动时 seed 拷贝到 $OBOR_WORK，01-clone 检测到 .git 即跳过联网 clone。
# tremor 也在此内置：权威源 git.xiph.org 是 IPv6-only 域名，CI 容器无 IPv6 出口会 DNS 失败，
#   故改从 IPv4 可达的 GitHub mirror（sezero/tremor，fork 自 gitlab.xiph.org/xiph/tremor，
#   文件与官方一致）预置，令 CI 可完全离线 seed，不再依赖宿主注入。
ENV DEPS=/opt/openbor-deps
RUN mkdir -p "$DEPS" && cd "$DEPS" \
    && export GIT_TERMINAL_PROMPT=0 \
    && git clone --depth 1 --branch SDL2    https://github.com/libsdl-org/SDL.git   sdl2 \
    && git clone --depth 1                  https://github.com/xiph/ogg.git         ogg \
    && git clone --depth 1 --branch v1.6.44 https://github.com/glennrp/libpng.git   libpng \
    && git clone --depth 1                  https://github.com/sezero/tremor.git    tremor \
    && git clone --depth 1 --branch v1.14.1 https://github.com/webmproject/libvpx.git libvpx

WORKDIR /src
CMD ["bash"]
