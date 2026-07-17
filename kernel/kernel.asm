org 0x10000      ;表示Kernel记载地址
;内存布局   0x7c00 -> Boot   0x9000 -> Loader   0x10000 -> Kernel入口ernel

mov ah,0x0e      ;设置BIOS显示字符

mov si,message   ;SI:Source Index，让SI指向字符串地址

print:           ;循环打印
lodsb

cmp al,0         ;判断结束

je halt


int 0x10         ;调用BIOS显示字符

jmp print

halt:
jmp $


message:

db 'OrangeOS Kernel Started!',0