# OpenBOR 6392 构建脚本

三平台可复现构建脚本。**原理、依赖细节与踩坑说明见 [`../docs/BUILD.md`](../docs/BUILD.md)**，本文只给用法。所有脚本参数化，构建产物与第三方源码一律落在仓库外，**绝不污染源码树**。

## 通用约定
- 工作目录 `OBOR_WORK`（放下载的源码/中间产物），默认 `$HOME/obor-android-build`，可用环境变量覆盖。
- 在 **Git-Bash（Windows）** 或 **Linux shell** 下运行；Windows 装 Android 依赖需额外备 **MSYS2**（编 libvpx 用 host gcc + POSIX make）。
- 目标 ABI 由 `OBOR_ABI` 控制，默认 `arm64-v8a`。

> **免重复 build**：三个自建构建镜像（`obor-build` / `obor-build-arm64` / `obor-android`）已发布为 ghcr 公开包，可直接 `docker pull` + `docker tag` 回本地名复用，脚本里的 `docker build` 即秒过。坐标与拉取/发布/踩坑见 [`../docs/BUILD.md` 第 8 节](../docs/BUILD.md)。

## Windows + Linux（Docker 一条命令）
两条都在同一容器内产出，宿主免装工具链（仅需 Docker）：
```bash
bash scripts/docker-build.sh          # 建镜像 → 容器内先编 Linux 原生，再交叉编 Windows
```
产物：
- `engine/OpenBOR`（ELF64 x86-64）
- `engine/OpenBOR.exe`（PE32 32-bit，用 `i686-w64-mingw32-gcc` 交叉编；win-sdk 仅提供 Windows 版第三方库/头）

> Windows 交叉编同样需放宽 `-Werror` + `-fcommon`（交叉是 GCC 12），与 Linux 段一致。

### Windows x64（64 位，`build-win64-docker.sh`）
产出真 64 位 `PE32+` exe。自带 `win-sdk` 只有 32 位第三方库、Debian 源也无这些库的 x86_64 mingw 交叉版，故本脚本在容器内**从上游锁定 tag 现场交叉编译**全套 64 位静态库（zlib / SDL2 / SDL2_gfx / libpng / libogg / libvorbis / libvpx），组装成 sysroot 再链出 exe：
```bash
# 需容器内有 gcc-mingw-w64-x86-64 等交叉链（见 .github/workflows/release.yml 的安装清单）
bash scripts/build-win64-docker.sh
```
- 产物：`engine/OpenBOR.exe`（PE32+ 64-bit），末尾用 `file` 校验必须是 `PE32+`。
- `engine/Makefile` 的 Windows 段已加 **x86_64 交叉门控**（`GCC_TARGET` 含 `x86_64` → `amd64`/`-m64`/`-DAMD64`/无 MMX；i686 与原生 win-sdk 不设 `GCC_TARGET`，保持 `x86`/`-m32`/MMX 不变）。见 [`../docs/BUILD.md`](../docs/BUILD.md) 第 9 节。

### 发布 CI（`.github/workflows/release.yml`）
在 GitHub **发布一个 Release** 时自动触发，**各平台独立 job**，一次产出并上传 **linux-x64 / linux-arm64 / win-x32 / win-x64 / psp / vita / macos-arm64** 七个平台产物到该 Release（Linux x64 用原生 runner 直接编，详见 [`../docs/BUILD.md`](../docs/BUILD.md) 第 9 节）。

### 原生 Windows（备用，未采用）
```bash
bash scripts/build-win.sh [已解压的 win-sdk 目录]
```
仓库自带 `tools/win-sdk/win-sdk.7z`（GCC 8.1.0）。**注意**：本机与归档都不含 `yasm.exe`（编 `*.asm` 必需），走原生需自备 `yasm` 并入 PATH；SDK 解压会依次探测 `7za`/`7z`/`7zz`/`bsdtar`/`tar`。GCC 8 无需放宽 `-Werror`/`-fcommon`。

