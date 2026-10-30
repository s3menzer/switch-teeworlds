#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/docker-build-switch.sh"

# Upload the NRO first and the manifest second. This ordering prevents a
# client from seeing a manifest that points at an artifact not yet present on
# the server.
TARGET="${RSYNC_TARGET:-pi:/var/www/html/switch/teeworlds}"
BUILD_DIR="${BUILD_DIR:-build-switch}"

if [[ "${BUILD_DIR}" = /* ]]; then
	NRO_PATH="${BUILD_DIR}/teeworlds.nro"
	DATA_PATH="${BUILD_DIR}/data"
else
	NRO_PATH="${SCRIPT_DIR}/${BUILD_DIR}/teeworlds.nro"
	DATA_PATH="${SCRIPT_DIR}/${BUILD_DIR}/data"
fi
MANIFEST_PATH="${SCRIPT_DIR}/teeworlds.xml"
SETTINGS_PATH="${SCRIPT_DIR}/settings07.cfg"

if ! command -v rsync >/dev/null 2>&1; then
	echo "[ERROR] rsync was not found." >&2
	exit 2
fi

if [[ ! -f "${NRO_PATH}" || ! -f "${MANIFEST_PATH}" ||
	! -f "${SETTINGS_PATH}" || ! -d "${DATA_PATH}/mapres" ]]; then
	echo "[ERROR] Missing ${NRO_PATH}, ${MANIFEST_PATH}, ${SETTINGS_PATH}, or ${DATA_PATH}/mapres." >&2
	echo "Build the Switch target first with ./build.sh." >&2
	exit 3
fi

RSYNC_ARGS=(
	--archive
	--verbose
	--human-readable
	--partial
	--progress
)

echo "Uploading teeworlds.nro to ${TARGET}"
rsync "${RSYNC_ARGS[@]}" \
	"${NRO_PATH}" \
	"${TARGET}"

echo "Uploading game data to ${TARGET%/}/data/"
rsync "${RSYNC_ARGS[@]}" \
	"${DATA_PATH}/" \
	"${TARGET%/}/data/"

echo "Uploading settings07.cfg to ${TARGET}"
rsync "${RSYNC_ARGS[@]}" \
	"${SETTINGS_PATH}" \
	"${TARGET}"

echo "Uploading teeworlds.xml to ${TARGET}"
rsync "${RSYNC_ARGS[@]}" \
	"${MANIFEST_PATH}" \
	"${TARGET}"

echo "Upload complete."
