#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${DEVKITPRO_DOCKER_IMAGE:-docker.io/devkitpro/devkita64:latest}"

if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
	ENGINE="$CONTAINER_ENGINE"
elif command -v docker >/dev/null 2>&1; then
	ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
	ENGINE="podman"
else
	echo "[ERROR] Neither docker nor podman was found." >&2
	exit 2
fi

echo "Using container engine: ${ENGINE}"
echo "Using image: ${IMAGE}"
echo "Using project: ${SCRIPT_DIR}"

if [[ "${SKIP_IMAGE_PULL:-0}" != "1" ]]; then
	"$ENGINE" pull "$IMAGE"
fi

VOLUME_SUFFIX="${CONTAINER_VOLUME_SUFFIX:-}"
if [[ -z "$VOLUME_SUFFIX" && "$(basename "$ENGINE")" == podman* ]]; then
	VOLUME_SUFFIX=":Z"
fi

CONTAINER_AUTO_BUILD_NUMBER="${AUTO_BUILD_NUMBER:-1}"
if [[ "${SKIP_BUILD_INCREMENT:-0}" == "1" ]]; then
	CONTAINER_AUTO_BUILD_NUMBER=0
fi

USER_ARGS=()
if [[ "${CONTAINER_USE_HOST_USER:-0}" == "1" ]]; then
	USER_ARGS+=(--user "$(id -u):$(id -g)")
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
	TTY_ARGS+=(-it)
fi

exec "$ENGINE" run --rm "${TTY_ARGS[@]}" \
	"${USER_ARGS[@]}" \
	-e DEVKITPRO=/opt/devkitpro \
	-e DEVKITA64=/opt/devkitpro/devkitA64 \
	-e LIBNX=/opt/devkitpro/libnx \
	-e PORTLIBS=/opt/devkitpro/portlibs \
	-e INSTALL_SWITCH_HARFBUZZ="${INSTALL_SWITCH_HARFBUZZ:-1}" \
	-e AUTO_BUILD_NUMBER="$CONTAINER_AUTO_BUILD_NUMBER" \
	-e BUILD_DIR="${BUILD_DIR:-build-switch}" \
	-e BUILD_TYPE="${BUILD_TYPE:-Release}" \
	-e JOBS="${JOBS:-}" \
	-v "${SCRIPT_DIR}:/workspace${VOLUME_SUFFIX}" \
	-w /workspace \
	"$IMAGE" \
	bash -lc \
	'export PATH="$DEVKITA64/bin:$DEVKITPRO/tools/bin:$DEVKITPRO/pacman/bin:$DEVKITPRO/portlibs/switch/bin:$PATH";
	if [[ "${INSTALL_SWITCH_HARFBUZZ:-1}" == "1" ]] &&
		{ [[ ! -f "$PORTLIBS/lib/libharfbuzz.a" ]] ||
		  [[ ! -f "$PORTLIBS/include/harfbuzz/hb.h" ]]; }; then
		echo "Installing switch-harfbuzz in the container...";
		dkp-pacman -S --needed --noconfirm switch-harfbuzz;
	fi;
	./build-switch.sh "$@"' \
	docker-build \
	"$@"
