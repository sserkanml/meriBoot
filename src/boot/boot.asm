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
    mov di, .load_stage2
    

.print_loop:
    lodsb
    cmp al, 0
    jz .print_done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
    
.print_done:
    jmp di

.load_stage2:
    mov ah, 0x02
    mov al, 4
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov bx, 0x8000
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

times 510 - ($ - $$) db 0

dw 0xAA55
