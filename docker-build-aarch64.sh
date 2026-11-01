#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${AARCH64_DOCKER_IMAGE:-teeworlds-aarch64-builder:latest}"
BUILD_DIR="${BUILD_DIR:-build-aarch64}"

if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
	ENGINE="$CONTAINER_ENGINE"
elif command -v podman >/dev/null 2>&1; then
	# On the self-hosted runner, docker is only the podman-docker
	# compatibility wrapper and may try to use the unavailable Docker socket.
	ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
	ENGINE="docker"
else
	echo "[ERROR] Neither docker nor podman was found." >&2
	exit 2
fi

ENGINE_COMMAND_PATH="$(command -v "$ENGINE" 2>/dev/null || true)"
ENGINE_IS_PODMAN=0
if [[ "$(basename "$ENGINE")" == podman* ]] ||
	{ [[ -n "$ENGINE_COMMAND_PATH" && -f "$ENGINE_COMMAND_PATH" ]] &&
		grep -q "podman" "$ENGINE_COMMAND_PATH"; }; then
	ENGINE_IS_PODMAN=1
fi

if [[ "${1:-}" == "clean-image" ]]; then
	"$ENGINE" image rm "$IMAGE" || true
	exit 0
fi

if [[ "${SKIP_IMAGE_BUILD:-0}" != "1" ]]; then
	echo "Building AArch64 builder image: ${IMAGE}"
	"$ENGINE" build \
		--tag "$IMAGE" \
		--file "${SCRIPT_DIR}/Dockerfile.aarch64" \
		"${SCRIPT_DIR}"
fi

if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
	echo "[ERROR] Builder image not found: ${IMAGE}" >&2
	echo "Build it first or unset SKIP_IMAGE_BUILD." >&2
	exit 3
fi

VOLUME_SUFFIX="${CONTAINER_VOLUME_SUFFIX:-}"
if [[ -z "$VOLUME_SUFFIX" && "$ENGINE_IS_PODMAN" == "1" ]]; then
	VOLUME_SUFFIX=":Z"
fi

USER_ARGS=()
if [[ "${CONTAINER_USE_HOST_USER:-1}" == "1" ]]; then
	if [[ "$ENGINE_IS_PODMAN" == "1" ]]; then
		# Rootless Podman rejects --user UID:GID on some systems with
		# "crun: setgroups: Invalid argument". keep-id preserves ownership
		# without asking crun to change supplementary groups.
		USER_ARGS+=(--userns=keep-id)
	else
		USER_ARGS+=(--user "$(id -u):$(id -g)")
	fi
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
	TTY_ARGS+=(-it)
fi

exec "$ENGINE" run --rm "${TTY_ARGS[@]}" \
	"${USER_ARGS[@]}" \
	-e BUILD_DIR="$BUILD_DIR" \
	-e BUILD_TYPE="${BUILD_TYPE:-Release}" \
	-e JOBS="${JOBS:-}" \
	-e CMAKE_TOOLCHAIN_FILE=/workspace/cmake/aarch64-linux-gnu.cmake \
	-e HOME=/tmp \
	-v "${SCRIPT_DIR}:/workspace${VOLUME_SUFFIX}" \
	-w /workspace \
	"$IMAGE" \
	bash -lc './build-aarch64.sh "$@"' \
	docker-build-aarch64 \
	"${1:-}"
