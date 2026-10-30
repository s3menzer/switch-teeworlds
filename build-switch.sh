#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

: "${DEVKITPRO:?DEVKITPRO must be set (use docker-build-switch.sh)}"
: "${DEVKITA64:?DEVKITA64 must be set (use docker-build-switch.sh)}"

BUILD_DIR="${BUILD_DIR:-build-switch}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
AUTO_BUILD_NUMBER="${AUTO_BUILD_NUMBER:-1}"
INSTALL_SWITCH_HARFBUZZ="${INSTALL_SWITCH_HARFBUZZ:-1}"
VERSION_FILE="src/switch/version.hpp"
VERSION_BACKUP=""

if [[ "${1:-}" == "clean" ]]; then
	if [[ -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
		cmake --build "$BUILD_DIR" --target clean || true
	fi
	rm -f teeworlds.xml
	exit 0
fi

if [[ "$INSTALL_SWITCH_HARFBUZZ" == "1" &&
	! -f "$DEVKITPRO/portlibs/switch/lib/libharfbuzz.a" ]]; then
	if [[ "$(id -u)" != "0" ]]; then
		echo "[ERROR] HarfBuzz is missing and package installation requires root." >&2
		echo "Run without CONTAINER_USE_HOST_USER=1 or set up switch-harfbuzz in the image." >&2
		exit 4
	fi
	PACMAN="$(command -v dkp-pacman || command -v pacman || true)"
	if [[ -z "$PACMAN" ]]; then
		echo "[ERROR] Could not find dkp-pacman or pacman to install switch-harfbuzz." >&2
		exit 4
	fi
	echo "Installing missing switch-harfbuzz package..."
	"$PACMAN" -S --noconfirm --needed switch-harfbuzz
fi

for tool in cmake elf2nro nacptool; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "Required Switch build tool not found: ${tool}" >&2
		exit 4
	fi
done

if [[ "$AUTO_BUILD_NUMBER" != "0" ]]; then
	CURRENT_BUILD="$(sed -n \
		's/^#define TEEWORLDS_SWITCH_BUILD_NUMBER[[:space:]]*\([0-9][0-9]*\)$/\1/p' \
		"$VERSION_FILE")"

	if [[ ! "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
		echo "Invalid TEEWORLDS_SWITCH_BUILD_NUMBER: ${CURRENT_BUILD}" >&2
		exit 3
	fi

	NEXT_BUILD=$((10#$CURRENT_BUILD + 1))
	VERSION_BACKUP="$(mktemp)"
	cp "$VERSION_FILE" "$VERSION_BACKUP"
	sed -i -E \
		"s/^#define TEEWORLDS_SWITCH_BUILD_NUMBER[[:space:]].*/#define TEEWORLDS_SWITCH_BUILD_NUMBER ${NEXT_BUILD}/" \
		"$VERSION_FILE"
	echo "Incremented Teeworlds Switch build number: ${CURRENT_BUILD} -> ${NEXT_BUILD}"
fi

restore_version_on_failure()
{
	if [[ -n "$VERSION_BACKUP" ]]; then
		cp "$VERSION_BACKUP" "$VERSION_FILE"
		rm -f "$VERSION_BACKUP"
		echo "Build failed; restored build ${CURRENT_BUILD}." >&2
	fi
}

trap restore_version_on_failure ERR

cmake -S . -B "$BUILD_DIR" \
	-DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
	-DCMAKE_TOOLCHAIN_FILE="$PWD/devkita64-libnx.cmake" \
	-DCLIENT=ON \
	-DDOWNLOAD_DEPENDENCIES=OFF \
	-DDOWNLOAD_GTEST=OFF \
	-DPREFER_BUNDLED_LIBS=ON

cmake --build "$BUILD_DIR" \
	--target teeworlds.nro \
	--parallel "${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

trap - ERR
if [[ -n "$VERSION_BACKUP" ]]; then
	rm -f "$VERSION_BACKUP"
fi

if [[ -f "${BUILD_DIR}/teeworlds.nro" ]]; then
	VERSION="$(sed -n \
		's/^#define GAME_VERSION[[:space:]]*"\([^"]*\)"/\1/p' \
		src/game/version.h)"
	BUILD_NUMBER="$(sed -n \
		's/^#define TEEWORLDS_SWITCH_BUILD_NUMBER[[:space:]]*\([0-9][0-9]*\)$/\1/p' \
		"$VERSION_FILE")"
	MANIFEST_URL="${TEEWORLDS_MANIFEST_URL:-http://192.168.22.7/switch/teeworlds/teeworlds.xml}"
	DOWNLOAD_URL="${TEEWORLDS_DOWNLOAD_URL:-http://192.168.22.7/switch/teeworlds/teeworlds.nro}"
	DATA_URL_BASE="${TEEWORLDS_DATA_URL_BASE:-${DOWNLOAD_URL%/*}}"

	MANIFEST_TOOL="src/updater/scripts/create_manifest.py"
	PYTHON="${PYTHON:-python3}"
	"$PYTHON" "$MANIFEST_TOOL" \
		--output teeworlds.xml \
		--name teeworlds \
		--platform switch \
		--version "$VERSION" \
		--build "$BUILD_NUMBER" \
		--file teeworlds.nro "$DOWNLOAD_URL" "${BUILD_DIR}/teeworlds.nro" \
		--file settings07.cfg "${DATA_URL_BASE%/}/settings07.cfg" settings07.cfg

	echo "Generated update manifest:"
	echo "  ${PWD}/teeworlds.xml"
	echo "  manifest URL: ${MANIFEST_URL}"
fi
