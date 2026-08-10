;=================================
; print32.asm
; OrangeOS 32位字符串输出模块
;=================================
[BITS 32]
global print_string32

;=================================
; print_string32
; 输入：
; DS:ESI = 以0结尾的字符串
; EDI = VGA显存地址
;=================================
print_string32:
.loop:
    lodsb

    test al,al
    jz .done

    ; Mirror printable kernel text to the Bochs/QEMU debug console.  Real
    ; hardware simply ignores this diagnostic port, while automated boot
    ; tests can observe progress without scraping VGA memory.
    out 0xE9,al

    mov byte [edi],al
    mov byte [edi+1],0x0A
    add edi,2

    jmp .loop

.done:
    ret
