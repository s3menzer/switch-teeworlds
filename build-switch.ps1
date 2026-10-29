$env:DEVKITPRO = 'D:/games/Switch/devkit/devkitPro'
& 'D:/tools/CMake/bin/cmake.exe' -S . -B build-switch -G Ninja `
  -DCMAKE_MAKE_PROGRAM=D:/tools/ninja.exe `
  -DCMAKE_TOOLCHAIN_FILE=D:/projects/switch-teeworlds/devkita64-libnx.cmake
& 'D:/tools/CMake/bin/cmake.exe' --build build-switch --target teeworlds.nro --parallel 8