# meriBoot

A from-scratch x86 bootloader built to fully comply with the [Multiboot2 specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)


## Status

Early development. See the project board and issues for current progress. Development is proceeding in two phases:

- **Phase 1 — BIOS/Legacy Boot** (in progress): boot sector, A20, GDT/protected mode, Multiboot2 header parsing, MBI construction.
- **Phase 2 — UEFI Boot** (planned): PE/COFF entry point, EFI-specific tags, EFI memory map, ACPI/SMBIOS via EFI Configuration Table.


## Prerequisites

### Linux

Run the setup script for your distribution (auto-detects Debian/Ubuntu vs. RHEL/Fedora/CentOS families):

```bash
chmod +x tools/setup_toolchain.sh
./tools/setup_toolchain.sh
```

This installs `nasm`, a 32-bit capable `gcc`, `binutils`, `make`, and `qemu-system-x86`.

### macOS

Apple's bundled clang/gcc no longer supports `-m32 -ffreestanding` bare-metal builds, so macOS uses a dedicated `x86_64-elf` cross-compiler instead. Run:

```bash
chmod +x tools/setup_toolchain_macos.sh
./tools/setup_toolchain_macos.sh
```

This installs `nasm`, `x86_64-elf-gcc`, `x86_64-elf-binutils`, `make`, and `qemu` via Homebrew.

## Building

```bash
make
```

The Makefile detects macOS automatically and uses the `x86_64-elf` cross-toolchain installed above (`CC=x86_64-elf-gcc`, `LD=x86_64-elf-ld`, `OBJCOPY=x86_64-elf-objcopy`); on Linux it uses the native `gcc`/`ld`/`objcopy`. This assembles the Stage 1 boot sector, compiles and links Stage 2, and produces a bootable disk image under `build/`.

## Running

```bash
chmod +x ./tools/run-qemu.sh &&
./tools/run-qemu.sh
```

Boots the produced image in QEMU.

## Debugging

QEMU can be launched with `-s -S` to pause at startup and accept a GDB connection, allowing step-by-step inspection of each boot stage (real mode → A20 → protected mode → Multiboot2 parsing → kernel handoff).

## Specification Reference

This project follows the [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html) as published by GNU GRUB. Relevant spec sections are cross-referenced in issue descriptions and code comments where applicable.

## License

See [LICENSE](LICENSE).
