#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${DEVKITPRO_DOCKER_IMAGE:-docker.io/devkitpro/devkita64:latest}"
ENGINE="${CONTAINER_ENGINE:-}"
SWITCH_IP="${SWITCH_IP:-${1:-}}"
NRO_PATH="${NRO_PATH:-${2:-build-switch/teeworlds.nro}}"
SWITCH_NRO_PATH="${SWITCH_NRO_PATH:-${3:-teeworlds/teeworlds.nro}}"
LOG_FILE="${NXLINK_LOG_FILE:-teeworlds-nxlink.log}"
SKIP_IMAGE_PULL="${SKIP_IMAGE_PULL:-1}"

if [[ -z "$SWITCH_IP" ]]; then
	echo "Usage: SWITCH_IP=192.168.22.202 $0 [switch-ip] [nro-path] [switch-nro-path]" >&2
	exit 2
fi

if [[ "$NRO_PATH" = /* ]]; then
	HOST_NRO_PATH="$NRO_PATH"
	RELATIVE_NRO_PATH="$(realpath --relative-to="$SCRIPT_DIR" "$NRO_PATH")"
	if [[ "$RELATIVE_NRO_PATH" = ../* || "$RELATIVE_NRO_PATH" == ".." ]]; then
		echo "[ERROR] NRO must be inside the project directory: ${NRO_PATH}" >&2
		exit 3
	fi
	CONTAINER_NRO_PATH="/workspace/${RELATIVE_NRO_PATH}"
else
	HOST_NRO_PATH="${SCRIPT_DIR}/${NRO_PATH}"
	CONTAINER_NRO_PATH="/workspace/${NRO_PATH}"
fi

if [[ ! -f "$HOST_NRO_PATH" ]]; then
	echo "[ERROR] NRO not found: ${HOST_NRO_PATH}" >&2
	echo "Build it first with ./docker-build.sh." >&2
	exit 3
fi

if [[ -z "$ENGINE" ]]; then
	if command -v docker >/dev/null 2>&1; then
		ENGINE=docker
	elif command -v podman >/dev/null 2>&1; then
		ENGINE=podman
	else
		echo "[ERROR] Neither docker nor podman was found." >&2
		exit 2
	fi
fi

if [[ "$SKIP_IMAGE_PULL" != "1" ]]; then
	"$ENGINE" pull "$IMAGE"
fi

VOLUME_SUFFIX="${CONTAINER_VOLUME_SUFFIX:-}"
if [[ -z "$VOLUME_SUFFIX" && "$(basename "$ENGINE")" == podman* ]]; then
	VOLUME_SUFFIX=":Z"
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
	TTY_ARGS+=(-it)
fi

CONTAINER_NAME="${NXLINK_CONTAINER_NAME:-teeworlds-nxlink-$$}"

stop_nxlink() {
	local status="${1:-130}"
	trap - INT TERM
	# nxlink -s can keep the container attached to the Switch stdio
	# connection. Force-remove the container so Ctrl+C always terminates it.
	"$ENGINE" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
	exit "$status"
}

trap 'stop_nxlink 130' INT TERM

echo "Launching ${NRO_PATH} on Switch ${SWITCH_IP} as ${SWITCH_NRO_PATH}"
echo "Saving nxlink output to ${SCRIPT_DIR}/${LOG_FILE}"

set +e
"$ENGINE" run --rm "${TTY_ARGS[@]}" \
	--name "$CONTAINER_NAME" \
	--network "${CONTAINER_NETWORK:-host}" \
	-e DEVKITPRO=/opt/devkitpro \
	-e DEVKITA64=/opt/devkitpro/devkitA64 \
	-e LIBNX=/opt/devkitpro/libnx \
	-e PORTLIBS=/opt/devkitpro/portlibs \
	-v "${SCRIPT_DIR}:/workspace:ro${VOLUME_SUFFIX}" \
	-w /workspace \
	"$IMAGE" \
	bash -lc \
	'export PATH="$DEVKITA64/bin:$DEVKITPRO/tools/bin:$DEVKITPRO/portlibs/switch/bin:$PATH";
	exec nxlink -s -a "$1" -p "$3" "$2"' \
	nxlink "$SWITCH_IP" "$CONTAINER_NRO_PATH" "$SWITCH_NRO_PATH" 2>&1 | tee "${SCRIPT_DIR}/${LOG_FILE}"
STATUS=${PIPESTATUS[0]}
set -e
trap - INT TERM

exit "$STATUS"
