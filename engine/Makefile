#
# OpenBOR - http://www.ChronoCrash.com
# ---------------------------------------------------------------------------------------------------
# All rights reserved, see LICENSE in OpenBOR root for details.
#
# Copyright (c) 2004 - 2018 OpenBOR Team
#

#----------------------------------------------------------------------------------------------------
#
#               	OpenBOR Makefile for ALL TARGET_PLATFORMs
#
#             PSP, PS3, Wii, Pandora, Windows, Darwin & Linux
#
#----------------------------------------------------------------------------------------------------

ifndef VERSION_NAME
VERSION_NAME = OpenBOR
endif

#----------------------------------------------------------------------------------------------------
# Defines
#----------------------------------------------------------------------------------------------------


ifdef BUILD_PSP
TARGET          = $(VERSION_NAME)
TARGET_FINAL    = EBOOT.PBP
TARGET_PLATFORM = PSP
PBPNAME_STR     = $(TARGET)
BUILD_TREMOR    = 1
BUILDING        = 1
ifeq ($(BUILD_PSP), 0)
BUILD_DEBUG     = 1
endif
endif


ifdef BUILD_WIN
TARGET          = $(VERSION_NAME).elf
TARGET_FINAL    = $(VERSION_NAME).exe
TARGET_PLATFORM = WIN
TARGET_RESOURCE = resources/$(VERSION_NAME).res
OBJTYPE         = win32
# Cross-arch selection for the Windows port.  win32 (i686) stays the default and
# is byte-for-byte the previous behaviour; only an x86_64-w64-mingw32 GCC_TARGET
# (set by scripts/build-win64-docker.sh) selects the 64-bit branch: amd64 PE32+,
# -m64, no MMX/yasm asm (which is x86-32-only here), matching the Linux amd64
# branch.  The native win-sdk build leaves GCC_TARGET unset and keeps x86.
ifeq ($(findstring x86_64, $(GCC_TARGET)), x86_64)
TARGET_ARCH     = amd64
BUILD_AMD64     = 1
ARCHFLAGS       = -m64
CFLAGS          += -DAMD64
else
TARGET_ARCH     = x86
ARCHFLAGS       = -m32
BUILD_MMX       = 1
endif
BUILD_SDL       = 1
BUILD_GFX       = 1
BUILD_STATIC    = 1
BUILD_SDL_IO    = 1
BUILD_OPENGL    = 1
BUILD_LOADGL    = 1
BUILD_VORBIS    = 1
BUILD_WEBM      = 1
BUILDING        = 1
YASM 	        = yasm$(EXTENSION)
CC              = $(WINDEV)/$(PREFIX)gcc$(EXTENSION)
INCLUDES        = $(SDKPATH)/include \
                  $(SDKPATH)/include/SDL2
LIBRARIES       = $(SDKPATH)/lib
ifeq ($(BUILD_WIN), 0)
BUILD_DEBUG     = 1
endif
endif


ifdef BUILD_LINUX
TARGET 	        = $(VERSION_NAME).elf
TARGET_FINAL    = $(VERSION_NAME)
TARGET_PLATFORM = LINUX
BUILD_SDL       = 1
BUILD_GFX       = 1
BUILD_PTHREAD   = 1
BUILD_SDL_IO    = 1
BUILD_OPENGL    = 1
BUILD_LOADGL    = 1
BUILD_VORBIS    = 1
BUILD_WEBM      = 1
BUILDING        = 1
YASM 	        = yasm
CC  	        = $(LNXDEV)/$(PREFIX)gcc
OBJTYPE         = elf
INCLUDES        = $(SDKPATH)/include
ifeq ($(findstring aarch64, $(GCC_TARGET)), aarch64)
# ARM64 (aarch64-linux-gnu).  "aarch64" contains the substring "64", so this
# branch MUST be tested before the findstring-64 amd64 check below, otherwise
# it is misdetected as amd64 and gets x86-only -m64 / yasm.  No MMX asm, no
# -DAMD64; libraries live in the Debian multiarch dir $(SDKPATH)/lib/<triple>.
TARGET_ARCH     = arm64
LIBRARIES       = $(SDKPATH)/lib/$(GCC_TARGET)
else ifeq ($(findstring 64, $(GCC_TARGET)), 64)
TARGET_ARCH     = amd64
BUILD_AMD64     = 1
ARCHFLAGS       = -m64
LIBRARIES       = $(SDKPATH)/lib/$(GCC_TARGET)
CFLAGS          += -DAMD64
else
TARGET_ARCH     = x86
ARCHFLAGS       = -m32
LIBRARIES       = $(SDKPATH)/lib32
BUILD_MMX       = 1
endif
ifeq ($(BUILD_LINUX), 0)
BUILD_DEBUG     = 1
endif
endif

