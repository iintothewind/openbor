#!/usr/bin/env bash
# OpenBOR 6392 Android - 组装 Gradle 工程并打 debug APK
# 前置：02(出 libSDL2.so) + 03(出 libopenbor.so) 已完成
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-env.sh"
OUT="$WORK/out"
[ -f "$OUT/libSDL2.so" ] || { echo "X 缺 libSDL2.so，先跑 02"; exit 1; }
[ -f "$WORK/nlibs/$ABI/libopenbor.so" ] || { echo "X 缺 libopenbor.so，先跑 03"; exit 1; }

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK" ] || { echo "X 需要 ANDROID_HOME/ANDROID_SDK_ROOT（含 platforms/build-tools）"; exit 1; }

GRADLE="$(command -v gradle || true)"
[ -n "$GRADLE" ] || GRADLE="$(find "$WORK" "$HOME" -maxdepth 3 -name gradle -type f -path '*/bin/*' 2>/dev/null | head -1)"
[ -n "$GRADLE" ] || { echo "X 需要 Gradle(8.7+)，装到 PATH 或放 $WORK 下"; exit 1; }

APK="$WORK/apk"; rm -rf "$APK"; cp -r "$REPO/scripts/android/gradle" "$APK"
DSTJ="$APK/app/src/main/java/org/libsdl/app"; mkdir -p "$DSTJ" "$APK/app/src/main/res"
LIBD="$APK/app/src/main/jniLibs/$ABI"; mkdir -p "$LIBD"

# SDL2 官方 Java（与编出的 native 同代 2.33 整套 9 个）
cp "$WORK/sdl2/android-project/app/src/main/java/org/libsdl/app/"*.java "$DSTJ/"
# 仓库自带 res（图标/strings）
cp -r "$ENG/android/res/." "$APK/app/src/main/res/"
# native：libSDL2.so 原样；libopenbor.so -> libmain.so
#   官方 SDLActivity.getLibraries()={"SDL2","main"}, getMainFunction()="SDL_main"
#   而 libopenbor.so 导出 SDL_main -> 零 Java 定制、JNI 完全配套
cp "$OUT/libSDL2.so" "$LIBD/libSDL2.so"
cp "$WORK/nlibs/$ABI/libopenbor.so" "$LIBD/libmain.so"

# local.properties 指向 SDK（正斜杠路径，properties 合法，免转义）
if [ "$WIN" = 1 ]; then SDKP="$(cygpath -m "$SDK")"; else SDKP="$SDK"; fi   # C:/... mixed 正斜杠
printf 'sdk.dir=%s\n' "$SDKP" > "$APK/local.properties"

echo ">>>>>> gradle assembleDebug ($ABI)"
( cd "$APK" && OABI="$ABI" "$GRADLE" assembleDebug --no-daemon --console=plain )

APKF="$APK/app/build/outputs/apk/debug/app-debug.apk"
[ -f "$APKF" ] && echo ">> APK 完成: $APKF" || { echo "X 打包失败"; exit 1; }
