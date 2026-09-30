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
    sti

    mov si, msg
    

.print_loop:
    lodsb
    cmp al, 0
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop

.done:
    jmp $


msg db "[meriBoot] Stage1 loaded", 0

times 510 - ($ - $$) db 0

dw 0xAA55