ifdef BUILD_DARWIN
TARGET          = $(VERSION_NAME).elf
TARGET_FINAL    = $(VERSION_NAME)
TARGET_PLATFORM = DARWIN
BUILD_SDL       = 1
BUILD_GFX       = 1
BUILD_LINUX     = 1
BUILD_PTHREAD   = 1
BUILD_SDL_IO    = 1
BUILD_OPENGL    = 1
BUILD_LOADGL    = 1
BUILD_VORBIS    = 1
BUILDING        = 1
YASM            = yasm
CC              = $(PREFIX)clang
OBJTYPE         = macho
INCLUDES        = $(DWNDEV)/include \
                  $(DWNDEV)/include/SDL2
LIBRARIES       = $(DWNDEV)/lib
# sdl/video.h unconditionally #includes "yuv.h" (in source/webmlib), but Darwin
# does not enable BUILD_WEBM, so add the header search path without pulling in
# the webm objects / libvpx dependency.  "mac" provides a malloc.h shim for the
# glibc-only  #include <malloc.h> used by several engine sources.
INCS            += source/webmlib mac
# clang defaults to the host arch (arm64-apple-darwin); keep ARCHFLAGS empty
# so the universal build works on both Apple Silicon and Intel without -arch.
TARGET_ARCH     = arm64
ifeq ($(BUILD_DARWIN), 0)
BUILD_DEBUG     = 1
endif
endif

ifdef BUILD_PANDORA
TARGET 	        = $(VERSION_NAME).elf
TARGET_FINAL    = $(VERSION_NAME)
TARGET_PLATFORM = PANDORA
BUILD_LINUX     = 1
BUILD_SDL       = 1
BUILD_GFX       = 1
BUILD_PTHREAD   = 1
BUILD_SDL_IO    = 1
BUILD_TREMOR    = 1
BUILDING        = 1
CC  	        = $(PNDDEV)/bin/arm-none-linux-gnueabi-gcc
INCLUDES        = $(PNDDEV)/include \
                  $(PNDDEV)/include/SDL
OBJTYPE         = elf
LIBRARIES       = $(PNDDEV)/lib
ifeq ($(BUILD_PANDORA), 0)
BUILD_DEBUG     = 1
endif
endif

ifdef BUILD_WII
TARGET 	        = $(VERSION_NAME).elf
TARGET_MAP      = $(TARGET).map
TARGET_FINAL    = boot.dol
TARGET_PLATFORM = WII
BUILD_TREMOR    = 1
BUILD_WEBM      = 1
BUILD_ELM       = 1
BUILDING        = 1
INCLUDES        = $(DEVKITPRO)/portlibs/ppc/include \
                  $(DEVKITPRO)/libogc/include
LIBRARIES       = $(DEVKITPRO)/portlibs/ppc/lib \
                  $(DEVKITPRO)/libogc/lib/wii
ifeq ($(BUILD_WII), 0)
BUILD_DEBUG     = 1
endif
endif

ifdef BUILD_VITA
TARGET 	        = $(VERSION_NAME).elf
TARGET_FINAL    = $(VERSION_NAME).vpk
TITLE_ID        = OPENBOR30
TARGET_PLATFORM = VITA
CC  	        = arm-vita-eabi-gcc
BUILD_TREMOR    = 1
BUILDING        = 1
ifeq ($(BUILD_VITA), 0)
BUILD_DEBUG     = 1
endif
endif


