# Makefile

ASM := nasm

# macOS ships Apple clang/ld as `gcc`/`ld`, which can't produce freestanding
# 32-bit ELF binaries. Default to the Homebrew x86_64-elf cross-toolchain
# there instead (see tools/setup_toolchain_macos.sh); override on the
# command line (e.g. `make CC=...`) if you need something else.
ifeq ($(shell uname -s),Darwin)
    CC      := x86_64-elf-gcc
    LD      := x86_64-elf-ld
    OBJCOPY := x86_64-elf-objcopy
else
    CC      := gcc
    LD      := ld
    OBJCOPY := objcopy
endif

BUILD_DIR  := build
SRC_BOOT   := src/boot/boot.asm
SRC_STAGE2 := src/stage2/stage2.c
LINKER     := src/stage2/linker.ld

BOOT_BIN   := $(BUILD_DIR)/boot.bin
STAGE2_OBJ := $(BUILD_DIR)/stage2.o
STAGE2_ELF := $(BUILD_DIR)/stage2.elf
STAGE2_BIN := $(BUILD_DIR)/stage2.bin
STAGE2_ASM_SRC := src/stage2/stage2_entry.asm
STAGE2_ASM_OBJ := $(BUILD_DIR)/stage2_entry.o
IMG        := $(BUILD_DIR)/meriboot.img

STAGE2_SECTORS := 4
STAGE2_SIZE    := $(shell echo $$(( $(STAGE2_SECTORS) * 512 )))

CFLAGS  := -m32 -ffreestanding -fno-pic -c
LDFLAGS := -m elf_i386 -T $(LINKER)

.PHONY: all run clean

all: $(IMG)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): $(SRC_BOOT) | $(BUILD_DIR)
	$(ASM) -f bin $(SRC_BOOT) -o $(BOOT_BIN)

$(STAGE2_OBJ): $(SRC_STAGE2) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SRC_STAGE2) -o $(STAGE2_OBJ)


$(STAGE2_BIN): $(STAGE2_ELF)
	$(OBJCOPY) -O binary $(STAGE2_ELF) $(STAGE2_BIN)

$(STAGE2_ASM_OBJ): $(STAGE2_ASM_SRC) | $(BUILD_DIR)
	$(ASM) -f elf32 $(STAGE2_ASM_SRC) -o $(STAGE2_ASM_OBJ)

$(STAGE2_ELF): $(STAGE2_ASM_OBJ) $(STAGE2_OBJ) $(LINKER)
	$(LD) $(LDFLAGS) $(STAGE2_ASM_OBJ) $(STAGE2_OBJ) -o $(STAGE2_ELF)

$(IMG): $(BOOT_BIN) $(STAGE2_BIN)
	cp $(BOOT_BIN) $(IMG)
	truncate -s $(STAGE2_SIZE) $(STAGE2_BIN)
	cat $(STAGE2_BIN) >> $(IMG)

run: $(IMG)
	./tools/run-qemu.sh

clean:
	rm -rf $(BUILD_DIR)