## Linux（本机已有依赖时）
本机已装依赖（`build-essential` / `libsdl2-dev` / `libsdl2-gfx-dev` / `libpng-dev` / `zlib1g-dev` / `yasm` / `libvorbis-dev` / `libogg-dev` / `libvpx-dev`）时可直接：
```bash
bash scripts/build-linux.sh          # 自动临时放宽 -Werror + -fcommon，编完还原
```
产物：`engine/OpenBOR`（纯 Docker 见上一节 `docker-build.sh`）

## Linux arm64（aarch64，Docker + QEMU）
在 x86-64 宿主上产出真 `ELF aarch64`：Docker `--platform linux/arm64` 借 QEMU(`qemu-aarch64`) 模拟，在 arm64 容器内**原生编译**（复用现有 `Dockerfile`，apt 命中 `:arm64` 包，无需交叉工具链/交叉库）。宿主仅需 Docker：
```bash
bash scripts/build-linux-arm64.sh [输出目录]   # 默认 $HOME/obor-linux-arm64-build
```
产物：`<输出目录>/OpenBOR`（`ELF 64-bit LSB pie executable, ARM aarch64`），落仓库外，**不入库**。
- `Makefile` 的 Linux 段已加 **aarch64 优先门控**（`aarch64-linux-gnu` 含子串 `64`，会被原 `findstring 64` 误判成 amd64 塞 x86 专有 `-m64`/yasm）。arm64 分支不设 `-m64`/`-DAMD64`/MMX，库走 Debian multiarch `$(SDKPATH)/lib/aarch64-linux-gnu`。见 [`../docs/BUILD.md`](../docs/BUILD.md) 第 2 节。
- 脚本会自动注册 `qemu-aarch64` binfmt（幂等）。QEMU 模拟执行较慢，请耐心。

## Android（Docker 自包含镜像，推荐 / 最省心）
镜像 `obor-android:6392` 已烘齐 JDK17 + Android SDK(platform-34/build-tools34) + NDK r26d + Gradle 8.7 + 第三方源码，宿主仅需 Docker，**无需本地装 NDK/SDK/Gradle/MSYS2**：
```bash
bash scripts/android/docker-build.sh   # 建镜像(首次联网拉齐) → 容器内 01→04 → 产 APK
```
产物：`$OBOR_WORK/apk/app/build/outputs/apk/debug/app-debug.apk`（默认 `$HOME/obor-android-build`，不入库）。
- 容器内 Linux 原生交叉编 libvpx，**不再需要 Windows 的 MSYS2 跨边界那一套**。
- 特例：**tremor** 权威源 `git.xiph.org` 仅 IPv6，容器无 IPv6 出口会失败，脚本改从宿主已验证源 seed（可用 `OBOR_TREMOR=/path/to/tremor` 指定）。

### 原生路线（本机已备全套工具链时）
前置：
- `NDK` 指向 NDK r26d 根目录（或放 `$ANDROID_HOME/ndk` 下自动探测）
- `ANDROID_HOME` / `ANDROID_SDK_ROOT` 指向 Android SDK（含 platforms + build-tools）
- 本机 `PATH` 有 `cmake`；`gradle` 在 PATH 或放 `$OBOR_WORK` 下
- Windows：装 MSYS2（提供 `bash.exe`），编 libvpx 时会调用

按序执行：
```bash
export NDK=/path/to/android-ndk-r26d
export ANDROID_HOME=/path/to/Android/Sdk
export OBOR_WORK=/path/to/work            # 可选，默认 $HOME/obor-android-build

bash scripts/android/01-clone.sh          # 克隆 SDL2/ogg/libpng/tremor/libvpx
bash scripts/android/02-build-deps.sh     # 交叉编 SDL2.so + ogg/png/tremor/vpx .a
bash scripts/android/03-build-native.sh   # 重链 libopenbor.so
bash scripts/android/04-build-apk.sh      # 组 Gradle 工程 + 打 debug APK
```
产物：`$OBOR_WORK/apk/app/build/outputs/apk/debug/app-debug.apk`

安装：`adb install -r <上面那个 apk>`