STRIP           = cp $(TARGET) $(TARGET_FINAL)
ifndef BUILD_DEBUG
ifndef NO_STRIP
ifdef BUILD_WIN
STRIP 	        = $(WINDEV)/$(PREFIX)strip$(EXTENSION) $(TARGET) -o $(TARGET_FINAL)
endif
ifdef BUILD_LINUX
STRIP 	        = $(LNXDEV)/$(PREFIX)strip $(TARGET) -o $(TARGET_FINAL)
endif
ifdef BUILD_DARWIN
STRIP           = $(PREFIX)strip $(TARGET) -o $(TARGET_FINAL)
endif
ifdef BUILD_PANDORA
STRIP 	        = $(PNDDEV)/bin/arm-none-linux-gnueabi-strip $(TARGET) -o $(TARGET_FINAL)
endif
ifdef BUILD_WII
STRIP           = elf2dol $< $@
endif
endif
endif


#----------------------------------------------------------------------------------------------------
# Directories
#----------------------------------------------------------------------------------------------------

ifdef BUILD_PSP
INCS           += psp
endif


ifdef BUILD_WII
INCS           += wii
endif


ifdef BUILD_VITA
INCS           += vita
endif


ifdef BUILD_SDL
INCS           += sdl
endif


ifdef BUILD_LINUX
INCS           += 'libpng-config --prefix'/include/libpng
endif


INCS 	       += .                                                                                 \
                  source                                                                            \
                  source/adpcmlib                                                                   \
                  source/gamelib                                                                    \
                  source/preprocessorlib                                                            \
                  source/ramlib                                                                     \
                  source/randlib                                                                    \
                  source/scriptlib                                                                  \
                  source/openborscript                                                              \
                  source/pnglib                                                                     \


ifdef BUILD_GFX
INCS 	       += source/gfxlib
endif

ifdef BUILD_WEBM
INCS 	       += source/webmlib
endif

INCS += $(INCLUDES)

#----------------------------------------------------------------------------------------------------
# Objects
#----------------------------------------------------------------------------------------------------

ADPCM 	        = source/adpcmlib/adpcm.o

ifdef BUILD_GFX
GFX 	        = source/gfxlib/2xSaI.o                                                             \
                  source/gfxlib/bilinear.o                                                          \
                  source/gfxlib/dotmatrix.o                                                         \
                  source/gfxlib/gfx.o                                                               \
                  source/gfxlib/hq2x.o                                                              \
                  source/gfxlib/scale2x.o                                                           \
                  source/gfxlib/scanline.o                                                          \
                  source/gfxlib/simple2x.o                                                          \
                  source/gfxlib/tv2x.o
endif

ifdef BUILD_MMX
GFX 	       += source/gfxlib/2xSaImmx.o                                                          \
                  source/gfxlib/bilinearmmx.o                                                       \
                  source/gfxlib/hq2x16mmx.o
endif

GAME	        = source/gamelib/draw.o                                                             \
                  source/gamelib/draw16.o                                                           \
                  source/gamelib/draw32.o                                                           \
                  source/gamelib/font.o                                                             \
                  source/gamelib/translation.o                                                             \
                  source/gamelib/anigif.o                                                           \
                  source/gamelib/bitmap.o 	                                                        \
                  source/gamelib/screen.o                                                           \
                  source/gamelib/screen16.o                                                         \
                  source/gamelib/screen32.o                                                         \
                  source/gamelib/loadimg.o                                                          \
                  source/gamelib/palette.o                                                          \
                  source/gamelib/packfile.o                                                         \
                  source/gamelib/filecache.o                                                        \
                  source/gamelib/pixelformat.o                                                      \
                  source/gamelib/soundmix.o                                                         \
                  source/gamelib/spriteq.o                                                          \
                  source/gamelib/sprite.o                                                          \
                  source/gamelib/spritex8p16.o                                                      \
                  source/gamelib/spritex8p32.o                                                      \
                  source/gamelib/models.o                                                           \
                  source/gamelib/transform.o
