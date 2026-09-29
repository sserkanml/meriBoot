#!/usr/bin/env bash
#
# run-qemu.sh
#
# Runs the compiled .img file of meriBoot in QEMU.
#
# Usage:
#   ./tools/run-qemu.sh           -> normal execution
#   ./tools/run-qemu.sh --debug   -> start QEMU suspended, waiting for GDB connection

set -euo pipefail

IMAGE="build/meriboot.img"

if [ ! -f "$IMAGE" ]; then
    echo "Error: $IMAGE not found. You need to run 'make' first to build the image." >&2
    exit 1
fi

QEMU_ARGS=(
    -drive "format=raw,file=$IMAGE"
    -serial stdio    
)

if [ "${1:-}" = "--debug" ]; then
    echo "Debug mode: QEMU will wait until GDB connects."
    echo "Run this command in another terminal: gdb -ex 'target remote localhost:1234'"
    QEMU_ARGS+=(-s -S)
fi

qemu-system-i386 "${QEMU_ARGS[@]}"