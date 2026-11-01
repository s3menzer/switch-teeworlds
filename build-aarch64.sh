#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BUILD_DIR="${BUILD_DIR:-build-aarch64}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
HOST_ARCH="$(uname -m)"

if [[ "${1:-}" == "clean" ]]; then
	rm -rf -- "$BUILD_DIR"
	exit 0
fi

for tool in cmake python3; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "Required build tool not found: ${tool}" >&2
		exit 4
	fi
done

# Do not silently produce an x86 binary when this script is run on a desktop.
# Cross compilation is still possible by supplying a toolchain file or both
# cross compilers explicitly.
if [[ "$HOST_ARCH" != "aarch64" && "$HOST_ARCH" != "arm64" &&
	-z "${CMAKE_TOOLCHAIN_FILE:-}" &&
	( -z "${CC:-}" || -z "${CXX:-}" ) ]]; then
	echo "This script must run on a 64-bit ARM system (aarch64) or be given a cross toolchain." >&2
	echo "On a Raspberry Pi, verify with: uname -m" >&2
	echo "For cross compilation, set CMAKE_TOOLCHAIN_FILE, CC, and CXX." >&2
	exit 4
fi

declare -a CMAKE_ARGS=(
	"-DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
	"-DCLIENT=ON"
	"-DDOWNLOAD_DEPENDENCIES=OFF"
	"-DDOWNLOAD_GTEST=OFF"
	"-DPREFER_BUNDLED_LIBS=OFF"
)

# The script is intended to run natively on an aarch64 Raspberry Pi. A
# toolchain file or compilers can still be supplied for cross compilation.
if [[ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]]; then
	CMAKE_ARGS+=("-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
fi
if [[ -n "${CC:-}" ]]; then
	CMAKE_ARGS+=("-DCMAKE_C_COMPILER=${CC}")
fi
if [[ -n "${CXX:-}" ]]; then
	CMAKE_ARGS+=("-DCMAKE_CXX_COMPILER=${CXX}")
fi

cmake -S . -B "$BUILD_DIR" "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR" \
	--target teeworlds.elf teeworlds_srv \
	--parallel "$JOBS"

SERVER_BINARY="${BUILD_DIR}/teeworlds_srv"
CLIENT_BINARY="${BUILD_DIR}/teeworlds.elf"
if command -v file >/dev/null 2>&1; then
	BINARY_DESCRIPTION="$(file -b "$SERVER_BINARY")"
	if [[ "$BINARY_DESCRIPTION" != *"aarch64"* && "$BINARY_DESCRIPTION" != *"AArch64"* ]]; then
		echo "The generated server is not an AArch64 binary:" >&2
		echo "  ${BINARY_DESCRIPTION}" >&2
		echo "Build it on a 64-bit Raspberry Pi or provide an AArch64 cross toolchain." >&2
		exit 5
	fi
	BINARY_DESCRIPTION="$(file -b "$CLIENT_BINARY")"
	if [[ "$BINARY_DESCRIPTION" != *"aarch64"* && "$BINARY_DESCRIPTION" != *"AArch64"* ]]; then
		echo "The generated client is not an AArch64 binary:" >&2
		echo "  ${BINARY_DESCRIPTION}" >&2
		echo "Build it on a 64-bit Raspberry Pi or provide an AArch64 cross toolchain." >&2
		exit 5
	fi
fi

if [[ "$BUILD_DIR" == /* ]]; then
	BUILD_PATH="$BUILD_DIR"
else
	BUILD_PATH="${PWD}/${BUILD_DIR}"
fi

echo
echo "Built: ${BUILD_PATH}/teeworlds.elf"
echo "Built: ${BUILD_PATH}/teeworlds_srv"
echo "Run from the build directory so the bundled data directory is found:"
echo "  cd ${BUILD_PATH} && ./teeworlds_srv"