SCRIPT          = source/scriptlib/StackedSymbolTable.o                                             \
                  source/scriptlib/ScriptVariant.o                                                  \
                  source/scriptlib/SymbolTable.o                                                    \
                  source/scriptlib/Instruction.o                                                    \
                  source/scriptlib/Interpreter.o                                                    \
                  source/scriptlib/ImportCache.o                                                    \
                  source/scriptlib/ParserSet.o                                                      \
                  source/scriptlib/Parser.o                                                         \
                  source/scriptlib/Lexer.o                                                          \
                  source/scriptlib/Stack.o                                                          \
                  source/scriptlib/List.o                                                           \
                  source/preprocessorlib/pp_lexer.o                                                 \
                  source/preprocessorlib/pp_parser.o                                                \
                  source/preprocessorlib/pp_expr.o
SCRIPT_BUILTINS = source/openborscript/commands.o                                                   \
				  source/openborscript/animation.o                                                  \
				  source/openborscript/axis.o                                           			\
				  source/openborscript/binding.o                                           			\
                  source/openborscript/collision_attack.o                                           \
                  source/openborscript/collision_body.o                                             \
				  source/openborscript/collision_entity.o                                           \
                  source/openborscript/constants.o                                                  \
                  source/openborscript/energy_status.o                                             	\
                  source/openborscript/entity.o                                                   	\
                  source/openborscript/index.o                                                      \
                  source/openborscript/layer.o                                                      \
                  source/openborscript/level.o                                                      \
                  source/openborscript/math.o                                                       \
                  source/openborscript/string.o
RAM             = source/ramlib/ram.o
RAND	        = source/randlib/rand32.o
PNG             = source/pnglib/pngdec.o                                                            \
                  source/pnglib/savepng.o
SOURCE	        = source/stringptr.o                                                                \
				  source/utils.o                                                                    \
                  source/stristr.o																	\
                  source/omath.o



ifdef BUILD_PSP
GAME_CONSOLE    = psp/control/control.o                                                             \
                  psp/dvemgr/dvemgr.o                                                               \
                  psp/kernel/kernel.o                                                               \
                  psp/graphics.o                                                                    \
                  psp/audiodrv.o                                                                    \
                  psp/sblaster.o                                                                    \
                  psp/control.o                                                                     \
                  psp/vertex.o                                                                      \
                  psp/timer.o                                                                       \
                  psp/video.o                                                                       \
                  psp/image.o                                                                       \
                  psp/menu.o                                                                        \
                  psp/pspport.o
endif


ifdef BUILD_WII
GAME_CONSOLE    = wii/control.o                                                                     \
                  wii/sblaster.o                                                                    \
                  wii/timer.o                                                                       \
                  wii/video.o                                                                       \
                  wii/threads.o                                                                     \
                  wii/menu.o                                                                        \
                  wii/wiiport.o
endif

ifdef BUILD_VITA
GAME_CONSOLE    = vita/control.o                                                                     \
                  vita/sblaster.o                                                                    \
                  vita/timer.o                                                                       \
                  vita/video.o                                                                       \
                  vita/vitaport.o                                                                    \
                  vita/menu.o
endif


ifdef BUILD_SDL
GAME	       += source/gamelib/filters.o
endif



ifdef BUILD_SDL_IO
GAME_CONSOLE   += sdl/joysticks.o                                                                   \
                  sdl/control.o                                                                     \
                  sdl/sblaster.o                                                                    \
                  sdl/timer.o                                                                       \
                  sdl/sdlport.o                                                                     \
                  sdl/video.o                                                                       \
                  sdl/videocommon.o                                                                 \
				  sdl/threads.o                                                                     \
                  sdl/menu.o
endif


ifdef BUILD_OPENGL
GAME_CONSOLE   += sdl/opengl.o
endif


ifdef BUILD_LOADGL
GAME_CONSOLE   += sdl/loadgl.o
endif


ifdef BUILD_WEBM
WEBM 	       += source/webmlib/vidplay.o                                                          \
                  source/webmlib/vorbis.o                                                           \
				  source/webmlib/samplecvt.o                                                        \
                  source/webmlib/yuv.o                                                              \
				  source/webmlib/halloc/halloc.o                                                    \
				  source/webmlib/nestegg/nestegg.o
endif


MAIN            = openbor.o					                                                \
                  openborscript.o

