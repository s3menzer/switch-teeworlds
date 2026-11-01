set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)
set(CMAKE_ASM_COMPILER /usr/bin/aarch64-linux-gnu-as)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)

set(CMAKE_FIND_ROOT_PATH
	/usr/aarch64-linux-gnu
	/usr/lib/gcc-cross/aarch64-linux-gnu
	/usr/lib/aarch64-linux-gnu
	/usr/include/aarch64-linux-gnu
	/
)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Debian installs the multiarch zlib development files below
# /usr/lib/aarch64-linux-gnu while the common headers remain in /usr/include.
if(EXISTS "/usr/lib/aarch64-linux-gnu/libz.so")
	set(ZLIB_LIBRARY "/usr/lib/aarch64-linux-gnu/libz.so" CACHE FILEPATH "AArch64 zlib library" FORCE)
endif()
if(EXISTS "/usr/include/zlib.h")
	set(ZLIB_INCLUDE_DIR "/usr/include" CACHE PATH "AArch64 zlib headers" FORCE)
endif()

# The cross-compiling find rules do not reliably discover Debian's
# multiarch Freetype installation under /usr/include/freetype2.
if(EXISTS "/usr/lib/aarch64-linux-gnu/libfreetype.so")
	set(FREETYPE_LIBRARY "/usr/lib/aarch64-linux-gnu/libfreetype.so"
		CACHE FILEPATH "AArch64 Freetype library" FORCE)
endif()
if(EXISTS "/usr/include/freetype2/freetype/config/ftheader.h")
	set(FREETYPE_INCLUDEDIR "/usr/include/freetype2"
		CACHE PATH "AArch64 Freetype headers" FORCE)
endif()
