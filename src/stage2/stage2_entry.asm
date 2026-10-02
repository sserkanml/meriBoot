bits 16

;   https://wiki.osdev.org/A20_Line
start:
    ; BIOS method to enable A20 line
    mov ax, 0x2401
    int 0x15

    ; Fast A20 enable method
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Keyboard controller method to enable A20 line
    call .kbc_wait_input
    mov al, 0xAD    ; Disable keyboard
    out 0x64, al

    call .kbc_wait_input
    mov al, 0xD0    ; Read output port
    out 0x64, al

    call .kbc_wait_output
    in al, 0x60     ; Get output port value
    push ax          ; Save output port value

    call .kbc_wait_input
    mov al, 0xD1    ; Write output port
    out 0x64, al

    call .kbc_wait_input
    pop ax           ; Restore output port value
    or al, 2         ; Set A20 gate bit
    out 0x60, al

    call .kbc_wait_input
    mov al, 0xAE    ; Enable keyboard
    out 0x64, al


    call .kbc_wait_input

    call .check_a20
    cmp ax, 1
    je .a20_done

.a20_error:
    jmp $

.a20_done:
    jmp $

.kbc_wait_input:
    in al, 0x64
    test al, 2
    jnz .kbc_wait_input
    ret

.kbc_wait_output:
    in al, 0x64
    test al, 1
    jz .kbc_wait_output
    ret

.check_a20:
    pushf
    push ds
    push es
    push di
    push si

    cli

    xor ax, ax
    mov es, ax

    mov ax, 0xFFFF
    mov ds, ax

    mov di, 0x0500
    mov si, 0x0510

    mov al, byte [es:di]
    push ax

    mov al, byte [ds:si]
    push ax

    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF

    cmp byte [es:di], 0xFF

    pop ax
    mov byte [ds:si], al

    pop ax
    mov byte [es:di], al

    mov ax, 0
    je .check_a20_exit

    mov ax, 1


.check_a20_exit:
    pop si
    pop di
    pop es
    pop ds
    popf

    ret