OBJS            = $(MAIN)                                                                           \
                  $(GAME_CONSOLE)                                                                   \
                  $(ADPCM)                                                                          \
                  $(GFX)                                                                            \
                  $(GAME)                                                                           \
                  $(SOURCE)                                                                         \
                  $(SCRIPT)                                                                         \
                  $(SCRIPT_BUILTINS)                                                                \
                  $(RAM)                                                                            \
                  $(RAND)                                                                           \
                  $(PNG)                                                                            \
                  $(WEBM)


#----------------------------------------------------------------------------------------------------
# Compiler Flags
#----------------------------------------------------------------------------------------------------

CFLAGS 	       += $(addprefix -I", $(addsuffix ", $(INCS))) $(ARCHFLAGS) -D$(TARGET_PLATFORM)
CFLAGS 	       += -g -Wall -Werror -fsigned-char -std=gnu99

# PSP/VITA: 现代交叉工具链(GCC15)对 2014 移植代码的严格性放宽 + 平台专有符号映射。
# 排在全局 -Werror 之后，仅这两平台生效，Linux/Win 不受影响。
#   -Wno-error: 兜底把其余 warning 降级(现代 GCC 下 2014 代码告警极多)
#   -fcommon: 老式裸定义全局变量, 现代 GCC 默认 -fno-common 会 multiple definition
#   -Wno-error=implicit-function-declaration: GCC14+ 默认升为硬 error, 需退回 warning
ifdef BUILD_PSP
CFLAGS	   += -Wno-error -fcommon -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Dstricmp=strcasecmp -Dstrnicmp=strncasecmp
endif
ifdef BUILD_VITA
CFLAGS	   += -Wno-error -fcommon -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Dstricmp=strcasecmp -Dstrnicmp=strncasecmp
endif


ifndef BUILD_DARWIN
ifdef BUILD_LINUX
CFLAGS         += -Wno-unused-result `pkg-config sdl2 --cflags`
endif
endif

ifndef BUILD_DEBUG
CFLAGS 	       += -O2
CFLAGS 	       += -fno-ident
ifndef BUILD_DARWIN
# GCC-only pass; clang (Apple toolchain) rejects -freorder-blocks even under -Werror.
CFLAGS         += -freorder-blocks
endif
ifndef BUILD_AMD64
CFLAGS         += -fomit-frame-pointer
endif
else
CFLAGS 	       += -DDEBUG -O0
ifdef NO_RAM_DEBUGGER
CFLAGS         += -DNO_RAM_DEBUGGER
endif
endif


ifdef BUILD_PSP
CFLAGS         += -G0
endif


ifdef BUILD_SDL
CFLAGS 	       += -DSDL=1
endif


ifdef BUILD_DARWIN
CFLAGS 	       += -DLINUX -isysroot $(SDKPATH)
# Apple clang (21.x, macOS 26 SDK) is far stricter than the GCC this 2014 port
# was written against; new diagnostics are promoted to errors by -Werror.
# Relax them for the Darwin build only, mirroring the PSP/Vita GCC15 gate.
CFLAGS 	       += -Wno-error -Wno-error=deprecated-non-prototype \
                  -Wno-error=implicit-enum-enum-cast -Wno-error=unused-but-set-variable \
                  -Wno-error=gnu-folding-constant -Wno-error=implicit-int-conversion \
                  -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -fcommon
endif


ifdef BUILD_PANDORA
CFLAGS         += -DLINUX
endif


ifdef BUILD_WII
CFLAGS 	       += -DCACHE_BACKGROUNDS -DREVERSE_COLOR -D__ppc__ $(MACHDEP) -Wl,-Map,$(TARGET_MAP),-wrap,wiiuse_register
endif


ifdef BUILD_VITA
CFLAGS 	       += -DCACHE_BACKGROUNDS -Wl,-q
endif


ifdef BUILD_MMX
CFLAGS 	       += -DMMX
endif


ifdef BUILD_VORBIS
CFLAGS         += -DOV_EXCLUDE_STATIC_CALLBACKS
endif


ifdef BUILD_TREMOR
CFLAGS         += -DTREMOR
endif


ifdef BUILD_OPENGL
CFLAGS         += -DOPENGL
endif


ifdef BUILD_LOADGL
CFLAGS         += -DLOADGL
endif


ifdef BUILD_GLES
CFLAGS         += -DGLES
endif


