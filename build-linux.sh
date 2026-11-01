#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BUILD_DIR="${BUILD_DIR:-build-linux}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

if [[ "${1:-}" == "clean" ]]; then
	rm -rf -- "$BUILD_DIR"
	exit 0
fi

cmake -S . -B "$BUILD_DIR" \
	-DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
	-DCLIENT="${CLIENT:-ON}" \
	-DDOWNLOAD_DEPENDENCIES=OFF \
	-DDOWNLOAD_GTEST=OFF \
	-DPREFER_BUNDLED_LIBS="${PREFER_BUNDLED_LIBS:-ON}"

cmake --build "$BUILD_DIR" --parallel "$JOBS"
