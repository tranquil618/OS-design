org 0x9000
[BITS 16]

; Establish a known real-mode environment.
cli
xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0x7C00
sti

; Pass conventional-memory size to the kernel at physical 0x0500.
int 0x12
mov [0x0500],ax

; Collect up to 16 BIOS E820 entries at physical 0x0508.
xor ax,ax
mov es,ax
xor ebx,ebx
mov di,0x0508
mov dword [0x0504],0
.e820_next:
mov eax,0xE820
mov edx,0x534D4150
mov ecx,20
int 0x15
jc .e820_done
cmp eax,0x534D4150
jne .e820_done
inc dword [0x0504]
add di,20
cmp dword [0x0504],16
jae .e820_done
test ebx,ebx
jnz .e820_next
.e820_done:

; Load 40 sectors from LBA 2 to physical address 0x10000.
xor ax,ax
mov ds,ax
mov si,kernel_dap
mov dl,0x80
mov ah,0x42
int 0x13
jc disk_error

call enable_a20

cli
lgdt [gdt_descriptor]
mov eax,cr0
or eax,0x00000001
mov cr0,eax
jmp dword CODE_SELECTOR:protected_mode_entry

disk_error:
    mov ah,0x0E
    mov al,'E'
    int 0x10
    jmp $

enable_a20:
    in al,0x92
    and al,11111110b
    or al,00000010b
    out 0x92,al
    ret

align 4
kernel_dap:
    db 0x10
    db 0
    dw 40
    dw 0x0000
    dw 0x1000
    dq 2

gdt_start:
gdt_null:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start

CODE_SELECTOR equ gdt_code-gdt_start
DATA_SELECTOR equ gdt_data-gdt_start

[BITS 32]
protected_mode_entry:
    mov ax,DATA_SELECTOR
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov esp,0x90000
    jmp dword CODE_SELECTOR:0x10000

times 510-($-$$) db 0
dw 0xAA55
