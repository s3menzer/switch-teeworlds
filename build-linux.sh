#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p build-linux
cd build-linux
cmake .. -DCMAKE_TOOLCHAIN_FILE=../devkita64-libnx.cmake
make -j"$(nproc)" 
