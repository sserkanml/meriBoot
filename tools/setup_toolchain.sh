#!/usr/bin/env bash
#
# setup-toolchain.sh
#
# Sets up the development environment for meriBoot. Detects the Linux
# distribution (Debian/Ubuntu or RHEL/Fedora/CentOS) and installs missing
# tools using the appropriate package manager.
#
# Installed packages:
#   - nasm            -> Assembly compiler (boot.asm, bios_calls.asm, gdt_flush.asm)
#   - gcc (32-bit)    -> 32-bit C compilation for stage2 (-m32 -ffreestanding)
#   - binutils (ld)   -> Linker used with linker.ld
#   - make            -> Build automation tool
#   - qemu-system-x86 -> Emulator to run and test compiled OS images
#
# Usage:
#   chmod +x tools/setup-toolchain.sh
#   ./tools/setup-toolchain.sh

set -euo pipefail

log()  { printf '\033[1;32m[setup]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[warning]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2; }

# --- 1) Root/Sudo Check ---------------------------------------------------

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        err "Root privileges required to install packages, but 'sudo' was not found."
        err "Run this script as root: su -c ./tools/setup-toolchain.sh"
        exit 1
    fi
fi

# --- 2) Distro Detection --------------------------------------------------

if [ ! -f /etc/os-release ]; then
    err "/etc/os-release not found. Cannot determine Linux distribution."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

DISTRO_ID="${ID:-}"
DISTRO_LIKE="${ID_LIKE:-}"
FAMILY=""

case "$DISTRO_ID $DISTRO_LIKE" in
    *debian*|*ubuntu*)
        FAMILY="debian"
        ;;
    *rhel*|*fedora*|*centos*)
        FAMILY="rhel"
        ;;
    *)
        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop)
                FAMILY="debian"
                ;;
            rhel|fedora|centos|rocky|almalinux)
                FAMILY="rhel"
                ;;
            *)
                err "Unsupported or unknown distribution: ID='${DISTRO_ID}' ID_LIKE='${DISTRO_LIKE}'"
                err "Supported distribution families: Debian/Ubuntu and RHEL/Fedora/CentOS."
                exit 1
                ;;
        esac
        ;;
esac

log "Detected OS: ${PRETTY_NAME:-$DISTRO_ID} (family: $FAMILY)"

# --- 3) Package Installation ----------------------------------------------

install_debian() {
    local required_pkgs=(
        build-essential
        nasm
        gcc-multilib
        g++-multilib
        binutils
        make
        qemu-system-x86
        xxd
    )
    local missing_pkgs=()

    log "Checking installed packages..."
    for pkg in "${required_pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log "All required packages are already installed."
        return 0
    fi

    log "Missing packages found: ${missing_pkgs[*]}"
    log "Updating apt package list..."
    $SUDO apt-get update -y

    log "Installing missing packages..."
    $SUDO apt-get install -y "${missing_pkgs[@]}"
}

install_rhel() {
    local pm="dnf"
    if ! command -v dnf >/dev/null 2>&1; then
        pm="yum"
    fi

    local required_pkgs=(
        gcc
        glibc-devel.i686
        libgcc.i686
        nasm
        binutils
        make
        qemu-system-x86
        vim-common
    )
    local missing_pkgs=()

    log "Checking installed packages..."
    for pkg in "${required_pkgs[@]}"; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log "All required packages are already installed."
        return 0
    fi

    log "Missing packages found: ${missing_pkgs[*]}"

    if [ "$DISTRO_ID" = "rhel" ] || [ "$DISTRO_ID" = "centos" ] || [ "$DISTRO_ID" = "rocky" ] || [ "$DISTRO_ID" = "almalinux" ]; then
        warn "RHEL-based systems may require the CRB or PowerTools repository for 32-bit development libraries:"
        warn "  $SUDO dnf config-manager --set-enabled crb      # RHEL 9 / Rocky 9 / Alma 9"
        warn "  $SUDO dnf config-manager --set-enabled powertools # RHEL 8 / Rocky 8 / Alma 8"
    fi

    log "Installing missing packages with $pm..."
    $SUDO "$pm" install -y "${missing_pkgs[@]}"
}

case "$FAMILY" in
    debian) install_debian ;;
    rhel)   install_rhel ;;
esac

# --- 4) Verification ------------------------------------------------------

log "Verifying installed tools..."

check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  [OK] %-10s -> %s\n' "$name" "$(command -v "$cmd")"
    else
        printf '  [MISSING] %-10s -> not found\n' "$name"
        MISSING=1
    fi
}

MISSING=0
check_tool "nasm"  "nasm"
check_tool "gcc"   "gcc"
check_tool "ld"    "ld"
check_tool "make"  "make"
check_tool "qemu"  "qemu-system-x86_64"

if [ "${MISSING:-0}" -eq 1 ]; then
    err "Some required tools are missing. Check the output above."
    exit 1
fi

log "Testing gcc -m32 support..."
if echo 'int main(void){return 0;}' | gcc -m32 -ffreestanding -x c -c -o /tmp/meriboot_m32_test.o - 2>/dev/null; then
    log "  [OK] gcc -m32 -ffreestanding works."
    rm -f /tmp/meriboot_m32_test.o
else
    err "  [FAILED] gcc -m32 test failed. Missing 32-bit development libraries (gcc-multilib or glibc-devel.i686)."
    exit 1
fi

log "Environment setup completed. You can now build with 'make' and test using qemu-system-x86_64."