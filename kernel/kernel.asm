org 0x10000      ;表示Kernel记载地址
;内存布局   0x7c00 -> Boot   0x9000 -> Loader   0x10000 -> Kernel入口

;设置数据段
mov ax,0x1000
mov ds,ax
;设置显存段
mov ax,0xb800      ;设置显存段
mov es,ax

call clear_screen

mov si,message   ;SI:Source Index，让SI指向字符串地址
mov bx,colors    ;颜色表地址
mov di,28*2         ;di表示显存偏移

print:           ;循环打印
    mov al,[si]
    cmp al,0
    je halt

    mov [es:di],al   ;写字符
    inc di

    mov al,[bx]      ;取当前字符颜色
    mov [es:di],al   ;写颜色
    inc di

    inc si
    inc bx
    jmp print

halt:
    jmp $

clear_screen:
    mov di,0       ;显存开始位置
    mov cx,2000     ;2000个字符

clear_loop:
    mov byte [es:di],' '    ;写空格
    inc di

    mov byte [es:di],0x07   ;黑底白字
    inc di

    loop clear_loop

    ret

message:
    db 'OrangeOS Kernel Started!',0

colors:
    ;OrangeOS每个字母一个颜色
    db 0x0C    ;O 亮红
    db 0x0E    ;r 亮黄
    db 0x0A    ;a 亮绿
    db 0x09    ;n 亮蓝
    db 0x0D    ;g 亮紫
    db 0x0B    ;e 亮青
    db 0x0F    ;O 亮白
    db 0x06    ;S 棕黄

    ;后面的Kernel Started!统一白色
    db 0x07    ;空格
    
    ;Kernel Started!
    times 15 db 0x07

