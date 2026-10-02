#!/usr/bin/env bash
#
# setup_toolchain_macos.sh
#
# Sets up the development environment for meriBoot on macOS.
#
# Apple's bundled clang/gcc no longer supports `-m32 -ffreestanding` bare-metal
# builds, so this script installs a dedicated i386-elf cross-compiler via
# Homebrew instead of relying on the system compiler.
#
# Installed packages (via Homebrew):
#   - nasm              -> Assembly compiler (boot.asm, bios_calls.asm, gdt_flush.asm)
#   - i386-elf-binutils -> Cross linker/assembler tools (ld, objcopy, ...)
#   - i386-elf-gcc      -> Freestanding 32-bit C cross-compiler for stage2
#   - make              -> Build automation tool
#   - qemu              -> Emulator to run and test compiled OS images
#
# Usage:
#   chmod +x tools/setup_toolchain_macos.sh
#   ./tools/setup_toolchain_macos.sh

set -euo pipefail

log()  { printf '\033[1;32m[setup]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[warning]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2; }

# --- 1) Platform Check -----------------------------------------------------

if [ "$(uname -s)" != "Darwin" ]; then
    err "This script is intended for macOS only. Use tools/setup_toolchain.sh on Linux."
    exit 1
fi

# --- 2) Xcode Command Line Tools -------------------------------------------

if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools not found. Triggering installation..."
    xcode-select --install || true
    err "Re-run this script after the Xcode Command Line Tools installation finishes."
    exit 1
fi

# --- 3) Homebrew Check -------------------------------------------------------

if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is required but was not found."
    err "Install it from https://brew.sh and re-run this script."
    exit 1
fi

log "Detected Homebrew: $(command -v brew)"

# --- 4) Tap + Package Installation ------------------------------------------

CROSS_TAP="nativeos/i386-elf-toolchain"

log "Updating Homebrew..."
brew update >/dev/null

if ! brew tap | grep -qx "$CROSS_TAP"; then
    log "Adding tap for i386-elf cross-compiler: $CROSS_TAP"
    brew tap "$CROSS_TAP"
fi

install_formula() {
    local formula="$1"
    if brew list --formula "$formula" >/dev/null 2>&1; then
        log "$formula is already installed."
    else
        log "Installing $formula..."
        brew install "$formula"
    fi
}

install_formula "nasm"
install_formula "qemu"
install_formula "make"
install_formula "i386-elf-binutils"
install_formula "i386-elf-gcc"

# --- 5) Verification ---------------------------------------------------------

log "Verifying installed tools..."

MISSING=0
check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  [OK] %-18s -> %s\n' "$name" "$(command -v "$cmd")"
    else
        printf '  [MISSING] %-18s -> not found\n' "$name"
        MISSING=1
    fi
}

check_tool "nasm"           "nasm"
check_tool "i386-elf-gcc"   "i386-elf-gcc"
check_tool "i386-elf-ld"    "i386-elf-ld"
check_tool "qemu"           "qemu-system-x86_64"

# Homebrew's `make` is installed as `gmake` to avoid clobbering the
# Xcode-provided `/usr/bin/make`; either is fine for this project.
if command -v gmake >/dev/null 2>&1; then
    printf '  [OK] %-18s -> %s\n' "make (gmake)" "$(command -v gmake)"
elif command -v make >/dev/null 2>&1; then
    printf '  [OK] %-18s -> %s\n' "make" "$(command -v make)"
else
    printf '  [MISSING] %-18s -> not found\n' "make"
    MISSING=1
fi

if [ "${MISSING:-0}" -eq 1 ]; then
    err "Some required tools are missing. Check the output above."
    err "Homebrew keg-only formulas (i386-elf-gcc, i386-elf-binutils) may need:"
    err "  export PATH=\"\$(brew --prefix i386-elf-gcc)/bin:\$(brew --prefix i386-elf-binutils)/bin:\$PATH\""
    exit 1
fi

log "Testing i386-elf-gcc -ffreestanding support..."
if echo 'int main(void){return 0;}' | i386-elf-gcc -ffreestanding -x c -c -o /tmp/meriboot_m32_test.o - 2>/dev/null; then
    log "  [OK] i386-elf-gcc -ffreestanding works."
    rm -f /tmp/meriboot_m32_test.o
else
    err "  [FAILED] i386-elf-gcc -ffreestanding test failed."
    exit 1
fi

log "Environment setup completed. You can now build with 'make' and test using qemu-system-x86_64."
log "Note: this project's build will need CC=i386-elf-gcc and LD=i386-elf-ld on macOS."
