#!/usr/bin/env bash
#
# setup_toolchain_macos.sh
#
# Sets up the development environment for meriBoot on macOS.
#
# Apple's bundled clang/gcc no longer supports `-m32 -ffreestanding` bare-metal
# builds, so this script installs a dedicated x86_64-elf cross-compiler via
# Homebrew instead of relying on the system compiler. x86_64-elf-gcc is
# multilib and happily produces 32-bit freestanding code with `-m32`, so it
# serves as a drop-in replacement for the i386-elf toolchain this project's
# Makefile was written against.
#
# Installed packages (via Homebrew, all from homebrew-core, no tap needed):
#   - nasm              -> Assembly compiler (boot.asm, bios_calls.asm, gdt_flush.asm)
#   - x86_64-elf-binutils -> Cross linker/assembler tools (ld, objcopy, ...)
#   - x86_64-elf-gcc      -> Freestanding 32-bit C cross-compiler for stage2
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

# --- 4) Package Installation -------------------------------------------------
#
# x86_64-elf-gcc/binutils ship directly from homebrew-core (bottled, no tap
# required). An earlier version of this script used the third-party
# nativeos/i386-elf-toolchain tap, but its formulas have no bottle for
# current macOS/Xcode releases and fail to build from source.

log "Updating Homebrew..."
brew update >/dev/null

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
install_formula "x86_64-elf-binutils"
install_formula "x86_64-elf-gcc"

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

check_tool "nasm"               "nasm"
check_tool "x86_64-elf-gcc"     "x86_64-elf-gcc"
check_tool "x86_64-elf-ld"      "x86_64-elf-ld"
check_tool "x86_64-elf-objcopy" "x86_64-elf-objcopy"
check_tool "qemu"               "qemu-system-x86_64"

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
    err "If x86_64-elf-gcc/binutils were just installed, open a new shell"
    err "(or re-run with: eval \"\$(/opt/homebrew/bin/brew shellenv)\") so Homebrew's"
    err "shims are on PATH."
    exit 1
fi

log "Testing full build chain with the project's Makefile flags..."
log "(CFLAGS: -m32 -ffreestanding -fno-pic -c | LDFLAGS: -m elf_i386)"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/test.c" <<'EOF'
void _start(void) { for (;;) {} }
EOF

cat > "$TEST_DIR/test.ld" <<'EOF'
ENTRY(_start)
SECTIONS {
    . = 0x1000;
    .text : { *(.text) }
}
EOF

if ! x86_64-elf-gcc -m32 -ffreestanding -fno-pic -c "$TEST_DIR/test.c" -o "$TEST_DIR/test.o" 2>"$TEST_DIR/cc.log"; then
    err "  [FAILED] x86_64-elf-gcc -m32 -ffreestanding -fno-pic -c failed:"
    cat "$TEST_DIR/cc.log" >&2
    exit 1
fi
log "  [OK] x86_64-elf-gcc compile step works."

if ! x86_64-elf-ld -m elf_i386 -T "$TEST_DIR/test.ld" "$TEST_DIR/test.o" -o "$TEST_DIR/test.elf" 2>"$TEST_DIR/ld.log"; then
    err "  [FAILED] x86_64-elf-ld -m elf_i386 link step failed:"
    cat "$TEST_DIR/ld.log" >&2
    exit 1
fi
log "  [OK] x86_64-elf-ld link step works."

if ! x86_64-elf-objcopy -O binary "$TEST_DIR/test.elf" "$TEST_DIR/test.bin" 2>"$TEST_DIR/objcopy.log"; then
    err "  [FAILED] x86_64-elf-objcopy -O binary step failed:"
    cat "$TEST_DIR/objcopy.log" >&2
    exit 1
fi
log "  [OK] x86_64-elf-objcopy step works."

log "Environment setup completed. You can now test using qemu-system-x86_64."
log ""
log "IMPORTANT: the project's Makefile defaults to CC=gcc, LD=ld, OBJCOPY=objcopy,"
log "which are Apple's native (non-bare-metal) tools and will NOT work for this"
log "project on macOS. Build with the cross-toolchain explicitly instead:"
log ""
log "  make CC=x86_64-elf-gcc LD=x86_64-elf-ld OBJCOPY=x86_64-elf-objcopy"
log ""
log "Consider adding a macOS override (e.g. an 'ifeq (\$(shell uname -s),Darwin)'"
log "block) to the Makefile so plain 'make' works out of the box on macOS."