ifdef BUILD_VERBOSE
CFLAGS         += -DVERBOSE
endif


ifdef BUILD_WEBM
CFLAGS 	       += -DWEBM
endif


CXXFLAGS        = $(CFLAGS) -fno-exceptions -fno-rtti
ASFLAGS         = $(CFLAGS)

#----------------------------------------------------------------------------------------------------
# Library
#----------------------------------------------------------------------------------------------------

LIBS            = $(addprefix -L", $(addsuffix ", $(LIBRARIES)))


ifdef BUILD_PSP
LIBS 	       += -lpspgu -lpspaudio -lpsppower -lpsprtc
endif


ifdef BUILD_DARWIN
LIBS           += -Wl,-syslibroot,$(SDKPATH) \
                  -headerpad_max_install_names \
                  -framework Cocoa \
                  -framework OpenGL \
                  -framework AudioUnit \
                  -framework IOKit \
                  -lSDL2main
endif


ifdef BUILD_SDL
ifeq ($(findstring DGE, $(SDKPATH)), DGE)
LIBS           += -lSDL -lSDL_gfx -lts
else
LIBS           += -Wl,-rpath,$(LIBRARIES) -lSDL2 -lSDL2_gfx
endif
endif


ifdef BUILD_WIN
LIBS           += -lpsapi -lopengl32 -lwinmm -lole32 -loleaut32 -luuid -limm32 -lversion -mwindows
endif


ifdef BUILD_PTHREAD
LIBS           += -lpthread
endif


ifdef BUILD_WII
LIBS           += -lwupc -lwiiuse -lbte -lfat -lasnd -logc
endif


ifdef BUILD_VITA
LIBS           += -lvita2d -lSceAppMgr_stub -lSceDisplay_stub -lSceGxm_stub \
	              -lSceSysmodule_stub -lSceCtrl_stub -lScePgf_stub \
	              -lSceCommonDialog_stub -lSceAudio_stub -lfreetype -ljpeg
endif


ifdef BUILD_STATIC
LIBS           += -static
endif


ifdef BUILD_VORBIS
LIBS           += -lvorbisfile -lvorbis -logg
endif


ifdef BUILD_TREMOR
LIBS           += -lvorbisidec -logg
endif


ifdef BUILD_WEBM
LIBS           += -lvpx
endif


LIBS           += -lpng -lz -lm

# Windows x64 (x86_64-w64-mingw32) static link adds two system libs the 32-bit
# win-sdk build never needed: -lsetupapi (SDL2 2.30 hidapi in libSDL2) and
# -lwinpthread (winpthreads for libvpx threading).  These satisfy symbols from
# libs placed earlier in LIBS, so they must come last (left-to-right link).
# The 32-bit i686 path (GCC_TARGET=i686-w64-mingw32) is unaffected.
ifeq ($(findstring x86_64, $(GCC_TARGET)), x86_64)
LIBS           += -lsetupapi -lwinpthread
endif

#----------------------------------------------------------------------------------------------------
# Rules to manage Files and Libraries for PSP
#----------------------------------------------------------------------------------------------------

ifdef BUILD_PSP
%.o : %.c
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(CC) $(CFLAGS) -c $< -o $@
%.o : %.S
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(CC) $(CFLAGS) -c $< -o $@
INCDIR          = $(INCS)
PSP_EBOOT_TITLE = $(VERSION_NAME) $(VERSION)
PSP_EBOOT_ICON 	= resources/OpenBOR_Icon_144x80.png
PSP_EBOOT_PIC1	= resources/OpenBOR_Logo_480x272.png
PSP_FW_VERSION  = 371
PSP_LARGE_MEMORY= 1
BUILD_PRX       = 1
include psp/build.mak
endif



#----------------------------------------------------------------------------------------------------
# Rules to manage Files and Libraries for SDL
#----------------------------------------------------------------------------------------------------

ifdef BUILD_SDL
all : $(TARGET) $(TARGET_FINAL)
	@echo
%.o : %.asm
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(YASM) -D $(TARGET_PLATFORM) -f $(OBJTYPE) -m $(TARGET_ARCH) -o $@ $<
%.o : %.c
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(CC) $(CFLAGS) -c $< -o $@
$(TARGET) : $(OBJS) $(RES)
	@echo
	@echo Linking $(TARGET_PLATFORM) Port: $(TARGET)...
	@$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(TARGET_RESOURCE) $(LIBS)
