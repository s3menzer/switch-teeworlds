@echo off
setlocal

rem Use Ninja + clang-cl in the MSVC environment; bundled zlib is x86.
for %%I in ("%~dp0.") do set "ROOT=%%~fI"
set "BUILD_ROOT=%ROOT%\build-windows"
set "BUILD_DIR=%BUILD_ROOT%\ninja-clang-win32"
set "PYTHON=%ROOT%\.venv\Scripts\python.exe"
set "ZLIB_DIR=%ROOT%\thirdParty\zlib-1.2.3-lib"
set "ZLIB_LIB=%ZLIB_DIR%\lib\zlib.lib"
set "SDL_DIR=%ROOT%\thirdParty\SDL-install"
set "SDL_LIB=%SDL_DIR%\lib\SDL2.lib"
set "SDL_INCLUDE=%SDL_DIR%\include\SDL2"
set "VSDEVCMD=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
set "CLANG_CL=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Tools\Llvm\bin\clang-cl.exe"
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
if not exist "%ZLIB_DIR%\include\zlib.h" (
    echo ERROR: zlib headers not found under "%ZLIB_DIR%\include"
    goto :input_error
)
if not exist "%ZLIB_LIB%" (
    echo ERROR: zlib import library not found: "%ZLIB_LIB%"
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
if not exist "%CLANG_CL%" (
    echo ERROR: clang-cl not found: "%CLANG_CL%"
    goto :input_error
)
if not exist "%NINJA%" (
    echo ERROR: Ninja not found: "%NINJA%"
    goto :input_error
)

call "%VSDEVCMD%" -arch=x86 -host_arch=x64 >nul
if errorlevel 1 goto :vs_error
for /f "delims=" %%L in ('where link.exe') do if not defined MSVC_LINK set "MSVC_LINK=%%L"
if not exist "%MSVC_LINK%" goto :vs_error

cmake -S .. -B ninja-clang-win32 -G Ninja ^
    "-DCMAKE_MAKE_PROGRAM:FILEPATH=%NINJA%" ^
    "-DCMAKE_C_COMPILER:FILEPATH=%CLANG_CL%" ^
    "-DCMAKE_CXX_COMPILER:FILEPATH=%CLANG_CL%" ^
    "-DCMAKE_LINKER:FILEPATH=%MSVC_LINK%" ^
    "-DCMAKE_BUILD_TYPE:STRING=Release" ^
    "-DPYTHON_EXECUTABLE:FILEPATH=%PYTHON%" ^
    "-DCLIENT_EXECUTABLE:STRING=teeworlds" ^
    "-DDOWNLOAD_DEPENDENCIES:BOOL=ON" ^
    "-DDOWNLOAD_GTEST:BOOL=OFF" ^
    "-DZLIB_INCLUDE_DIR:PATH=%ZLIB_DIR%\include" ^
    "-DZLIB_LIBRARY_RELEASE:FILEPATH=%ZLIB_LIB%" ^
    "-DZLIB_LIBRARY_DEBUG:FILEPATH=%ZLIB_LIB%" ^
    "-DSDL2_LIBRARY:FILEPATH=%SDL_LIB%" ^
    "-DSDL2_INCLUDEDIR:PATH=%SDL_INCLUDE%"
if errorlevel 1 goto :cmake_error

cmake --build ninja-clang-win32 --parallel
if errorlevel 1 goto :build_error

echo.
echo Ninja + clang-cl build succeeded:
echo   "%BUILD_DIR%"
echo Copy SDL2.dll and zlib1.dll beside the game executable before running it.
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
