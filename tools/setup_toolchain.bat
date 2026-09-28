@echo off
setlocal enabledelayedexpansion

echo [setup] Initializing Windows toolchain setup for meriBoot...

:: --- 1) Administrator Check -----------------------------------------------

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [error] Administrative privileges required.
    echo [error] Please right-click this batch file and select "Run as administrator".
    pause
    exit /b 1
)

:: --- 2) Check Winget Availability ---------------------------------------

where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo [error] 'winget' is not installed or not available in PATH.
    echo [error] Please install App Installer from Microsoft Store or update Windows.
    pause
    exit /b 1
)

:: --- 3) Package Installation Function ------------------------------------

call :InstallPackage "NASM" "NASM.NASM"
call :InstallPackage "QEMU" "qemu.qemu"
call :InstallPackage "Make" "GnuWin32.Make"
call :InstallPackage "MSYS2 (GCC & Binutils)" "MSYS2.MSYS2"

:: --- 4) Environment Setup Notice ----------------------------------------

echo.
echo [setup] Toolchain installation completed.
echo [warning] Important notes for Windows environment:
echo   1. Restart your terminal or command prompt for PATH changes to take effect.
echo   2. For 32-bit C cross-compilation (-m32 -ffreestanding), using MSYS2 GCC
echo      or WSL2 (Ubuntu) is strongly recommended over standard Win32 GCC builds.
echo.
echo You can test your setup using 'make' and 'qemu-system-x86_64'.
pause
exit /b 0

:: --- Subroutine: Install Package -----------------------------------------

:InstallPackage
set "pkgName=%~1"
set "pkgId=%~2"

echo [setup] Checking %pkgName% (%pkgId%)...
winget list --exact --id %pkgId% >nul 2>&1
if %errorlevel% equ 0 (
    echo [setup] %pkgName% is already installed.
) else (
    echo [setup] Installing %pkgName%...
    winget install --exact --id %pkgId% --silent --accept-source-agreements --accept-package-agreements
    if !errorlevel! neq 0 (
        echo [error] Failed to install %pkgName%.
    )
)
exit /b 0