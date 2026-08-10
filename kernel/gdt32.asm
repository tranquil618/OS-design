; OrangeOS kernel-owned GDT and 32-bit TSS
[BITS 32]

global gdt_init32
global gdt_is_ready32

KERNEL_CODE equ 0x08
KERNEL_DATA equ 0x10
TSS_SELECTOR equ 0x28
TSS_ESP0 equ 0x0008F000

gdt_init32:
    pushad
    mov eax,tss32
    mov word [gdt_tss+2],ax
    shr eax,16
    mov byte [gdt_tss+4],al
    mov byte [gdt_tss+7],ah

    mov dword [tss32+4],TSS_ESP0
    mov word [tss32+8],KERNEL_DATA
    mov word [tss32+102],104

    lgdt [gdt_descriptor]
    mov ax,KERNEL_DATA
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov ax,TSS_SELECTOR
    ltr ax
    mov byte [gdt_ready],1
    popad
    ret

gdt_is_ready32:
    movzx eax,byte [gdt_ready]
    ret

align 8
gdt_start:
    dq 0
    dq 0x00CF9A000000FFFF       ; 0x08 ring-0 code
    dq 0x00CF92000000FFFF       ; 0x10 ring-0 data
    dq 0x00CFFA000000FFFF       ; 0x18 ring-3 code
    dq 0x00CFF2000000FFFF       ; 0x20 ring-3 data
gdt_tss:
    dw 103,0
    db 0,0x89,0,0
gdt_end:

gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start

align 4
tss32: times 104 db 0
gdt_ready: db 0
