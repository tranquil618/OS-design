org 0x9000

;设置Loader数据段
mov ax,0x0000
mov ds,ax

;设置Kernel加载段
mov ax,0x1000
mov es,ax
mov bx,0x0000

;读取kernel
mov ah,0x02       ;BIOS读取扇区
mov al,8          ;读取8个扇区
;设置CHS参数
mov ch,0          ;第0柱面
mov cl,3          ;第3扇区(kernel所在)
mov dh,0          ;第0磁头
mov dl,0x80       ;第一块硬盘

int 0x13          ;调用BIOS磁盘读取

jc disk_error      ;读取失败
jmp 0x1000:0x0000 ;跳转执行kernel


disk_error:
mov ah,0x0e        ;显示错误字符E
mov al,'E'

int 0x10

jmp $

;=================================
; Global Descriptor Table
;=================================
gdt_start:
;空描述符
gdt_null:
    dq 0x0000000000000000

;32位代码段描述符
gdt_code:
    dw 0xFFFF          ;段界限 0-15
    dw 0x0000          ;段基址 0-15
    db 0x00            ;段基址 16-23
    db 10011010b       ;代码段，可读、可执行
    db 11001111b       ;4KB粒度，32位，界限高4位
    db 0x00            ;段基址 24-31

;32位数据段描述符
gdt_data:
    dw 0xFFFF          ;段界限 0-15
    dw 0x0000          ;段基址 0-15
    db 0x00            ;段基址 16-23
    db 10010010b       ;数据段，可读写
    db 11001111b       ;4KB粒度，32位，界限高4位
    db 0x00            ;段基址 24-31

gdt_end:
;GDT描述符
gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start

CODE_SELECTOR equ gdt_code-gdt_start
DATA_SELECTOR equ gdt_data-gdt_start

times 510-($-$$) db 0

dw 0xaa55