# meriBoot

A from-scratch x86 bootloader built to fully comply with the [Multiboot2 specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)


## Status

Early development. See the project board and issues for current progress. Development is proceeding in two phases:

- **Phase 1 — BIOS/Legacy Boot** (in progress): boot sector, A20, GDT/protected mode, Multiboot2 header parsing, MBI construction.
- **Phase 2 — UEFI Boot** (planned): PE/COFF entry point, EFI-specific tags, EFI memory map, ACPI/SMBIOS via EFI Configuration Table.


## Prerequisites

Run the setup script for your distribution (auto-detects Debian/Ubuntu vs. RHEL/Fedora/CentOS families):

```bash
chmod +x tools/setup-toolchain.sh
./tools/setup-toolchain.sh
```

This installs `nasm`, a 32-bit capable `gcc`, `binutils`, `make`, and `qemu-system-x86`.

## Building

```bash
make
```

This assembles the Stage 1 boot sector, compiles and links Stage 2, and produces a bootable disk image under `build/`.

## Running

```bash
./tools/run-qemu.sh
```

Boots the produced image in QEMU.

## Debugging

QEMU can be launched with `-s -S` to pause at startup and accept a GDB connection, allowing step-by-step inspection of each boot stage (real mode → A20 → protected mode → Multiboot2 parsing → kernel handoff).

## Specification Reference

This project follows the [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html) as published by GNU GRUB. Relevant spec sections are cross-referenced in issue descriptions and code comments where applicable.

## License

See [LICENSE](LICENSE).
