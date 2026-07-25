org 0x9000
[BITS 16]

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

;开启A20地址线
call enable_a20

;关闭中断并加载GDT
cli
lgdt [gdt_descriptor]

;设置CR0的PE位
mov eax,cr0
or eax,0x00000001
mov cr0,eax

;远跳转进入32位代码段
jmp dword CODE_SELECTOR:protected_mode_entry




;=================================
; Disk Error
;=================================
disk_error:
    mov ah,0x0e        ;显示错误字符E
    mov al,'E'

    int 0x10

    jmp $

;=================================
; 开启A20地址线
; 使用Fast A20 Gate，端口0x92
;=================================
enable_a20:
    in al,0x92        ;读取系统控制端口
    ;确保不会触发Fast Reset
    and al,11111110b  ;避免意外触发快速复位
    ;将A20 Enable位置1
    or al,00000010b

    out 0x92,al       ;写回
    ret

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

;=================================
; 32位保护模式入口
;=================================
[BITS 32]
protected_mode_entry:
    ;初始化数据段寄存器
    mov ax,DATA_SELECTOR
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax

    ;初始化32位栈
    mov esp,0x90000

    ;跳转到物理地址0x10000的32位kernel
    jmp dword CODE_SELECTOR:0x10000


times 510-($-$$) db 0

dw 0xaa55