### 关键设计（为什么这么编）
- **tremor**：源码只有 `configure.ac` 且老 autotools 生成的 configure 有语法错误 → `02` 里手写 `config.h` + 直接 NDK clang 编源文件（注入端序宏）。
- **libvpx**：静态库需位置无关 → `--enable-pic`；且须用 **MSYS POSIX make**（NDK 自带 make.exe 解析不了路径）。
- **libmain.so**：`04` 把 `libopenbor.so` 改名 `libmain.so`，配合 SDL2 2.33 官方 Java（`getLibraries()={"SDL2","main"}`、`getMainFunction()="SDL_main"`）→ 零 Java 定制、JNI 完全配套。

## PSP + Vita（官方工具链镜像，宿主零 SDK）
掌机两平台用官方预编译交叉工具链镜像，宿主仅需 Docker（与 Linux/Win 的自建 `obor-build`、Android 的自建 `obor-android` 互补）：
```bash
bash scripts/docker-build-pspvita.sh [输出目录]   # 串编 PSP + Vita，默认输出 $HOME/obor-pspvita-build
# 或单独：
bash scripts/build-psp.sh   [输出目录]            # pspdev/pspdev:latest   → EBOOT.PBP
bash scripts/build-vita.sh  [输出目录]            # vitasdk/vitasdk:latest → OpenBOR.vpk
```
产物：`EBOOT.PBP`（PSP，魔数 `00 50 42 50`）、`OpenBOR.vpk`（Vita，魔数 `50 4b 03 04`），落在仓库外 temp，**不入库**。
- 现代工具链（两镜像内嵌 GCC 15）对 2014 代码的放宽与符号映射已固化进 `engine/Makefile` 的 `ifdef BUILD_PSP/BUILD_VITA` 段与 `psp/`、`vita/` 源码，脚本本身不再 sed。原理与踩坑见 [`../docs/BUILD.md`](../docs/BUILD.md) 第 4 节。
- 注意 Vita 镜像仓库名是 `vitasdk/vitasdk`（不是 `vitasdk/toolchain`）。
- 产物为掌机格式，本机不能运行验证；PSP 可 PPSSPP 加载（需另投游戏 `.pak`）。

## macOS（Darwin / Apple Silicon arm64，须真机）
**macOS 无法进 Docker**：链接 Cocoa/AudioUnit/IOKit 需 Apple SDK，只能在真实 macOS（Apple Silicon Mac 或 `macos-14` CI runner）上编。在 Mac 上跑：
```bash
bash scripts/build-mac.sh [输出目录]   # 自动 brew 装依赖，temp 副本上编，组 OpenBOR.app，默认 $HOME/obor-mac-build
```
产物：`OpenBOR.app`（`Contents/MacOS/OpenBOR` = Mach-O 64-bit executable arm64，adhoc 签名），落仓库外 temp，**不入库**。
- 依赖 Homebrew：`sdl2`(现为 `sdl2-compat`，提供 `libSDL2`/`libSDL2main`，无旧 `libSDLmain`) `sdl2_gfx` `libvorbis` `libpng` `libogg`。
- Apple clang 21 比 GCC15 更严；arm64 门控改造（去 Carbon/`-arch i386`/MMX、`-lSDL2main`、`-Wno-error` 白名单、`mac/malloc.h` 兼容头等）已固化进 `engine/Makefile` 的 `ifdef BUILD_DARWIN` 段与 `source/utils.c`、`engine/mac/malloc.h`，脚本不再 sed。原理与踩坑见 [`../docs/BUILD.md`](../docs/BUILD.md) 第 5 节。

## 目录结构
```
scripts/
  build-win.sh  build-win-docker.sh  build-win64-docker.sh  build-linux.sh  build-linux-arm64.sh  docker-build.sh  Dockerfile  README.md
  build-psp.sh  build-vita.sh  docker-build-pspvita.sh   # PSP/Vita（官方工具链镜像）
  build-mac.sh                                          # macOS（须在真实 Apple Silicon Mac 上跑）
  android/
    00-env.sh            # 公共环境（被 01~04 source）
    01-clone.sh  02-build-deps.sh  03-build-native.sh  04-build-apk.sh
    gradle/              # AGP 工程骨架（manifest + build.gradle，被 04 拷用）
```
