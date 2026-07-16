org 0x7c00      ;告诉NASM这段代码未来会被加载到内存地址0x7C00
;BIOS(Basic Input/Output System，基本输入输出系统)，固化在计算机主板上的一块制度存储器；
;加电自检(POST),寻找引导设备，加载引导扇区
mov ax,0        ;把数字0放入AX寄存器，现在AX=0000
mov ds,ax       ;设置数据段寄存器DS变成DS=0000，因为8086使用（段地址：偏移地址），例如DS:1234实际地址为DS*16+1234
mov es,ax       ;设置ES=0000，因为BIOS磁盘读取不是DS:BX,俄日是ES:BX,所以后面的mov bx,0x9000实际上表示0000:9000,也就是0x9000

;读取loader
mov ah,0x02     ;设置功能号，AH是INT 13h的功能选择，BIOS磁盘服务
mov al,1        ;读取1个扇区(读取数量)
;设置CHS参数，BIOS早期使用C(ylinder)H(ead)S(ector)
mov ch,0        ;第0柱面
mov cl,2        ;第2个扇区(loader所在)
mov dh,0        ;第0磁头
mov dl,0x80     ;第一块硬盘

mov bx,0x9000   ;loader加载到0x9000

int 0x13        ;调用BIOS磁盘服务


jc disk_error   ;如果读取失败跳转

jmp 0x0000:0x9000 ;跳转执行loader


disk_error:      

mov ah,0x0e      ;BIOS显示字符功能
mov al,'E'       ;显示错误字符E
int 0x10         ;调用显示服务

jmp $            ;无限循环



times 510-($-$$) db 0 ;填充到510字节

dw 0xaa55        ;Boot Sector结束标志
