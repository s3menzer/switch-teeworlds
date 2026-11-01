#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${WINDOWS_DOCKER_IMAGE:-teeworlds-windows-builder:latest}"

if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
	ENGINE="$CONTAINER_ENGINE"
elif command -v podman >/dev/null 2>&1; then
	# Prefer Podman when it is installed. On the self-hosted runner the
	# docker command is the podman-docker compatibility wrapper and may try
	# to use the unavailable Docker socket.
	ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
	ENGINE="docker"
else
	echo "[ERROR] Neither podman nor docker was found." >&2
	exit 2
fi

if [[ "${1:-}" == "clean-image" ]]; then
	"$ENGINE" image rm "$IMAGE" || true
	exit 0
fi

if [[ "${IMAGE_PULL:-0}" == "1" ]]; then
	# The builder image is local, so this is intentionally only useful when
	# an external registry is configured through WINDOWS_DOCKER_IMAGE.
	"$ENGINE" pull "$IMAGE"
fi

if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
	echo "Building Windows builder image: ${IMAGE}"
	"$ENGINE" build --tag "$IMAGE" \
		--file "${SCRIPT_DIR}/Dockerfile.windows" "${SCRIPT_DIR}"
fi

VOLUME_SUFFIX="${CONTAINER_VOLUME_SUFFIX:-}"
if [[ -z "$VOLUME_SUFFIX" && "$(basename "$ENGINE")" == podman* ]]; then
	VOLUME_SUFFIX=":Z"
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
	TTY_ARGS+=(-it)
fi

exec "$ENGINE" run --rm "${TTY_ARGS[@]}" \
	-e BUILD_DIR="${BUILD_DIR:-build-windows}" \
	-e BUILD_TYPE="${BUILD_TYPE:-Release}" \
	-e JOBS="${JOBS:-}" \
	-v "${SCRIPT_DIR}:/workspace${VOLUME_SUFFIX}" \
	-w /workspace \
	"$IMAGE" \
	bash -lc '
		set -euo pipefail
		cmake -S . -B "${BUILD_DIR:-build-windows}" \
			-G Ninja \
			-DCMAKE_BUILD_TYPE="${BUILD_TYPE:-Release}" \
			-DCMAKE_TOOLCHAIN_FILE="$PWD/cmake/toolchains/mingw64.toolchain" \
			-DCLIENT=ON \
			-DDOWNLOAD_DEPENDENCIES=ON \
			-DDOWNLOAD_GTEST=OFF \
			-DPREFER_BUNDLED_LIBS=ON
		cmake --build "${BUILD_DIR:-build-windows}" \
			--parallel "${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
		cmake --build "${BUILD_DIR:-build-windows}" --target package_default
	' \
	docker-build-windows
