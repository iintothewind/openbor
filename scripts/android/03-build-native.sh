#!/usr/bin/env bash
# OpenBOR 6392 Android - 组装 arm64 库/头并重链 libopenbor.so
# 在 $WORK 生成参数化 Android.mk（不碰仓库源码，用绝对路径引用 engine）
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-env.sh"
OUT="$WORK/out"; INC="$WORK/inc"
for f in libSDL2.so libogg.a libpng.a libvorbisidec.a libvpx.a; do
  [ -f "$OUT/$f" ] || { echo "X 缺 $OUT/$f，先跑 02-build-deps.sh"; exit 1; }
done
# 供 Android.mk 用的路径（Windows 需 C:/ 风格）
MENG="$(topath "$ENG")"; MWORK="$(topath "$WORK")"; MOUT="$(topath "$OUT")"; MINC="$(topath "$INC")"
PNGINC="$(topath "$WORK/libpng")"; PNGCONF="$(topath "$WORK/libpng-build")"
OGGINC="$(topath "$WORK/ogg/include")"; VPXINC="$(topath "$WORK/libvpx")"

MK="$WORK/jni/Android.mk"; mkdir -p "$WORK/jni" "$WORK/nobj" "$WORK/nlibs"
cat > "$MK" <<EOF
LOCAL_PATH := \$(call my-dir)
ENG  := $MENG
OUT  := $MOUT
INC  := $MINC

include \$(CLEAR_VARS)
LOCAL_MODULE := SDL2
LOCAL_SRC_FILES := \$(OUT)/libSDL2.so
include \$(PREBUILT_SHARED_LIBRARY)

include \$(CLEAR_VARS)
LOCAL_MODULE := png
LOCAL_SRC_FILES := \$(OUT)/libpng.a
LOCAL_EXPORT_C_INCLUDES := $PNGINC $PNGCONF
include \$(PREBUILT_STATIC_LIBRARY)

include \$(CLEAR_VARS)
LOCAL_MODULE := ogg
LOCAL_SRC_FILES := \$(OUT)/libogg.a
LOCAL_EXPORT_C_INCLUDES := $OGGINC
include \$(PREBUILT_STATIC_LIBRARY)

include \$(CLEAR_VARS)
LOCAL_MODULE := vorbisidec
LOCAL_SRC_FILES := \$(OUT)/libvorbisidec.a
LOCAL_EXPORT_C_INCLUDES := \$(INC)/tremor
include \$(PREBUILT_STATIC_LIBRARY)

include \$(CLEAR_VARS)
LOCAL_MODULE := vpx
LOCAL_SRC_FILES := \$(OUT)/libvpx.a
LOCAL_EXPORT_C_INCLUDES := $VPXINC
include \$(PREBUILT_STATIC_LIBRARY)

include \$(CLEAR_VARS)
LOCAL_MODULE := openbor
LOCAL_CFLAGS := -g -O2 -Wall -Wno-error -fcommon -Wno-unused-result -fsigned-char -fno-ident -freorder-blocks
LOCAL_CFLAGS += -DLINUX -DSDL=1 -DANDROID=1 -DTREMOR=1 -DWEBM=1
LOCAL_CPPFLAGS := \$(LOCAL_CFLAGS)
WRAP := \$(ENG)/android/jni/openbor
LOCAL_C_INCLUDES := \
  \$(INC) $OGGINC \
  \$(WRAP)/include/sdl \$(WRAP)/include/png \$(WRAP)/include/tremor \$(WRAP)/include/vpx \
  \$(ENG) \$(ENG)/sdl \$(ENG)/resources \$(ENG)/source \
  \$(ENG)/source/adpcmlib \$(ENG)/source/gamelib \$(ENG)/source/gfxlib \$(ENG)/source/pnglib \
  \$(ENG)/source/preprocessorlib \$(ENG)/source/ramlib \$(ENG)/source/randlib \
  \$(ENG)/source/scriptlib \$(ENG)/source/openborscript \$(ENG)/source/tracelib2 \
  \$(ENG)/source/webmlib \$(ENG)/source/webmlib/halloc \$(ENG)/source/webmlib/nestegg
LOCAL_SRC_FILES := \
  \$(wildcard \$(ENG)/sdl/*.c) \$(wildcard \$(ENG)/*.c) \$(wildcard \$(ENG)/source/*.c) \
  \$(wildcard \$(ENG)/source/adpcmlib/*.c) \$(wildcard \$(ENG)/source/gamelib/*.c) \
  \$(wildcard \$(ENG)/source/gfxlib/*.c) \$(wildcard \$(ENG)/source/pnglib/*.c) \
  \$(wildcard \$(ENG)/source/preprocessorlib/*.c) \$(wildcard \$(ENG)/source/ramlib/*.c) \
  \$(wildcard \$(ENG)/source/randlib/*.c) \$(wildcard \$(ENG)/source/scriptlib/*.c) \
  \$(wildcard \$(ENG)/source/openborscript/*.c) \$(wildcard \$(ENG)/source/webmlib/*.c) \
  \$(wildcard \$(ENG)/source/webmlib/*/*.c) \
  \$(WRAP)/jniutils.cpp \$(WRAP)/SDL_android_main.cpp
LOCAL_LDLIBS := -ldl -lGLESv2 -llog -lz
LOCAL_STATIC_LIBRARIES := png vorbisidec ogg vpx
LOCAL_SHARED_LIBRARIES := SDL2
include \$(BUILD_SHARED_LIBRARY)
\$(call import-module,android/cpufeatures)
EOF

echo ">>>>>> 重链 libopenbor.so ($ABI)"
"$NDB" NDK_PROJECT_PATH="$(topath "$WORK")" \
  APP_BUILD_SCRIPT="$(topath "$MK")" \
  NDK_OUT="$(topath "$WORK/nobj")" NDK_LIBS_OUT="$(topath "$WORK/nlibs")" \
  APP_PLATFORM="android-$API" APP_ABI="$ABI" APP_OPTIM=release

LIB="$WORK/nlibs/$ABI/libopenbor.so"
[ -f "$LIB" ] && echo ">> OK: $LIB" || { echo "X 链接失败"; exit 1; }
