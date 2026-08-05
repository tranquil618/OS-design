; OrangeOS reboot and QEMU shutdown support
[BITS 32]

global system_reboot32
global system_shutdown32

KBC_STATUS  equ 0x64
KBC_COMMAND equ 0x64

system_reboot32:
    cli
    mov ecx,1000000
.wait_input_empty:
    in al,KBC_STATUS
    test al,0x02
    jz .reset
    loop .wait_input_empty
.reset:
    mov al,0xFE
    out KBC_COMMAND,al
.halt:
    hlt
    jmp .halt

system_shutdown32:
    cli
    ; QEMU/Bochs ACPI power-off ports.
    mov dx,0x0604
    mov ax,0x2000
    out dx,ax
    mov dx,0xB004
    out dx,ax
.halt:
    hlt
    jmp .halt