$(TARGET_FINAL) : $(TARGET)
	@echo Stripping $(TARGET_PLATFORM) Port: $(TARGET_FINAL)...
	@$(STRIP)
	@echo
	@echo Completed $(TARGET_PLATFORM) Port!
	@echo $(TARGET_FINAL) is now ready!
endif

#----------------------------------------------------------------------------------------------------
# Rules to manage Files and Libraries for Wii
#----------------------------------------------------------------------------------------------------

ifdef BUILD_WII
SOURCES = $(INCS)
include $(DEVKITPPC)/wii_rules
all : $(TARGET) $(TARGET_FINAL)
	@echo
%.o : %.c
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(CC) $(CFLAGS) -c $< -o $@
$(TARGET) : $(OBJS) $(RES)
	@echo
	@echo Linking $(TARGET_PLATFORM) Port: $(TARGET)...
	@$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(TARGET_RESOURCE) $(LIBS)
$(TARGET_FINAL) : $(TARGET)
	@echo Stripping $(TARGET_PLATFORM) Port: $(TARGET_FINAL)...
	@$(STRIP)
	@echo
	@echo Completed $(TARGET_PLATFORM) Port!
	@echo $(TARGET_FINAL) is now ready!
endif

#----------------------------------------------------------------------------------------------------
# Rules to manage Files and Libraries for Vita
#----------------------------------------------------------------------------------------------------

ifdef BUILD_VITA
all : OpenBOR.vpk
	@echo
%.o : %.c
	@echo Compiling $(TARGET_PLATFORM) Port: $<...
	@$(CC) $(CFLAGS) -c $< -o $@
OpenBOR.elf : $(OBJS) $(RES)
	@echo
	@echo Linking $(TARGET_PLATFORM) Port: $(TARGET)...
	@$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(TARGET_RESOURCE) $(LIBS)
%.velf: %.elf
	vita-elf-create $< $@
eboot.bin: $(VERSION_NAME).velf
	vita-make-fself -s $< $@
OpenBOR.vpk: eboot.bin
	@echo Stripping $(TARGET_PLATFORM) Port: $(TARGET_FINAL)...
	vita-mksfoex -s TITLE_ID=$(TITLE_ID) "OpenBOR" param.sfo
	vita-pack-vpk -s param.sfo -b eboot.bin --add resources/vita_icon.png=sce_sys/icon0.png $@
	@echo
	@echo Completed $(TARGET_PLATFORM) Port!
	@echo $(TARGET_FINAL) is now ready!
endif


#----------------------------------------------------------------------------------------------------
# Rules to CleanUp Files for All Platforms
#----------------------------------------------------------------------------------------------------

ifndef BUILDING
all:
	@echo
	@echo Build A TARGET_PLATFORM:
	@echo
	@echo make BUILD_PSP=1
	@echo make BUILD_PS2=1
	@echo make BUILD_WII=1
	@echo make BUILD_WIN=1
	@echo make BUILD_PANDORA=1
	@echo make BUILD_LINUX=1
	@echo
	@echo Cleanup Intermediate Files:
	@echo
	@echo make clean
	@echo
	@echo Remove All Files:
	@echo
	@echo make clean-all
	@echo
endif


ifndef BUILD_PSP
clean-all: clean-releases clean

clean-releases:
	@rm -rf releases/*

clean:
	@echo
	@echo "Removing All $(TARGET_PLATFORM) Files..."
	@rm -f $(TARGET) $(TARGET_FINAL) $(TARGET_MAP) PARAM.SFO param.sfo eboot.bin OpenBOR.velf linkmap $(OBJS)
	@echo Done!
	@echo
endif

version:
	@echo "-------------------------------------------------------"
	@echo "OpenBOR $(VERSION) - http://www.ChronoCrash.com"
	@echo
	@echo "All rights reserved."
	@echo "See LICENSE and README within OpenBOR root for details."
	@echo
	@echo "Copyright (c) 2004 - 2018 OpenBOR Team"
	@echo "-------------------------------------------------------"

