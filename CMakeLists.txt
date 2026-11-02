# Copyright 2019 SwitchPy Team. All rights reserved.
# Licensed under the MIT license.
# Refer to the LICENSE file included.
#
# libnx CMake template for Nintendo Switch homebrew development.

cmake_minimum_required(VERSION 3.13)

file(STRINGS src/game/version.h VERSION_LINE
        LIMIT_COUNT 1
        REGEX GAME_RELEASE_VERSION
)

if(VERSION_LINE MATCHES "\"([0-9]+)\\.([0-9]+)\\.([0-9]+|[0-9]+\\.[0-9]+)\"")
    set(VERSION_MAJOR ${CMAKE_MATCH_1})
    set(VERSION_MINOR ${CMAKE_MATCH_2})
    set(VERSION_PATCH ${CMAKE_MATCH_3})
elseif(VERSION_LINE MATCHES "\"([0-9]+)\\.([0-9]+)\"")
    set(VERSION_MAJOR ${CMAKE_MATCH_1})
    set(VERSION_MINOR ${CMAKE_MATCH_2})
    set(VERSION_PATCH "0")
else()
    message(FATAL_ERROR "Couldn't parse version from src/game/version.h")
endif()

project(teeworlds
        VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
        LANGUAGES C CXX)

if(NOT SWITCH)
set(HOMEBREW_APP "teeworlds")
include(CMakeLists2.txt)
else()
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(options)
include(utils)

find_package(LIBNX REQUIRED)
if (NOT LIBNX_FOUND)
    cmake_panic("Unable to detect libnx on this system.")
endif ()

# === The following 3 libs are required for cURL ===
# === Add ${CURL_LIBRARIES} ${MBEDTLS_LIBRARIES} ${ZLIB_LIBRARIES} to target_link_libraries() before switch::libnx ===

# find_package(CURL REQUIRED)
# if (NOT CURL_FOUND)
#     cmake_panic("Unable to detect libcurl on this system.")
# endif ()
# find_package(ZLIB REQUIRED)
# if (NOT ZLIB_FOUND)
#     cmake_panic("Unable to detect zlib on this system.")
# endif ()
# find_package(MbedTLS REQUIRED)
# if (NOT MbedTLS_FOUND)
#     cmake_panic("Unable to detect mbedtls on this system.")
# endif ()

# === Add switch::libtwili to target_link_libraries() to link with libtwili ===

# find_package(LIBTWILI REQUIRED)
# if (NOT LIBTWILI_FOUND)
#     cmake_panic("Unable to detect libtwili on this system.")
# endif ()

include_directories(${PROJECT_BINARY_DIR} ${DEVKITPRO}/libnx/include ${PORTLIBS}/include)
link_directories(${PORTLIBS}/lib)

# The homebrew entry point is the updater/launcher. The actual game is built
# as a separate NRO and is started by the launcher after the update check.
set(HOMEBREW_APP "game")

# Meta information about the app
set(APP_TITLE "Teeworlds")
set(APP_AUTHOR "menzer")
set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/teeworld.png")


if (NOT DEFINED CMAKE_BUILD_TYPE_INIT)
    set(CMAKE_BUILD_TYPE_INIT Release)
endif ()

set(CMAKE_C_STANDARD 99)
if (USE_CPP_17)
    set(CMAKE_CXX_STANDARD 17)
else ()
    set(CMAKE_CXX_STANDARD 11)
endif ()

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    include(clang-utils)
endif ()

include(nx-utils)

cmake_info("Building ${APP_TITLE} version ${APP_VERSION}.")

include(CMakeLists2.txt)

set(APP_VERSION
        "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

find_package(Bz2)
target_link_libraries(${HOMEBREW_APP}.elf switch::bz2)

find_package(PNG)
target_link_libraries(${HOMEBREW_APP}.elf switch::png)

find_package(HarfBuzz REQUIRED)
target_link_libraries(${HOMEBREW_APP}.elf switch::harfbuzz)

find_package(EGL)
target_link_libraries(${HOMEBREW_APP}.elf switch::egl)

find_package(GLES)
target_link_libraries(${HOMEBREW_APP}.elf switch::gles)

# Mesa's EGL/GLES archives require the GL dispatch runtime as well. Some
# devkitPro CMake versions do not expose it through FindOpenGL, so provide
# the imported target explicitly when the archive is installed.
if(NOT TARGET switch::opengl)
    find_library(SWITCH_GLAPI_LIBRARY
        NAMES glapi libglapi.a
        PATHS "$ENV{PORTLIBS}/switch/lib" "${PORTLIBS}/switch/lib"
        NO_DEFAULT_PATH)
    if(SWITCH_GLAPI_LIBRARY)
        add_library(switch::opengl STATIC IMPORTED GLOBAL)
        set_target_properties(switch::opengl PROPERTIES
            IMPORTED_LOCATION "${SWITCH_GLAPI_LIBRARY}")
    endif()
endif()

if(TARGET switch::opengl)
    target_link_libraries(${HOMEBREW_APP}.elf switch::opengl)
endif()

find_package(Drm)
target_link_libraries(${HOMEBREW_APP}.elf switch::drm)

target_link_libraries(${HOMEBREW_APP}.elf switch::libnx)
set_target_properties(${HOMEBREW_APP}.elf PROPERTIES
        LINKER_LANGUAGE CXX # Replace this with C if you have C source files
        LINK_FLAGS "-specs=${LIBNX}/switch.specs -Wl,-no-as-needed -Wl,-Map,.map")

build_switch_binaries(${HOMEBREW_APP}.elf)

# Build a small launcher NRO separately. It is the file started by hbmenu
# (/switch/teeworlds/teeworlds.nro); the game itself lives in game.nro.
add_executable(teeworlds.elf
        ${SWITCH_UPDATER_LAUNCHER_SOURCE}
)
target_include_directories(teeworlds.elf PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        "${PROJECT_BINARY_DIR}/src"
)
target_compile_definitions(teeworlds.elf PRIVATE
        SWITCH_UPDATER_APPLICATION_NAME="teeworlds"
        SWITCH_UPDATER_CURRENT_VERSION="${APP_VERSION}"
        SWITCH_UPDATER_MANIFEST_URL="http://192.168.22.7/switch/teeworlds/manifests.json"
)
add_dependencies(teeworlds.elf game-shared)
target_link_libraries(teeworlds.elf
        switch-updater
        switch::libnx
)
set_target_properties(teeworlds.elf PROPERTIES
        LINKER_LANGUAGE CXX
        LINK_FLAGS "-specs=${LIBNX}/switch.specs -Wl,-no-as-needed -Wl,-Map,teeworlds.map")

set(_GAME_APP_TITLE "${APP_TITLE}")
set(_GAME_APP_AUTHOR "${APP_AUTHOR}")
set(_GAME_APP_VERSION "${APP_VERSION}")
set(_GAME_APP_ICON "${APP_ICON}")
set(APP_TITLE "Teeworlds Updater")
set(APP_AUTHOR "menzer")
set(APP_VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/teeworld.png")
build_switch_binaries(teeworlds.elf NO_ROMFS)
set(APP_TITLE "${_GAME_APP_TITLE}")
set(APP_AUTHOR "${_GAME_APP_AUTHOR}")
set(APP_VERSION "${_GAME_APP_VERSION}")
set(APP_ICON "${_GAME_APP_ICON}")
add_dependencies(teeworlds.nro game.nro)
#build_switch_sysmodule(${HOMEBREW_APP}.elf)  # build .kip
#build_switch_nsp(${HOMEBREW_APP}.elf)  # build .nsp
endif()
