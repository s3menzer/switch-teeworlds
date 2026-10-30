$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$env:DEVKITPRO = 'D:/games/Switch/devkit/devkitPro'
$env:DEVKITA64 = Join-Path $env:DEVKITPRO 'devkitA64'

$BuildDir = if ([string]::IsNullOrEmpty($env:BUILD_DIR)) { 'build-switch' } else { $env:BUILD_DIR }
$BuildType = if ([string]::IsNullOrEmpty($env:BUILD_TYPE)) { 'Release' } else { $env:BUILD_TYPE }
$AutoBuildNumber = if ([string]::IsNullOrEmpty($env:AUTO_BUILD_NUMBER)) { '1' } else { $env:AUTO_BUILD_NUMBER }
if ($env:SKIP_BUILD_INCREMENT -eq '1') {
  $AutoBuildNumber = '0'
}

$VersionFile = Join-Path $ScriptDir 'src/switch/version.hpp'
$VersionBackup = $null
$CurrentBuild = $null

if ($args.Count -gt 0 -and $args[0] -eq 'clean') {
  if (Test-Path (Join-Path $BuildDir 'CMakeCache.txt')) {
    & 'D:/tools/CMake/bin/cmake.exe' --build $BuildDir --target clean
    if ($LASTEXITCODE -ne 0) {
      Write-Warning 'The clean target failed; continuing with manifest cleanup.'
    }
  }
  Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ScriptDir 'teeworlds.xml')
  exit 0
}

if ($AutoBuildNumber -ne '0') {
  $VersionContents = [System.IO.File]::ReadAllText($VersionFile)
  $BuildMatch = [regex]::Match(
    $VersionContents,
    '(?m)^#define TEEWORLDS_SWITCH_BUILD_NUMBER\s+([0-9]+)\s*$'
  )
  if (-not $BuildMatch.Success) {
    throw "Invalid TEEWORLDS_SWITCH_BUILD_NUMBER in $VersionFile"
  }

  $CurrentBuild = [long]::Parse(
    $BuildMatch.Groups[1].Value,
    [System.Globalization.CultureInfo]::InvariantCulture
  )
  $NextBuild = $CurrentBuild + 1
  $VersionBackup = [System.IO.Path]::GetTempFileName()
  Copy-Item -Force $VersionFile $VersionBackup

  $UpdatedVersionContents = [regex]::Replace(
    $VersionContents,
    '(?m)^#define TEEWORLDS_SWITCH_BUILD_NUMBER\s+[0-9]+\s*$',
    "#define TEEWORLDS_SWITCH_BUILD_NUMBER $NextBuild"
  )
  [System.IO.File]::WriteAllText(
    $VersionFile,
    $UpdatedVersionContents,
    [System.Text.UTF8Encoding]::new($false)
  )
  Write-Host "Incremented Teeworlds Switch build number: $CurrentBuild -> $NextBuild"
}

try {
  $ToolchainFile = Join-Path $ScriptDir 'devkita64-libnx.cmake'
  & 'D:/tools/CMake/bin/cmake.exe' -S $ScriptDir -B $BuildDir -G Ninja `
    -DCMAKE_MAKE_PROGRAM=D:/tools/ninja.exe `
    -DCMAKE_BUILD_TYPE=$BuildType `
    -DCMAKE_TOOLCHAIN_FILE=$ToolchainFile `
    -DCLIENT=ON `
    -DDOWNLOAD_DEPENDENCIES=OFF `
    -DDOWNLOAD_GTEST=OFF `
    -DPREFER_BUNDLED_LIBS=ON
  if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed with exit code $LASTEXITCODE"
  }

  & 'D:/tools/CMake/bin/cmake.exe' --build $BuildDir --target teeworlds.nro --parallel 8
  if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
  }

  $NroPath = Join-Path $BuildDir 'teeworlds.nro'
  if (Test-Path $NroPath) {
    $GameVersionContents = [System.IO.File]::ReadAllText(
      (Join-Path $ScriptDir 'src/game/version.h')
    )
    $GameVersionMatch = [regex]::Match(
      $GameVersionContents,
      '(?m)^#define GAME_VERSION\s+"([^"]+)"'
    )
    if (-not $GameVersionMatch.Success) {
      throw 'Could not determine GAME_VERSION.'
    }

    $BuildMatch = [regex]::Match(
      [System.IO.File]::ReadAllText($VersionFile),
      '(?m)^#define TEEWORLDS_SWITCH_BUILD_NUMBER\s+([0-9]+)\s*$'
    )
    if (-not $BuildMatch.Success) {
      throw 'Could not determine TEEWORLDS_SWITCH_BUILD_NUMBER.'
    }

    $ManifestUrl = if ([string]::IsNullOrEmpty($env:TEEWORLDS_MANIFEST_URL)) {
      'http://192.168.22.7/switch/teeworlds/teeworlds.xml'
    } else {
      $env:TEEWORLDS_MANIFEST_URL
    }
    $DownloadUrl = if ([string]::IsNullOrEmpty($env:TEEWORLDS_DOWNLOAD_URL)) {
      'http://192.168.22.7/switch/teeworlds/teeworlds.nro'
    } else {
      $env:TEEWORLDS_DOWNLOAD_URL
    }
    $DataUrlBase = if ([string]::IsNullOrEmpty($env:TEEWORLDS_DATA_URL_BASE)) {
      $DownloadUrl.Substring(0, $DownloadUrl.LastIndexOf('/'))
    } else {
      $env:TEEWORLDS_DATA_URL_BASE.TrimEnd('/')
    }

    $ManifestPath = Join-Path $ScriptDir 'teeworlds.xml'
    $ManifestTool = Join-Path $ScriptDir 'src/updater/scripts/create_manifest.py'
    $Python = if ([string]::IsNullOrEmpty($env:PYTHON)) { 'python' } else { $env:PYTHON }
    $SettingsPath = Join-Path $ScriptDir 'settings07.cfg'
    $ManifestArguments = @(
      '--output', $ManifestPath,
      '--name', 'teeworlds',
      '--platform', 'switch',
      '--version', $GameVersionMatch.Groups[1].Value,
      '--build', $BuildMatch.Groups[1].Value,
      '--file', 'teeworlds.nro', $DownloadUrl, $NroPath,
      '--file', 'settings07.cfg', "$DataUrlBase/settings07.cfg", $SettingsPath
    )
    & $Python $ManifestTool @ManifestArguments
    if ($LASTEXITCODE -ne 0) {
      throw 'Could not generate the update manifest.'
    }

    Write-Host 'Generated update manifest:'
    Write-Host "  $ManifestPath"
    Write-Host "  manifest URL: $ManifestUrl"
  }
}
catch {
  if ($null -ne $VersionBackup) {
    Copy-Item -Force $VersionBackup $VersionFile
    Remove-Item -Force -ErrorAction SilentlyContinue $VersionBackup
    Write-Error "Build failed; restored build $CurrentBuild."
  }
  throw
}
finally {
  if ($null -ne $VersionBackup -and (Test-Path $VersionBackup)) {
    Remove-Item -Force $VersionBackup
  }
}
