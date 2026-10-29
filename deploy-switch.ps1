param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SwitchIp
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$cmake = 'D:/tools/CMake/bin/cmake.exe'
$ninja = 'D:/tools/ninja.exe'
$devkitPro = 'D:/games/Switch/devkit/devkitPro'
$nxlink = Join-Path $devkitPro 'tools/bin/nxlink.exe'
$nro = Join-Path $projectRoot 'build-switch/teeworlds.nro'

if (-not (Test-Path -LiteralPath $cmake)) { throw "CMake not found: $cmake" }
if (-not (Test-Path -LiteralPath $ninja)) { throw "Ninja not found: $ninja" }
if (-not (Test-Path -LiteralPath $nxlink)) { throw "nxlink not found: $nxlink" }

$env:DEVKITPRO = $devkitPro
& $cmake -S $projectRoot -B (Join-Path $projectRoot 'build-switch') -G Ninja `
    "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_TOOLCHAIN_FILE=$(Join-Path $projectRoot 'devkita64-libnx.cmake')"
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE" }

& $cmake --build (Join-Path $projectRoot 'build-switch') --target teeworlds.nro --parallel 8
if ($LASTEXITCODE -ne 0) { throw "Switch build failed with exit code $LASTEXITCODE" }

Write-Host "Sending $nro to $SwitchIp. Make sure Homebrew Menu Netloader is open (press Y)."
& $nxlink -s -a $SwitchIp $nro
if ($LASTEXITCODE -ne 0) { throw "nxlink failed with exit code $LASTEXITCODE" }
