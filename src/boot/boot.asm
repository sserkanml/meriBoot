bits 16
org 0x7C00

jmp 0x0000:start

start:
    cli     ; clear interrupts
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti     ; enable interrupts

    cld     ; clear direction flag

    mov si, msg
    mov di, .check_extensions
    jmp .print_loop
    

.check_extensions:
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc .load_stage2_chs
    jmp .load_stage2_lba

.print_loop:
    lodsb
    cmp al, 0
    jz .print_done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
    
.print_done:
    jmp di

.load_stage2_chs:
    mov ah, 0x02
    mov al, 4
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov bx, 0x8000
    int 0x13
    jc .load_error

    jmp 0x0000:0x8000

.load_stage2_lba:
    mov si, dap
    mov ah, 0x42
    int 0x13
    jc .load_error

    jmp 0x0000:0x8000


.load_error:
    mov si, error_msg
    mov di, .done
    jmp .print_loop


.done:
    jmp $


msg db "[meriBoot] Stage1 loaded", 0

error_msg db "[meriBoot] Error loading Stage2", 0

dap:               ; disk access packet https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)
    db 0x10        ; package size (fixed, 16 byte)
    db 0x00        ; reserved
    dw 4           ; sector count
    dw 0x8000      ; target offset
    dw 0x0000      ; target segment
    dq 1           ; beginning LBA (8 byte)

times 510 - ($ - $$) db 0

dw 0xAA55
