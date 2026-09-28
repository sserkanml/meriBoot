@echo off
echo [setup] Setting up WSL2 (Ubuntu) development environment...

:: Check if WSL is installed
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo [setup] Installing WSL (Ubuntu)...
    wsl --install
    echo [setup] Please restart your computer to complete WSL installation, then run this script again.
    pause
    exit /b 0
)

:: Execute the Linux setup script directly inside WSL
echo [setup] Running tools/setup-toolchain.sh inside WSL...
wsl bash -c "chmod +x ./tools/setup-toolchain.sh && ./tools/setup-toolchain.sh"

pause