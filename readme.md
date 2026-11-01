# Teeworlds

This repository contains the Teeworlds Nintendo Switch port and the
supporting build scripts.

## Get the source

```bash
git clone --recurse-submodules git@github.com:s3menzer/switch-teeworlds.git
cd switch-teeworlds

# For an existing checkout:
git submodule sync --recursive
git submodule update --init --recursive
```

## Build overview

| Target          | Native build             | Docker build                |
| --------------- | ------------------------ | --------------------------- |
| Linux           | `./build-linux.sh`       | `./docker-build-linux.sh`   |
| AArch64 server  | `./build-aarch64.sh`     | `./docker-build-aarch64.sh` |
| Windows         | MSYS2 instructions below | `./docker-build-windows.sh` |
| Nintendo Switch | —                        | `./docker-build-switch.sh`  |

All scripts use `Release` builds by default. Set `BUILD_TYPE`, `BUILD_DIR`,
`JOBS`, or `CLIENT` to customize a build.

## Linux

### Native Linux build

Install the dependencies:

```bash
sudo apt install \
  build-essential cmake git python3 pkg-config \
  libfreetype6-dev libsdl2-dev libssl-dev \
  libgl1-mesa-dev libx11-dev libxext-dev libxfixes-dev zlib1g-dev
```

Build the client and server:

```bash
./build-linux.sh
```

The output is placed in `build-linux/`.

Useful commands:

```bash
./build-linux.sh clean
CLIENT=OFF ./build-linux.sh       # server only
BUILD_TYPE=Debug ./build-linux.sh
```

Run the result:

```bash
cd build-linux
./teeworlds
./teeworlds_srv
```

### Linux Docker build

Docker or Podman is required. The script builds `Dockerfile.linux`
automatically when the image is missing:

```bash
./docker-build-linux.sh
```

The result is written to `build-linux/` on the host.

## AArch64 server

### Native AArch64 build

Use this on a 64-bit Raspberry Pi or another AArch64 Linux system:

```bash
./build-aarch64.sh
```

This builds the server only and writes it to:

```text
build-aarch64/teeworlds_srv
```

Run it from the build directory so the bundled data is found:

```bash
cd build-aarch64
./teeworlds_srv
```

### AArch64 Docker build

Use this on an x86-64 host to cross-compile the Raspberry Pi server:

```bash
./docker-build-aarch64.sh
```

The image is built from `Dockerfile.aarch64` if necessary. The generated
binary is `build-aarch64/teeworlds_srv`.

If Podman reports a user/group or `setgroups` error, try:

```bash
CONTAINER_USE_HOST_USER=0 ./docker-build-aarch64.sh
```

## Windows with MSYS2

Install MSYS2, then open the **MSYS2 MinGW 64-bit** shell and install:

```bash
pacman -Syu
pacman -S --needed \
  git python mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-freetype mingw-w64-x86_64-SDL2 \
  mingw-w64-x86_64-zlib
```

Configure and build:

```bash
cmake -S . -B build-windows-msys2 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/mingw64.toolchain \
  -DCMAKE_BUILD_TYPE=Release \
  -DDOWNLOAD_DEPENDENCIES=OFF \
  -DDOWNLOAD_GTEST=OFF \
  -DPREFER_BUNDLED_LIBS=OFF

cmake --build build-windows-msys2 --parallel
```

The executable is generated in `build-windows-msys2/`.

### Windows Docker cross-build

On a Linux host, the same MinGW build used by CI can be run with:

```bash
./docker-build-windows.sh
```

The script builds `Dockerfile.windows` automatically when its image is
missing and writes the release package to `build-windows/`.

## Nintendo Switch

The Switch build uses the devkitPro Docker image:

```bash
./docker-build-switch.sh
```

The image is not pulled by default. To pull it:

```bash
IMAGE_PULL=1 ./docker-build-switch.sh
```

To avoid incrementing the Switch build number:

```bash
AUTO_BUILD_NUMBER=0 ./docker-build-switch.sh
```

The build creates:

```text
build-switch/teeworlds.nro  # updater/launcher started by hbmenu
build-switch/game.nro       # actual game
manifests.json              # updater manifest
```

Static game data is embedded into both NROs through RomFS. No external
`data/` directory is needed on the SD card.

The SD card layout is:

```text
/switch/teeworlds/teeworlds.nro
/switch/teeworlds/game.nro
/switch/teeworlds/settings07.cfg
```

The launcher downloads `manifests.json`, updates files in place, and
chain-loads `game.nro`. The launcher itself can only be replaced on the next
invocation because it is currently running.

### Upload to the update server

Configure the rsync destination if required:

```bash
export RSYNC_TARGET=pi:/var/www/html/switch/teeworlds
./rsync-upload.sh
```

The script uploads both NROs, `settings07.cfg`, and `manifests.json`.

### Launch through nxlink

Close the running game, then run:

```bash
./deploy-switch-docker.sh 192.168.22.202
```

The default target on the Switch is `teeworlds/teeworlds.nro`. Nxlink output
is saved to `teeworlds-nxlink.log`.

For diagnostics, set this in `settings07.cfg`:

```text
debug 1
```

The application log is written to `teeworlds.txt` next to the launched NRO.

## Runtime configuration

The default Switch server address is:

```text
192.168.22.7:8303
```

## License

This software is provided “as-is”, without any express or implied warranty.
See `license.txt` for the complete license text.

Originally written by Magnus Auvinen.
