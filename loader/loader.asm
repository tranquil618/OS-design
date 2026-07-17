org 0x9000

;设置段寄存器
mov ax,0x1000
mov es,ax
mov ds,ax

mov bx,0

;读取kernel
mov ah,0x02       ;BIOS读取扇区
mov al,1          ;读取1个扇区
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

times 510-($-$$) db 0

dw 0xaa55