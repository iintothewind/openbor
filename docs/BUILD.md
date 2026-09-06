# OpenBOR 6392 构建指南（Windows / Linux / arm64 / Android / PSP / Vita / macOS）

> **懒人入口**：四个自建构建镜像已发布为 ghcr 公开包，可**直接 `docker pull` 复用、免从零 build**——坐标与拉取方式见 [第 8 节](#8-构建镜像发布到-ghcr免重复-build可直接拉取)。

本文记录 OpenBOR `6392` 分支（基于 `v6391`）在多个平台上**可复现**的构建方法：依赖、步骤、以及实际踩过的坑与解法。所有命令均在 `Windows / Git-Bash` 环境实测通过。

> 适用版本线：`6392` 分支沿用 **旧构建体系**（`engine/Makefile` + `engine/build.sh` + `engine/environ.sh`），不是 master 的 CMake 工程。

---

## 0. 通用背景

### 0.1 版本号机制
- `engine/version.sh` 用 `git rev-list --count HEAD` 生成 `VERSION_BUILD`，写入 `engine/version.h` / `version.tmp`。
- `v6391` = commit `494708eb...`，`git rev-list --count v6391` = 6391；`6392` 从同一 commit 切出。

### 0.2 铁律：产物不入库
- 所有**构建产物、第三方库、临时脚本、克隆源码**一律放仓库外（本文档示例用 `C:\Users\ivarc\AppData\Local\Temp\obor_android`、`obor_winsdk`）。
- 若为编译临时修改了仓库内文件（如放宽 `-Werror`、误覆盖 `Info.plist`、误删跟踪的 `.o`），编完必须 `git checkout -- <file>` 还原，保持 `git status` 干净。
- 例外：本文档 `BUILD.md` 作为知识沉淀，由维护者主动选择入库。

### 0.3 现代工具链的两个共性改造（Linux / Android 通用）
`6391` 是 2014 年代代码，现代 GCC/Clang 默认严格度会编译失败，需两处放宽：
1. **`-Werror` → `-Wno-error`**：源码里有 `strcpy`/`sprintf`/`strncpy`/指针比较等告警，老工具链不报、新工具链报成 error。
2. **加 `-fcommon`**：`openbor.h` 里裸定义全局变量（`s_anim_list *anim_list;` @1909、`s_modelcache *model_cache;` @2245），现代 GCC 默认 `-fno-common` 会 `multiple definition` 链接失败。
> 采用 **Docker 交叉编译** Windows（`i686-w64-mingw32-gcc`，GCC 12）时，这两项放宽与 Linux 段一致，`build-win-docker.sh` 会自动处理。仅当走**原生** `build-win.sh`（仓库自带 GCC 8.1.0）时无需放宽。
>
> **掌机两平台（PSP / Vita）更严**：官方 PSPDev / Vitasdk 镜像内嵌的是 **GCC 15**（比 Linux/Win 的 GCC 12 新得多），2014 代码在其下会命中更多**硬 error**（`implicit-function-declaration`/`int-conversion` 等在 GCC14+ 默认升级为 error）。这些改造已固化进 `engine/Makefile` 的 `ifdef BUILD_PSP` / `ifdef BUILD_VITA` 段与 `psp/`、`vita/` 专有源码，详见第 4 节；**Linux/Win 不受影响**（块被 `ifdef` 门控）。

---

## 1. Windows（Docker 内交叉编译，与 Linux 同容器）

最终采用 **Docker 交叉编译**：在同一镜像里装齐两套依赖，用 `i686-w64-mingw32-gcc`（GCC 12）交叉产出 `OpenBOR.exe`，宿主机**无需**装 win-sdk / yasm。脚本：`scripts/build-win-docker.sh`，由 `scripts/docker-build.sh` 与 Linux 段串联执行。

### 1.1 依赖（全部在容器内，见 `scripts/Dockerfile`）
- `gcc-mingw-w64-i686`：交叉编译器 + windres（提供 `i686-w64-mingw32-gcc`）
- `p7zip-full`（`7z`）：容器内解压自带 win-sdk
- `yasm`：编 `source/gfxlib/*.asm`（`OBJTYPE=win32 -m x86`）
- 仓库自带 `tools/win-sdk/win-sdk.7z` **仅作为 Windows 版第三方库/头的来源**（`libSDL2.a`、`libSDL2_gfx.a`、`libogg.a`、`libpng.a`、`libvorbis*.a`、`libvpx.a` 及 `include/`），不再用它里面的 Windows 版 gcc。

### 1.2 步骤
```bash
# 一条命令同时编 Linux + Windows（容器内先 Linux 原生，再交叉编 Windows）
bash scripts/docker-build.sh
```
`build-win-docker.sh` 内部要点：
- 解压 win-sdk 到容器内临时目录（`WINSDK`，默认 `/tmp/winsdk`，可挂载复用）；
- 交叉工具链：`WINDEV=/usr/bin`、`PREFIX=i686-w64-mingw32-`、`EXTENSION=`、`SDKPATH=$WINSDK`、`TARGET_ARCH=x86`；
- 同 Linux 一样临时放宽：`-Werror`→`-Wno-error` + `-fcommon`，并 `find . -name '*.o' -delete`（清掉 Linux 段残留 `.o`，ELF/COFF 不能混）；
- `make BUILD_WIN=1` → 产物在 **`engine/OpenBOR.exe`**（Makefile 在 `engine/`，与 Linux 的 `engine/OpenBOR` 对称）。

### 1.3 产物
- `engine/OpenBOR.exe`（PE32 GUI 32-bit i386，约 3.6 MB）

### 1.4 踩坑（本轮端到端实测暴露）
1. **win-sdk 只给库不给交叉编译器、且不含 `yasm`**：归档顶层 `lib/` 有全套 Windows 版 `.a`，但 `bin/` 里无 `yasm`、`tools/bin` 也没有；`2xSaImmx.asm` 等需要汇编器。→ 交叉编译统一由容器提供 `yasm` + mingw-w64，win-sdk 只贡献库/头。
2. **win-sdk 的 `png.h` 找不到 `zlib.h`、链接缺 `-lz`**：zlib 的头/库被放在归档的 `i686-w64-mingw32/{include,lib}` 子目录，而 Makefile Windows 段只搜 `$(SDKPATH)/include` 与 `$(SDKPATH)/lib`。且 `LIBRARIES` 经 `$(addprefix -L",...)` 展开，**直接往 `LIBRARIES` 追加目录会退化成裸路径喂给 ld**（`file format not recognized`）。→ 脚本在解压后把 `zlib.h`/`zconf.h`/`libz.a` `cp` 并入 win-sdk 顶层的 `include/`、`lib/`，绕开搜索路径改动。
3. **产物路径**：`make` 必须在 `engine/` 下跑（Makefile 只在那），产物落 `engine/OpenBOR.exe`；早期脚本在仓库根跑 → `No makefile found`。
4. 交叉 GCC 是 GCC 12，和 Linux 段一样需要 `-Wno-error` + `-fcommon`（与旧文档"Windows 无需放宽"不同——那条只对原生 GCC 8 成立）。

> 附注（**未采用**）：原生 Git-Bash + 自带 win-sdk 路线因本机/归档都没有 `yasm.exe` 而无法开箱即用；若要走原生需自备 `yasm` 并入 PATH，且用 `7za`/`7z`/`bsdtar` 之一解压 SDK。`scripts/build-win.sh` 保留为原生路线脚本（含解压器自动探测），但主验证以 Docker 交叉为准。

---

## 2. Linux（Docker 交叉验证）

### 2.1 依赖（全部在容器内，见 `scripts/Dockerfile`）
- Docker（本例用 `debian:bookworm-slim`，**GCC 12**）
- 镜像内装：`build-essential`、`libsdl2-dev`、**`libsdl2-gfx-dev`**（提供 `SDL2_framerate.h` 等）、`libpng-dev`、`zlib1g-dev`、`yasm`、**`libvorbis-dev libogg-dev libvpx-dev`**（`soundmix.c` 走 `#else` 分支要 `vorbis/vorbisfile.h`，链接要 `-lvorbisfile -lvorbis -logg -lvpx`）。

### 2.2 步骤
```bash
# 一条命令：建镜像 + 容器内先编 Linux 原生、再交叉编 Windows
bash scripts/docker-build.sh
```
`build-linux.sh` 内部要点：`LNXDEV=/usr/bin`、`SDKPATH=/usr`、`GCC_TARGET=$(gcc -dumpmachine)`、`TARGET_ARCH=amd64`；临时把 `engine/Makefile` 的 `-Werror`→`-Wno-error` 并追加 `-fcommon`（见 0.3），`find . -name '*.o' -delete` 清 `.o`，`make BUILD_LINUX=1`；退出时 `trap` 统一 `git checkout` 还原 Makefile、`Info.plist` 与被误删的跟踪 `.o`。

### 2.3 产物
- `OpenBOR`（ELF64 x86-64，约 1.4 MB）

### 2.4 踩坑
1. **`cc1: all warnings treated as errors`** → `-Werror` 改 `-Wno-error`。
2. **`multiple definition of anim_list / model_cache`** → 加 `-fcommon`；**并且必须删净 `.o` 重编**——否则增量编译复用旧的未加 `-fcommon` 的 `.o`，问题照旧。
3. **`make version` 会覆盖 git 跟踪的 `engine/resources/Info.plist`** → 编完 `git checkout -- engine/resources/Info.plist`。
4. **`find . -name "*.o" -delete` 会误删被 git 跟踪的 `engine/sdl/gp2x/modules/mmuhack.o`** → `git checkout -- ` 还原。
5. Git-Bash 里跑 docker 会把 `-w /src/...` 误转成 Windows 路径 → 前缀 `MSYS_NO_PATHCONV=1`。
6. **`sdl/video.c: fatal error: SDL2_framerate.h`** → 镜像缺 `libsdl2-gfx-dev`（SDL2_gfx 的开发头，提供 `SDL2_framerate.h`）。Android 段不需要它（`sdl/video.c` 在 `#if ANDROID` 分支转 include `android/jni/openbor/video.c`，不走 SDL2_gfx）。
7. **`soundmix.c: fatal error: vorbis/vorbisfile.h`** → 镜像缺 `libvorbis-dev`（`soundmix.c` 的 `#else` 分支用 `<vorbis/vorbisfile.h>`，链接还需 `-lvorbisfile -lvorbis -logg -lvpx`，一并补 `libogg-dev libvpx-dev`）。

### 2.5 Linux arm64（aarch64，Docker + QEMU，宿主免交叉工具链）
在第 2 节基础上产出真 `ELF aarch64`：用 `docker build/run --platform linux/arm64` 借 **QEMU(`qemu-aarch64`)** 模拟，在 arm64 容器内**原生编译**（容器内 `build-linux.sh` 与 amd64 完全一致），**复用同一份 `scripts/Dockerfile`**（依赖清单无硬编码架构，apt 自动命中 `:arm64` 包），无需交叉工具链与交叉版第三方库。
```bash
bash scripts/build-linux-arm64.sh [输出目录]   # 默认 $HOME/obor-linux-arm64-build
```
产物：`OpenBOR`（ELF 64-bit LSB pie executable, ARM aarch64，约 1.35 MB）。脚本会自建 `obor-build-arm64:6392` 镜像、按需注册 `qemu-aarch64` binfmt（`tonistiigi/binfmt --install arm64`，幂等），编完把产物抽到输出目录并清源码树残留，**不入库**。

**踩坑（本轮端到端实测暴露）：**
1. **`gcc: error: unrecognized command-line option '-m64'`**（编译第一个 `.c` 即挂）：根因 `engine/Makefile` 的 Linux 段用 `findstring 64, $(GCC_TARGET)` 判架构，而 aarch64 容器的 `gcc -dumpmachine` = `aarch64-linux-gnu` 恰好含子串 `64`，被误判成 amd64，塞进 x86 专有的 `-m64`（及 yasm `-m amd64`、`-DAMD64`）。**修复**：在该判断**之前**先测 `findstring aarch64`，命中则 `TARGET_ARCH=arm64`、不设 `ARCHFLAGS`/`BUILD_MMX`/`-DAMD64`，库走 Debian multiarch `$(SDKPATH)/lib/aarch64-linux-gnu`。已门控入库，amd64 / x86 / Win 分支零影响。
2. **Git-Bash 的 Windows `tar` 在「管道 + `**` glob」下漏拷 `scripts/`**（曾试先复制 temp 副本再编以隔离，结果容器内 `scripts/build-linux.sh: No such file`）→ 改回与 `docker-build.sh` 一致的「挂载真实仓库、原地编译」，靠 `build-linux.sh` 的 `trap` 还原 Makefile；脚本自身只把产物抽到输出目录并 `rm` 源码树里的 `OpenBOR`/`OpenBOR.elf`。
3. QEMU 模拟执行比原生慢数倍，arm64 镜像 apt + 整轮编译约数分钟，属正常。

**验证**：宿主机 `od -An -tu1 -N20 OpenBOR` 读 ELF header：magic `\x7fELF`、`EI_CLASS=2`(64-bit)、`e_type=3`(ET_DYN/PIE)、`e_machine=183 0`=`0xB7`=`EM_AARCH64`（对比 x86-64=62、i386=3）。

---

## 3. Android（现代 NDK + Gradle 重建，目标 arm64-v8a）

这是**最重**的一条路。`6391` 自带的 `engine/android` 是 SDL2 2.0.1 时代的工程：
- `Android.mk` 用 `include $(call all-subdir-makefiles)`，NDK r19+ 已移除该函数 → 失效。
- `Application.mk` 是 `APP_ABI := armeabi-v7a`（纯 32 位）。
- vendored 第三方库（`jni/openbor/lib/armeabi-v7a/`：libSDL2.so / libpng.a / libogg.a / libvorbisidec.a / libvpx.a）全是 **2014 ARM32 预编译**，无法用于 arm64。
- 自带 Java 是 SDL2 **2.0.4**，`SDLActivity` 里有 openbor 定制（`getLibraries()` 加载 `openbor`、自定义 native `isNativeVibrationEnabled` / `isTouchArea`）。

**结论**：要出可靠运行的现代 arm64 APK，必须用现代 NDK **重编全套第三方库为 arm64**，Java 层用 SDL2 官方 2.33 整套替换。

### 3.0 最省心：Docker 自包含镜像（`scripts/android/docker-build.sh`）
本节后面 3.1~3.5 是**原生路线**（需本机自备 NDK/SDK/Gradle/MSYS2）。若只想一条命令出包，用自包含镜像：
```bash
bash scripts/android/docker-build.sh
```
镜像 `obor-android:6392`（`scripts/android/Dockerfile`，约 5.2GB）build 时联网烘齐 **JDK17 + Android SDK(platform-34/build-tools34) + NDK r26d + Gradle 8.7 + 第三方源码**，容器内按 01→04 跑完后产物 `app-debug.apk` 落 `$OBOR_WORK`（默认 `$HOME/obor-android-build`，不入库）。宿主仅需 Docker。
- **收益**：容器是 Linux，libvpx 原生交叉编 → **彻底摆脱 3.6 里坑 14（Git-Bash↔MSYS2 跨边界三连坑）**，也免装 MSYS2。
- **NDK 装法**：`sdkmanager` 的 cmdline-tools 索引查不到 `ndk;26.3.10750924`，改 curl 官方 `android-ndk-r26d-linux.zip` 解压到 `$ANDROID_HOME/ndk/26.3.10750924`（目录名=版本号，供 `00-env.sh` `sort -V` 命中）。
- **tremor 特例**（见坑 15）：权威源 `git.xiph.org` 是 **IPv6-only** 域名，多数 Docker 容器无 IPv6 出口 → 容器内 clone 必然 DNS 失败；GitHub 亦无 `xiph/tremor`。故 tremor **不进镜像 clone**，由 `docker-build.sh` 在宿主侧从已验证完好源（可用 `OBOR_TREMOR=/path/to/tremor` 指定）seed 进挂载卷。

### 3.1 依赖
| 组件 | 版本 | 用途 |
|---|---|---|
| Android NDK | **r26d** | 交叉编译全部 native（`aarch64-linux-android21-clang`）|
| Android SDK | platforms android-34 / build-tools 34.0.0 + platform-tools | Gradle 编译 Java + 打包 |
| JDK | 21 | Gradle 运行 |
| Gradle | 8.7（配 AGP 8.6.0）| 打 APK |
| SDL2 源码 | 官方 `SDL2.x-Android` / `android-project`（branch SDL2, 2.33）| 编 arm64 libSDL2.so + 提供 2.33 Java |
| libogg / libpng | 源码（libpng v1.6.44）| NDK CMake 交叉编 |
| tremor (vorbisidec) | 源码（只有 `configure.ac` 无 `configure`）| 手工 NDK clang 编 |
| libvpx | 源码 v1.14.1 | MSYS make + autotools-free 交叉编 |
| MSYS2 Portable | 任意 | 提供 autotools / POSIX make / host gcc（仅编第三方库用）|

### 3.2 各库 arm64 交叉编译

#### B1 — SDL2（官方 Android 工程）
```bash
NDK=/path/obor_android/android-ndk-r26d
$NDK/ndk-build.cmd \
  APP_BUILD_SCRIPT=$SDL2/android-project/app/jni/Android.mk \
  APP_PLATFORM=android-21 APP_ABI=arm64-v8a
# -> libSDL2.so (ELF 64-bit ARM aarch64)
```
> SDL2 官方 release **不提供** libSDL2 的 Android 预编译，故用官方 `android-project` 源码工程编。

#### B2a — libogg / libpng（NDK CMake）
本机 PATH 无 `make`，须用 NDK 自带 `make.exe`：
```bash
NDK=/path/obor_android/android-ndk-r26d
"$NDK/prebuilt/windows-x86_64/bin/make.exe"  # 即 make
cmake -G "Unix Makefiles" \
  -DCMAKE_MAKE_PROGRAM="$NDK/prebuilt/windows-x86_64/bin/make.exe" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21 \
  -DBUILD_SHARED_LIBS=OFF -DPNG_STATIC=ON -DPNG_SHARED=OFF -DPNG_TESTS=OFF \
  -S <src> -B <build>
# -> libogg.a, libpng.a
```

#### B2b — tremor / vorbisidec（手工 NDK clang，**绕开老 autotools**）
tremor 只有 `configure.ac` 无 `configure`；即便用 autotools 生成，其 `XIPH_PATH_OGG` 宏展开出的 `configure` 仍有语法错误。**务实做法**：直接手写 `config.h` 并用 NDK clang 编源文件。

关键点（务必都做到）：
- 手写 `config.h`：标准 POSIX 项 + **端序三件套**（源码 `misc.h` 用 `#if BYTE_ORDER==LITTLE_ENDIAN` / `BIG_ENDIAN`，宏未定义时 `0==0` 都成立，导致 `union magic` 重复定义 → 必须显式定义小端）。
- 命令行注入端序宏（源码并不 `#include config.h`）：`-DBYTE_ORDER=1234 -DLITTLE_ENDIAN=1234 -DBIG_ENDIAN=4321`。
- 头文件路径：`-I <ogg>/include`，并需 `ogg/include/ogg/config_types.h`（该文件由构建生成，缺失时按 `config_types.h.in` 手写：`typedef int32_t ogg_int32_t;` 等用 stdint 固定宽度类型）。
- **不要**定义 `ASM_ARM` → `misc.h` 的 `#include "asm_arm.h"` 被 `#ifdef ASM_ARM` 保护，走纯 C 回退。
- 编译对象（`libvorbisidec_la_SOURCES` 里的 .c）：`mdct block window synthesis info floor1 floor0 vorbisfile res012 mapping0 registry codebook sharedbook`，最后 `llvm-ar rcs libvorbisidec.a *.o`。

#### B2c — libvpx（autotools-free 交叉编，坑最多）
```bash
cd $VPX
git clean -xfd
./configure --target=arm64-android-gcc --enable-static --disable-shared --enable-pic \
  --disable-examples --disable-unit-tests --disable-tools --disable-docs --disable-libyuv
make -j4      # -> libvpx.a (全部对象 AArch64，位置无关)
```

### 3.3 B3 — 组装并重链 libopenbor.so
在**仓库外**写 `Android.mk`（绝对路径引用仓库源码 + 上面产出的 arm64 库/头，完全不碰仓库）：
```bash
$NDK/ndk-build.cmd \
  NDK_PROJECT_PATH=$JNI_ARM64 \
  APP_BUILD_SCRIPT=$JNI_ARM64/Android.mk \
  NDK_OUT=$B3/obj NDK_LIBS_OUT=$B3/libs \
  APP_PLATFORM=android-21 APP_ABI=arm64-v8a APP_OPTIM=release
```
`Android.mk` 要点：
- `LOCAL_CFLAGS`：`-Wall -Wno-error -fcommon ...` + `-DLINUX -DSDL=1 -DANDROID=1 -DTREMOR=1 -DWEBM=1`。
- 头：SDL 用**新 flat 布局**（`$SDL2/include`，匹配源码 `#include "SDL.h"`）；tremor 头放 `<dir>/tremor/` 下；暴露 `ogg/include`。
- 依赖：`LOCAL_STATIC_LIBRARIES := png vorbisidec ogg vpx`（**ogg 必须在**，tremor 依赖它；SDL2 是 shared 不是 static）。
- `LOCAL_SHARED_LIBRARIES := SDL2`；`LOCAL_LDLIBS := -ldl -lGLESv2 -llog -lz`。
- 末尾 `$(call import-module,android/cpufeatures)`（vpx 依赖 `android_getCpuFeatures`，r26d 自带该模块，**别删**）。
- **Android 不需要 SDL2_gfx**：`sdl/video.c` 在 `#if ANDROID` 分支转而 `#include "android/jni/openbor/video.c"`，不走 `SDL2_framerate.h`。
- mk 里的路径要是 `C:/...` 风格（Windows ndk-build 不认 MSYS 的 `/c/...`，写完 `sed 's#/c/Users#C:/Users#g'`）。

### 3.4 B4 — Gradle 打 APK
新建仓库外 Gradle 工程（`settings.gradle` / 根+app `build.gradle` / `AndroidManifest.xml` / `local.properties` / `gradle.properties`）：
- AGP `com.android.tools.build:gradle:8.6.0`，`compileSdk 34`，`minSdk 21`，`abiFilters 'arm64-v8a'`。
- Java：拷 SDL2 **2.33 官方整套** 9 个 java（含 HIDDevice 等）。
- 产物 `.so` 放 `app/src/main/jniLibs/arm64-v8a/`，其中 **`libopenbor.so` 改名为 `libmain.so`**：SDL2 2.33 官方 `SDLActivity.getLibraries()` 返回 `{"SDL2","main"}`，`getMainFunction()="SDL_main"`，而我们的库导出 `SDL_main` → 官方 Java 加载 `libmain.so` 并 dlsym `SDL_main`，**零 Java 定制、JNI 完全配套**。
- 打包：`gradle assembleDebug --no-daemon` → `app-debug.apk`。

### 3.5 产物与验证
- `app-debug.apk`（约 2.0 MB，包名 `org.openbor.engine`，版本名 `6392`）。
- 验证：`aapt2 dump badging` 看 `native-code: 'arm64-v8a'`；解压确认 `lib/arm64-v8a/{libSDL2.so,libmain.so}` 均 `Machine: AArch64`。
- 安装：`adb install -r app-debug.apk`

### 3.6 Android 全部踩坑（按遇到顺序）
1. 顶层 `Android.mk` 的 `all-subdir-makefiles` NDK r26 失效 → 用 `APP_BUILD_SCRIPT` 直指 `openbor/Android.mk`，不改顶层。
2. 链接 `undefined symbol: android_getCpuFeatures` → 恢复 `cpufeatures` import。
3. libvpx `configure` 报 `Unknown option --cross=...` / `--enable-better-comp` → 去掉这两个参数，`--target=arm64-android-gcc` 配 NDK clang 即可。
4. MSYS2 用 `bash -c` 找不到 pacman → **必须登录 shell `bash -lc`**；portable 首次需 `pacman-key --init` + `--populate msys2` + `pacman -Sy`；tar 解压需 `--strip-components=1`。
5. tremor 的 autotools 太老 → 放弃 autotools，改手工 clang + 手写 config.h（见 B2b）。
6. tremor `union magic` 重复定义 → 注入端序宏（见 B2b）。
7. tremor/ogg 缺 `ogg/config_types.h` → 按 `.in` 手写。
8. **libvpx 路径错位 `libs.mk: No such file or directory`**：用错了 make！NDK 的 `make.exe` 是 Windows make，解析不了 MSYS 的 `/c/.../libs.mk`。**改用 MSYS 自带的 POSIX `/usr/bin/make`**（PATH 里让 `/usr/bin` 优先）即解决。
9. libvpx 链接 `relocation R_AARCH64_... cannot be used ... recompile with -fPIC`：静态库对象非 PIC，链进 `.so` 必崩。`--extra-cflags=-fPIC` **不注入汇编**仍失败；正解是 libvpx 自带的 **`--enable-pic`**（同时覆盖 C 与汇编），重编。
10. 链接 `undefined symbol: ogg_*`：openbor 依赖列表漏了 ogg → `LOCAL_STATIC_LIBRARIES` 加 `ogg`（且 SDL2 不该在 static 列表，它是 shared）。
11. libvpx 用 `--with-pic` configure 不识别 → cfg 失败导致复用旧库；`--enable-shared` 的 configure 在探测阶段也失败 → 最终用 `--enable-pic` 静态。
12. Java/native JNI 配套：仓库 Java 2.0.4 ↔ 编出的 native 2.33 跨 30 个 minor 版签名不兼容 → 整套换 2.33 官方 Java，并把 libopenbor 改名 `libmain.so`（见 B4）。
13. **SDL2 编译入口走错**：`02-build-deps.sh` 最初把 `ndk-build` 的 `APP_BUILD_SCRIPT` 指向 `sdl2/android-project/app/jni/Android.mk`（那是**示例 app**，只有 `main` 模块、`LOCAL_SHARED_LIBRARIES := SDL2`，但没有定义 SDL2 模块）→ `Module main depends on undefined modules: SDL2`。→ 正确入口是 **SDL 源码根的 `sdl2/Android.mk`**（`LOCAL_MODULE := SDL2`），`APP_BUILD_SCRIPT=$WORK/sdl2/Android.mk`。
14. **libvpx 跨 Git-Bash↔MSYS2 边界三连坑**（Windows 上 libvpx 需 host gcc + POSIX make，只能在 MSYS2 编）：
    - `mktemp` 生成的脚本落在 Git-Bash 的 `/tmp`，与 MSYS2 的 `/tmp` **不互通** → 改用写到 `$WORK` 下的 `vpxbuild.sh`（两边同盘符路径一致），并把绝对路径**字面量展开**写进脚本，执行不再依赖跨边界 env 传参。
    - 裸 `/usr/bin` 从 Git-Bash 起的 MSYS 子 bash 会被解析到 **Git 的 usr/bin**（无 `make`）→ 由 `$MSYS` 反推 msys64 的 `usr/bin` **绝对路径**写进 PATH。
    - 宿主 Git-Bash 传入的 `TEMP`/`TMPDIR`（Windows 路径）污染 libvpx 的 configure：它在 msys `/tmp` 建临时 `.c` 却用绝对 `/usr/bin/cat`（Git 的，看不到 msys `/tmp`）读不回 → `Unable to invoke compiler`。→ 用 **`env -i`** 起干净 MSYS 子 shell（仅给 msys 原生 `PATH` + `TMPDIR/TMP/TEMP=/tmp`），彻底甩开 Git-Bash 环境。
15. **Docker 镜像路线暴露的两处 clone 源缺陷**（原生 02→04 从不跑 `01-clone.sh`，故一直没暴露）：
    - `01-clone.sh` 的 libpng 用 `madler/libpng` → GitHub **404**（触发 `could not read Username`）→ 改 `glennrp/libpng`（libpng 官方 GitHub 镜像，`v1.6.44` tag 可达）。
    - **tremor** 权威源 `git.xiph.org` 是 **IPv6-only** 域名：Docker 容器（及本机 Git-Bash）无 IPv6 出口 → `Could not resolve host`；GitHub 无 `xiph/tremor`。→ tremor **不进镜像 clone**，`docker-build.sh` 在宿主侧从已验证完好源 seed（`OBOR_TREMOR=/path/to/tremor` 指定，脚本自动探测常见位置）。

---

## 4. PSP / Vita（官方预编译工具链镜像，宿主零 SDK）

掌机两平台各自用**官方预编译交叉工具链镜像**编译（与 Linux/Win 用自建 `obor-build`、Android 用自建 `obor-android` 互补——掌机不并库，因为 SDK 装法官方镜像即权威、现编 toolchain 慢且脆）。宿主仅需 Docker。

一条命令同时编两平台，产物导出到仓库外 temp（默认 `$HOME/obor-pspvita-build`，可传参覆盖）：
```bash
bash scripts/docker-build-pspvita.sh          # 串调 build-psp.sh + build-vita.sh
# 或单独：
bash scripts/build-psp.sh   [输出目录]         # 用 pspdev/pspdev:latest      → EBOOT.PBP
bash scripts/build-vita.sh  [输出目录]         # 用 vitasdk/vitasdk:latest    → OpenBOR.vpk
```
- PSP 镜像 `pspdev/pspdev:latest`：`psp-gcc` = **GCC 15.2.0**，portlibs 齐（`libpspgu/pspaudio/psppower/psprtc` + tremor 所需 `libvorbisidec/libogg/libpng/libz`）。
- Vita 镜像 `vitasdk/vitasdk:latest`（注意：仓库名是 `vitasdk/vitasdk`，`vitasdk/toolchain` 不存在）：`arm-vita-eabi-gcc` = **GCC 15.2.0**，打包链 `vita-elf-create/vita-make-fself/vita-mksfoex/vita-pack-vpk` 与 `libvita2d/libfreetype/libjpeg` 齐。

脚本在容器内 `cp -a` 副本上 `make`，只把最终产物拷回 OUT_DIR，**不污染源码树**。

### 4.1 产物
- `EBOOT.PBP`（PSP，魔数 `00 50 42 50`；`make` 走 `psp/build.mak`：编 `.o` → `psp-prxgen` 生成 PRX → `pack-pbp` 打入 PARAM.SFO/icon/logo）
- `OpenBOR.vpk`（Vita，魔数 `50 4b 03 04`；打包链 `elf→velf→fself→vpk`，`TITLE_ID=OPENBOR30`，见 `engine/Makefile` Vita 段）

### 4.2 GCC 15 下的额外改造（已固化进仓库，均门控）
2014 代码在 GCC15 下命中硬 error，逐个修正（Linux/Win 用 GCC12 只当 warning，故这些改动都**限定在 PSP/Vita 生效**）：

| 改动 | 位置 | 门控方式 |
|---|---|---|
| str 函数映射 `-Dstricmp=strcasecmp -Dstrnicmp=strncasecmp` + `-Wno-error` 系列降级 + `-fcommon` | `engine/Makefile` 新增 `ifdef BUILD_PSP` / `ifdef BUILD_VITA` 两段 | `ifdef` 门控，排在全局 `-Werror` 之后 |
| `_time` 类型冲突 `unsigned int`→`u32` | `openborscript.c:14061`（与同文件 69 行 `u32` 声明统一） | 纯类型修正，各平台都更正确 |
| 文件作用域 VLA `vitaPalette[PAL_BYTES]`→`[1024]`（`PAL_BYTES` 非编译期常量） | `vita/video.c:18` | 仅 Vita 专有文件 |
| libpng 1.6 API 漂移 `png_infopp_NULL/int_p_NULL/png_bytep_NULL`→`NULL`、`png_set_gray_1_2_4_to_8`→`png_set_expand_gray_1_2_4_to_8` | `psp/image.c` | 仅 PSP 专有文件 |
| 注释 `PSP_HEAP_SIZE_MAX();`（现代 PSP SDK 已移除该宏） | `psp/pspport.c:27` | 仅 PSP 专有文件 |
| Vita LIBS 去 `-lSceKernel_stub`（现代 vitasdk 已移除）、补 `-lSceAppMgr_stub`（现编 `libvita2d` 新增依赖 `sceSharedFb*`/`sceAppMgrGetBudgetInfo`） | `engine/Makefile` Vita `LIBS` 行 | 本就在 `ifdef BUILD_VITA` 内 |

> 已实测：回归 Linux/Win（`docker-build.sh`）后 `engine/Makefile` 的 PSP/VITA 块计数不变（18 行命中），证明上述 `ifdef` 门控对 Linux/Win **零回归**。

### 4.3 踩坑（本轮端到端实测暴露）
- **Vita 镜像仓库名**：正确是 `vitasdk/vitasdk:latest`；`vitasdk/toolchain` 一律 404。
- **`-Wno-error` 单独不够**：GCC14+ 把 `implicit-function-declaration` 默认升为 error，需再显式 `-Wno-error=implicit-function-declaration` 退回 warning。
- **Vita 链接 stub 漂移**：`libvita2d`（vitasdk 现编版）比 2014 版多依赖 `sceSharedFb*`+`sceAppMgrGetBudgetInfo`，两者现归属 `libSceAppMgr_stub.a`（现代 SDK 把 SharedFb 并入 AppMgr）；旧 `SceKernel_stub` 已不存在，须删。

### 4.4 已知限制
- 产物为掌机格式，**本机无法运行验证**，仅能验"编出合法文件"（魔数 + 打包链走通）。PSP 可 PPSSPP 加载（需另投游戏 `.pak` 到 `PSP/GAME/OPENBOR30/Paks/`）；Vita 需实机/ henkaku。
- 两平台同样**不含游戏数据（Paks）**。

---

## 5. macOS（Darwin / Apple Silicon arm64，须真机）

**与前五平台根本不同：macOS 产物无法在 Linux/Docker 交叉编译。** 链接 Cocoa / AudioUnit / IOKit 需要 Apple SDK 与 XNU，只能在**真实 macOS**（Apple Silicon Mac，或基于 Apple VZ 的 arm64 macOS 虚拟机 / GitHub Actions `macos-14` runner）上编译；x86 主机里的 QEMU「Docker-OSX」起的是 x86_64 macOS、且踩过 Apple 许可线，产不出 arm64 产物。

依赖 Homebrew，在 Mac 上一条命令产出 `.app`（默认导出到仓库外 temp `$HOME/obor-mac-build`，可传参覆盖）：
```bash
bash scripts/build-mac.sh [输出目录]     # 自动 brew 安装依赖，temp 副本上编，组 .app
```
- 目标 **Apple Silicon arm64**：clang 用 host 默认 arch（`arm64-apple-darwin`），**无需 `-arch`**（已去 i386/x86_64 与 x86 MMX 汇编）。
- 依赖：`brew install sdl2 sdl2_gfx libvorbis libpng libogg`（注：`sdl2` 现由 `sdl2-compat`(SDL3 兼容层) 提供，提供 `libSDL2`/`libSDL2main`，**不再有**旧的 `libSDLmain`）。
- 实测环境：Apple M 系列（arm64）、macOS 26.5、Apple clang 21、SDK 26.5、Homebrew 5。
- 脚本在仓库外 temp 副本上 `make`，组好 `.app` 后 `codesign` adhoc 签名，只把 `OpenBOR.app` 落 OUT_DIR，**不污染源码树**。

### 5.1 产物
- `OpenBOR.app`（`Contents/MacOS/OpenBOR` = **Mach-O 64-bit executable arm64**，含 `Info.plist`/`PkgInfo`/`OpenBOR.icns`/`_CodeSignature`，adhoc 签名）。运行需自备游戏 pak。

### 5.2 Apple clang 下的额外改造（已固化进仓库，均门控）
2014 的 Darwin 端口停留在 32 位 Intel + GCC 时代；Apple clang 21 / macOS 26 SDK 比它严苛得多。所有改动都**限定在 Darwin 生效**（Linux/Win 零回归）：

| 改动 | 位置 | 门控方式 |
|---|---|---|
| `CC = gcc`→`clang`；去 `-arch i386`/`-arch x86_64` 与 `BUILD_MMX`；改 `TARGET_ARCH=arm64`；INCLUDES 去 `MacOSX10.4u` malloc 路径、`include/SDL`→`include/SDL2` | `engine/Makefile` `ifdef BUILD_DARWIN` 段 | 整段 `ifdef BUILD_DARWIN` 门控 |
| `-freorder-blocks`（GCC 专有 pass，clang 拒收） | `engine/Makefile` CFLAGS 优化块 | `ifndef BUILD_DARWIN` 排除该行 |
| LIBS 去 `-framework Carbon`（32-bit-only，arm64 不存在）、`-lSDLmain`→`-lSDL2main` | `engine/Makefile` Darwin `LIBS` 段 | 本就在 `ifdef BUILD_DARWIN` 内 |
| `-headerpad_max_install_names` 从编译期 CFLAGS 移到链接期 LIBS（否则 clang 报"编译期未用参数"被 `-Werror` 升级） | `engine/Makefile` Darwin CFLAGS / LIBS | 同上 |
| Apple clang21 新诊断降回 warning：`-Wno-error` 系列（`deprecated-non-prototype`/`implicit-enum-enum-cast`/`unused-but-set-variable`/`gnu-folding-constant`/`int-conversion`(GLhandleARB↔GLuint)/…）+ `-fcommon` | `engine/Makefile` Darwin 段新增块 | 排在全局 `-Werror` 之后，仅 Darwin 生效 |
| `yuv.h` 找不到（`sdl/video.h` 无条件 include，但 Darwin 无 `BUILD_WEBM`） | `engine/Makefile` Darwin `INCS += source/webmlib` | 仅加 include 路径，不引 webm 对象/libvpx |
| `<malloc.h>`（glibc 专有，Apple 只有 `malloc/malloc.h`） | 新建 `engine/mac/malloc.h` 转发 `<stdlib.h>`；`INCS += mac` | 仅 Darwin `INCS` 引用该目录 |
| `mallinfo()`（glibc 专有，全仓唯一一处，仅 OOM 日志用） | `source/utils.c:307` | `#ifndef DARWIN` 门控该行 |

### 5.3 踩坑（本轮真机端到端实测暴露）
- **无法进 Docker**：与 PSP/Vita 不同，macOS 没有可用的交叉容器，必须真 Apple Silicon（见本节开头）。
- **`sdl2` 已是 SDL3 兼容层**：Homebrew `sdl2` 现指向 `sdl2-compat`，提供 `libSDL2main.a` 但无旧 `libSDLmain` → LIBS 用 `-lSDL2main`。
- **Apple clang 比 GCC15 更严**：`-Wno-error` 单用不够，`int-conversion`（`sdl/opengl.c` 的 `GLhandleARB`(void*)↔`GLuint`(uint)）在 Apple clang 下默认即 error，须显式 `-Wno-error=int-conversion`（与 PSP/Vita 同类坑）。
- **链接期参数混进编译期**：老 Makefile 把 `-headerpad_max_install_names`（链接选项）放在 CFLAGS，clang `-Werror` 直接拒。

### 5.4 已知限制
- 产物是 `.app`，**依赖 Homebrew 绝对路径**（`otool -L` 显示 `libSDL2` 等指向 `/opt/homebrew/...`）→ 仅在同款装了对应 bottle 的 Mac 上可直接跑；对外分发需 `darwin.sh` 式改 install-name + 拷库进 `Contents/Libraries`（本轮只做本机可运行版，adhoc 签名，非公证分发）。
- **不含游戏数据（Paks）**，且本机（Windows）无法运行 macOS `.app`，验证均在真 Mac 上经 ssh 完成。

---

## 6. 已知限制 / 后续

- **APK 未打包游戏数据（Paks）**：OpenBOR 运行需游戏资源，需放设备存储或改 assets 注入后重打包。
- 仅产出 **arm64-v8a**（B 路线目标），未含 armeabi-v7a / x86 / x86_64。
- SDL2 2.0.4 时代 openbor 自定义的两个 native（震动/触摸区）在 2.33 官方 Java 下未接线 → 运行时该两处功能降级，不影响启动。
- 上述所有第三方库产物、临时脚本、`Android.mk`、Gradle 工程均在仓库外 temp；temp 被系统清理后需按本文重跑。建议长期复现时把 temp 迁到固定目录或整理成仓库外脚本。

---

## 7. 一键概览

| 平台 | 关键工具链 | 是否需放宽 `-Werror`/`-fcommon` | 产物 |
|---|---|---|---|
| Windows | **Docker 交叉** `i686-w64-mingw32-gcc`（GCC 12）+ win-sdk 库 | **是** | `engine/OpenBOR.exe` (PE32 32) |
| Windows x64 | **Docker 交叉** `x86_64-w64-mingw32-gcc`；自带 win-sdk 无 64 位库，第三方库由 `Dockerfile.win64` 预烘进镜像 sysroot（版本锁在 `xbuild-win64-libs.sh`），`build-win64-docker.sh` 直接取用编 exe；裸容器无 sysroot 时现场交叉编兜底 | **是** | `engine/OpenBOR.exe` (PE32+ 64) |
| Linux | Docker GCC 12 | **是** | `engine/OpenBOR` (ELF64) |
| Linux arm64 | **Docker `--platform linux/arm64` + QEMU** 原生编（复用同 Dockerfile，无交叉工具链） | **是** | `OpenBOR` (ELF aarch64) |
| Android | **Docker 自包含镜像**（`obor-android:6392`，含 NDK r26d + Gradle 8.7 + AGP 8.6 + SDL2 2.33）；或原生自备工具链 | **是** | `app-debug.apk` (arm64) |
| PSP | **官方镜像** `pspdev/pspdev:latest`（`psp-gcc` GCC 15） | **是**（且更多，GCC15 硬 error） | `EBOOT.PBP` (PRX 打包) |
| Vita | **官方镜像** `vitasdk/vitasdk:latest`（`arm-vita-eabi-gcc` GCC 15） | **是**（且更多，GCC15 硬 error） | `OpenBOR.vpk` |
| macOS | **真机** Apple clang 21 + Homebrew SDL2（arm64，无法 Docker 交叉） | **是**（Apple clang 比 GCC15 更严） | `OpenBOR.app` (Mach-O arm64) |

> Linux + Windows 均由 `bash scripts/docker-build.sh` 一条命令在同一容器内产出；Android 推荐 `bash scripts/android/docker-build.sh`（自包含镜像，宿主仅需 Docker），原生路线则手动跑 `scripts/android/01→04`；**PSP + Vita** 由 `bash scripts/docker-build-pspvita.sh` 一条命令产出（官方工具链镜像，产物落仓库外 temp）；**macOS** 由 `bash scripts/build-mac.sh` 在真实 Apple Silicon Mac 上产出 `.app`（无法进 Docker）。

---

## 8. 构建镜像发布到 ghcr（免重复 build，可直接拉取）

四个**自建**构建镜像已发布为 GitHub Container Registry（ghcr.io）上的**公开包**，任何人可匿名拉取，免去每次本地从零 `docker build`（尤其 Android 镜像 5.22 GB，首次 build 联网烘 NDK/SDK/Gradle 很慢）。

### 8.1 镜像坐标与 digest

| 本地镜像名（脚本期望） | ghcr 公开坐标 | digest | 体积 | 用途 |
|---|---|---|---|---|
| `obor-build:6392` | `ghcr.io/iintothewind/openbor-build:6392` | `sha256:5b643eb09acb…` | 1.68 GB | Linux amd64 + Win 交叉 |
| `obor-build-arm64:6392` | `ghcr.io/iintothewind/openbor-build-arm64:6392` | `sha256:31e93edf2404…` | 1.67 GB | Linux arm64（QEMU 原生编，**发布 CI 已改用原生 arm64 runner，不再用它**，留作本地/无原生 runner 时用） |
| `obor-build-win64:6392` | `ghcr.io/iintothewind/openbor-build-win64:6392` | `sha256:8121e6e358c9…` | 1.5 GB | Win x64 交叉（内含交叉链 + **预烘 64 位第三方库 sysroot**） |
| `obor-android:6392` | `ghcr.io/iintothewind/openbor-android:6392` | `sha256:b11bae08da0b…` | 5.22 GB | Android（NDK+SDK+Gradle+三方源码） |

> PSP/Vita 用**官方公共镜像**（`pspdev/pspdev:latest`、`vitasdk/vitasdk:latest`）、macOS **无法进 Docker**，均不发布、直接按第 4/5 节用官方镜像或真机。

### 8.2 拉取并复用（推荐，零改脚本）
脚本内部用的是**本地镜像名**（`obor-build:6392` 等）。拉下来后 `docker tag` 回本地名即可复用，脚本里的 `docker build` 会命中已有层、秒过：
```bash
docker pull ghcr.io/iintothewind/openbor-build:6392
docker tag  ghcr.io/iintothewind/openbor-build:6392  obor-build:6392

docker pull ghcr.io/iintothewind/openbor-build-arm64:6392
docker tag  ghcr.io/iintothewind/openbor-build-arm64:6392  obor-build-arm64:6392

docker pull ghcr.io/iintothewind/openbor-build-win64:6392
docker tag  ghcr.io/iintothewind/openbor-build-win64:6392  obor-build-win64:6392

docker pull ghcr.io/iintothewind/openbor-android:6392
docker tag  ghcr.io/iintothewind/openbor-android:6392  obor-android:6392
```
之后照常跑 `scripts/docker-build.sh` / `scripts/build-linux-arm64.sh` / `scripts/android/docker-build.sh` 即可。

> 若只想手动进容器编一次（不跑脚本）：
> ```bash
> # Linux amd64 + Win（同一容器）
> MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD":/src -w /src obor-build:6392 \
>   bash -c "bash scripts/build-linux.sh && bash scripts/build-win-docker.sh"
> # Linux arm64（需 --platform + qemu-aarch64 binfmt）
> MSYS_NO_PATHCONV=1 docker run --rm --platform linux/arm64 -v "$PWD":/src -w /src obor-build-arm64:6392 \
>   bash scripts/build-linux.sh
> ```

### 8.3 发布/推送流程（维护者，需重新构建或更新版本时）
```bash
NS=ghcr.io/iintothewind
# 1) 重新 tag（前缀 openbor-）
docker tag obor-build:6392         $NS/openbor-build:6392
docker tag obor-build-arm64:6392   $NS/openbor-build-arm64:6392
docker tag obor-build-win64:6392   $NS/openbor-build-win64:6392
docker tag obor-android:6392       $NS/openbor-android:6392
# 2) 登录 ghcr（见 8.4 身份要求）
printf '%s' "$GITHUB_TOKEN" | docker login ghcr.io -u iintothewind --password-stdin
# 3) 推送
docker push $NS/openbor-build:6392
docker push $NS/openbor-build-arm64:6392
docker push $NS/openbor-build-win64:6392
docker push $NS/openbor-android:6392
```

### 8.4 身份与可见性（实测踩坑，务必照此）
- **推送 namespace 必须是 `iintothewind` 本人签发、带 `write:packages` 的 token**。ghcr 在 `ghcr.io/iintothewind/...` 建包，只认该 namespace 的写权；用别的账号（如协作者 `ivar-acrgo`）的 token 会 `permission_denied: create_package`。
- **token 类型**：用 **classic PAT 且同时勾 `write:packages` + `repo`** 最稳。`ghp_…` 只勾了部分 scope、或 fine-grained PAT（`github_pat_…`）未授 Packages 写权时，push 报 `permission_denied: The token provided does not match expected scopes`（身份对、scope 不够）。
- **可见性只能网页手动设 public**：user-namespace 包无对应 API——REST `PATCH /users/<u>/packages/container/<pkg>/visibility` 返回 `404`，GraphQL `updatePackage` 已从 schema 移除。到各包 settings 的 Danger Zone → Change visibility → Public：
  ```
  https://github.com/users/iintothewind/packages/container/openbor-build/settings
  https://github.com/users/iintothewind/packages/container/openbor-build-arm64/settings
  https://github.com/users/iintothewind/packages/container/openbor-build-win64/settings
  https://github.com/users/iintothewind/packages/container/openbor-android/settings
  ```
- **验证 public**（不带任何本地凭证的匿名 token 交换）：
  ```bash
  for p in openbor-build openbor-build-arm64 openbor-build-win64 openbor-android; do
    tok=$(curl -s "https://ghcr.io/token?scope=repository:iintothewind/$p:pull" \
          | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
    curl -s -o /dev/null -w "$p: HTTP %{http_code}\n" \
      -H "Authorization: Bearer $tok" \
      -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
      "https://ghcr.io/v2/iintothewind/$p/manifests/6392"
  done   # 四包均应 HTTP 200 => 可匿名拉
  ```

### 8.5 安全提醒
推送用的高权限 PAT（尤其 classic full PAT）属敏感凭证，发布完成后应尽快 **revoke**；日常复用只需匿名 `docker pull`，无需任何凭证。

---

## 9. 发布 CI（GitHub Actions，一次发布多平台产物）

`.github/workflows/release.yml`：在 GitHub 上**创建（发布）一个 Release** 时自动触发，一次产出并上传 **7 个平台**产物到该 Release：

| 产物文件 | 平台 | 构建方式 |
|---|---|---|
| `OpenBOR-linux-x86_64` | Linux x64 | **原生 `ubuntu-latest` runner**（本身就是 x86_64 Linux）直接 apt 装依赖 + 跑 `build-linux.sh`，无容器/QEMU |
| `OpenBOR-linux-aarch64` | Linux arm64 | **原生 `ubuntu-24.04-arm` runner**（GitHub 原生 arm64，已 GA、public 免费）直接 apt 装依赖 + 跑 `build-linux.sh`，无容器/QEMU |
| `OpenBOR-windows-x32.exe` | Windows x32 (32) | ghcr 镜像 `openbor-build` 内跑 `build-win-docker.sh`（i686 交叉） |
| `OpenBOR-windows-x64.exe` | Windows x64 (PE32+) | ghcr 镜像 `openbor-build-win64`（预烘 64 位第三方库 sysroot）内跑 `build-win64-docker.sh`，只编 OpenBOR 本体 |
| `OpenBOR-psp-EBOOT.PBP` | PSP | 官方镜像 `pspdev/pspdev` |
| `OpenBOR-vita.vpk` | Vita (PSV) | 官方镜像 `vitasdk/vitasdk` |
| `OpenBOR-macos-arm64.zip` | macOS arm64 | 真实 `macos-14` runner 跑 `build-mac.sh`，`ditto` 打包 `.app` |

外加 `SHA256SUMS.txt`。产物均不含游戏 `.pak`（见第 6 节）。各平台为**相互独立的 job**（某平台失败不牵连其余）。

### 9.1 触发与用法

- 触发事件：`release: types: [published]`。在仓库 **Draft → Publish release** 即触发构建，产物自动挂到该 Release 的 Assets。
- 也可 `workflow_dispatch` 手动跑（仅产 artifacts，需配合 Release 才上传）。
- 版本号沿用 tag（Release 的 tag 即 `git tag`）。

### 9.2 依赖的 ghcr 镜像

仅 **Win x32** 与 **Win x64** 依赖第 8 节的 ghcr 公开镜像（工作流内 `docker pull` + `docker tag` 回本地名）。**Linux x64、Linux arm64 均用 GitHub 原生 runner（`ubuntu-latest` / `ubuntu-24.04-arm`）直接编，不再拉镜像、也不用 QEMU。**PSP/Vita 用官方公共镜像。macOS 用真机 `macos-14` runner + Homebrew。

### 9.3 CI 踩坑（真跑测试 tag 暴露）

- **Linux x64 误链 Windows 库（exit 2）**：`-lsetupapi`/`-lwinpthread` 的门控最初只看 `GCC_TARGET` 含 `x86_64`，但 Linux 原生 `gcc -dumpmachine` 也是 `x86_64-linux-gnu`，导致 Linux 链接去拉 Windows 专属库失败 → 门控补 `ifdef BUILD_WIN` 限定。
- **Linux x64 容器/QEMU 无必要**：GitHub Actions 的 `ubuntu-latest` 本身即 x86_64 Linux，直接 apt 装依赖原生编即可，无需容器/QEMU（原合并 job 走 ghcr 容器纯属多余且慢）。
- **Linux/Win 合并 job 连坐**：Linux 与 Win x32 合成一个 job 时，Linux 侧任何失败会连带 Win 步骤不执行 → 拆成两个独立 job。
- **挂载目录 `dubious ownership`（exit 128）**：容器挂载 `/src` 原地编时，脚本 `trap` 里的 `git checkout` 触发 git 安全策略报错 → 每个容器内先 `git config --global --add safe.directory /src`。
- **arm64 `docker pull` 报 `no matching manifest for linux/amd64`**（仅本地仍走 arm64 容器方式时适用；发布 CI 的 linux-arm64 已改用原生 `ubuntu-24.04-arm` runner，不再拉 arm64 镜像）：ghcr 的 arm64 镜像只有 arm64 层，`pull` 必须显式 `--platform linux/arm64`。
- **SDL2 拒绝 in-tree 构建**：win64 现场交叉编 SDL2 时，SDL 禁止在 git clone 目录内直接 configure → 在其内部 `build/` 做 out-of-tree（`../configure`）。
- **win64 镜像 build context 用 `scripts/` 而非仓库根**：本仓库 `.git` 达 1.3 GB，以仓库根做 context 每次 `docker build` 都要把整个 `.git` 传给 daemon → `docker build -f scripts/Dockerfile.win64 ... scripts`（context 设成 `scripts/`，`COPY` 源路径相应去掉 `scripts/` 前缀）。第三方库交叉编译逻辑收敛进 `scripts/xbuild-win64-libs.sh`，镜像与本地兜底共用同一份，避免版本/参数漂移。
- macOS `macos-14` 即 Apple Silicon runner，原生 arm64，无需交叉。
