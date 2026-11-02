@echo off
setlocal

rem Use Ninja + clang-cl in the MSVC environment for a 32-bit Windows build.
for %%I in ("%~dp0.") do set "ROOT=%%~fI"
set "BUILD_ROOT=%ROOT%\build-windows"
set "BUILD_DIR=%BUILD_ROOT%\ninja-clang-x86"
set "PYTHON=%ROOT%\.venv\Scripts\python.exe"
set "ZLIB_ARCHIVE=%ROOT%\thirdParty\zlib.tar.gz"
set "SDL_DIR=%ROOT%\thirdParty\SDL-install"
set "SDL_LIB=%SDL_DIR%\lib\SDL2.lib"
set "SDL_INCLUDE=%SDL_DIR%\include\SDL2"
set "CLANG_TOOLCHAIN=%ROOT%\cmake\toolchains\clang-cl-x86.toolchain"
set "VSDEVCMD=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
set "TEEWORLDS_CLANG_CL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Tools\Llvm\x64\bin\clang-cl.exe"
set "NINJA=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"

if not exist "%BUILD_ROOT%\" (
    mkdir "%BUILD_ROOT%"
    if errorlevel 1 exit /b 1
)
pushd "%BUILD_ROOT%" || exit /b 1

if not exist "%PYTHON%" (
    echo ERROR: Python virtual environment not found: "%PYTHON%"
    goto :input_error
)
if not exist "%ZLIB_ARCHIVE%" (
    echo ERROR: zlib source archive not found: "%ZLIB_ARCHIVE%"
    goto :input_error
)
if not exist "%SDL_DIR%\include\SDL2\SDL.h" (
    echo ERROR: SDL2 headers not found under "%SDL_INCLUDE%"
    goto :input_error
)
if not exist "%SDL_LIB%" (
    echo ERROR: SDL2 import library not found: "%SDL_LIB%"
    goto :input_error
)
if not exist "%VSDEVCMD%" (
    echo ERROR: Visual Studio developer environment script not found: "%VSDEVCMD%"
    goto :input_error
)
if not exist "%TEEWORLDS_CLANG_CL%" (
    echo ERROR: clang-cl not found: "%TEEWORLDS_CLANG_CL%"
    goto :input_error
)
if not exist "%NINJA%" (
    echo ERROR: Ninja not found: "%NINJA%"
    goto :input_error
)
if not exist "%CLANG_TOOLCHAIN%" (
    echo ERROR: clang-cl x86 toolchain file not found: "%CLANG_TOOLCHAIN%"
    goto :input_error
)

call "%VSDEVCMD%" -arch=x86 -host_arch=x64 >nul
if errorlevel 1 goto :vs_error
if not defined VCToolsInstallDir goto :vs_error
if not defined WindowsSdkDir goto :vs_error
if not defined WindowsSDKVersion goto :vs_error
set "LIB=%VCToolsInstallDir%lib\x86;%WindowsSdkDir%Lib\%WindowsSDKVersion%ucrt\x86;%WindowsSdkDir%Lib\%WindowsSDKVersion%um\x86;%LIB%"
if not exist "%WindowsSdkDir%Lib\%WindowsSDKVersion%um\x86\WS2_32.Lib" goto :vs_error
set "DUMPBIN=%VCToolsInstallDir%bin\Hostx64\x86\dumpbin.exe"
if not exist "%DUMPBIN%" goto :vs_error
for /f "delims=" %%L in ('where link.exe') do if not defined MSVC_LINK set "MSVC_LINK=%%L"
if not exist "%MSVC_LINK%" goto :vs_error

cmake -S .. -B "%BUILD_DIR%" -G Ninja ^
    "-DCMAKE_MAKE_PROGRAM:FILEPATH=%NINJA%" ^
    "-DCMAKE_TOOLCHAIN_FILE:FILEPATH=%CLANG_TOOLCHAIN%" ^
    "-DCMAKE_C_COMPILER:FILEPATH=%TEEWORLDS_CLANG_CL%" ^
    "-DCMAKE_CXX_COMPILER:FILEPATH=%TEEWORLDS_CLANG_CL%" ^
    "-DCMAKE_LINKER:FILEPATH=%MSVC_LINK%" ^
    "-DCMAKE_BUILD_TYPE:STRING=Release" ^
    "-DPYTHON_EXECUTABLE:FILEPATH=%PYTHON%" ^
    "-DCLIENT_EXECUTABLE:STRING=teeworlds" ^
    "-DDOWNLOAD_DEPENDENCIES:BOOL=ON" ^
    "-DDOWNLOAD_GTEST:BOOL=OFF" ^
    "-DSDL2_LIBRARY:FILEPATH=%SDL_LIB%" ^
    "-DSDL2_INCLUDEDIR:PATH=%SDL_INCLUDE%"
if errorlevel 1 goto :cmake_error

cmake --build "%BUILD_DIR%" --parallel
if errorlevel 1 goto :build_error

"%DUMPBIN%" /nologo /dependents "%BUILD_DIR%\teeworlds.exe" | findstr /I /C:"zlib1.dll" >nul
if not errorlevel 1 (
    echo ERROR: teeworlds.exe still depends on zlib1.dll.
    echo The Windows build compiles zlib from thirdParty\zlib.tar.gz as a static library.
    popd
    exit /b 1
)

echo.
echo Ninja + clang-cl build succeeded:
echo   "%BUILD_DIR%"
echo SDL2.dll and freetype.dll must remain beside the game executable.
popd
exit /b 0

:input_error
popd
exit /b 1

:cmake_error
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:vs_error
echo ERROR: Failed to initialize the Visual Studio x86 build environment.
popd
exit /b 1

:build_error
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
