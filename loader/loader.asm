org 0x9000

mov ah,0x0e       ;BIOS显示字符功能
mov al,'L'        ;显示字符L
int 0x10          ;调用BIOS显示

jmp $             ;无限循环

times 510-($-$$) db 0

dw 0xaa55