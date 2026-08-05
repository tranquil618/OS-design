; OrangeOS CMOS real-time clock
[BITS 32]

global rtc_get_info32

CMOS_INDEX equ 0x70
CMOS_DATA  equ 0x71

rtc_get_info32:
    pushad
.wait_update:
    mov al,0x0A
    out CMOS_INDEX,al
    in al,CMOS_DATA
    test al,0x80
    jnz .wait_update

    mov al,0x00
    call rtc_read32
    mov [rtc_second],al
    mov al,0x02
    call rtc_read32
    mov [rtc_minute],al
    mov al,0x04
    call rtc_read32
    mov [rtc_hour],al
    mov al,0x07
    call rtc_read32
    mov [rtc_day],al
    mov al,0x08
    call rtc_read32
    mov [rtc_month],al
    mov al,0x09
    call rtc_read32
    mov [rtc_year],al
    mov al,0x0B
    call rtc_read32
    mov [rtc_status_b],al

    test byte [rtc_status_b],0x04
    jnz .binary_ready
    mov esi,rtc_second
    mov ecx,6
.convert:
    mov al,[esi]
    call bcd_to_binary32
    mov [esi],al
    inc esi
    loop .convert
.binary_ready:
    mov edi,rtc_buffer
    mov esi,rtc_prefix
    call rtc_append_string32
    movzx eax,byte [rtc_year]
    call rtc_append_two_digits32
    mov al,'-'
    stosb
    movzx eax,byte [rtc_month]
    call rtc_append_two_digits32
    mov al,'-'
    stosb
    movzx eax,byte [rtc_day]
    call rtc_append_two_digits32
    mov al,' '
    stosb
    movzx eax,byte [rtc_hour]
    and eax,0x7F
    call rtc_append_two_digits32
    mov al,':'
    stosb
    movzx eax,byte [rtc_minute]
    call rtc_append_two_digits32
    mov al,':'
    stosb
    movzx eax,byte [rtc_second]
    call rtc_append_two_digits32
    mov byte [edi],0
    popad
    mov esi,rtc_buffer
    ret

rtc_read32:
    out CMOS_INDEX,al
    in al,CMOS_DATA
    ret

bcd_to_binary32:
    push ebx
    mov bl,al
    and eax,0x0F
    and ebx,0xF0
    shr ebx,4
    imul ebx,ebx,10
    add eax,ebx
    pop ebx
    ret

rtc_append_two_digits32:
    push edx
    xor edx,edx
    mov ecx,10
    div ecx
    add al,'0'
    stosb
    mov al,dl
    add al,'0'
    stosb
    pop edx
    ret

rtc_append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

rtc_prefix: db 'RTC UTC 20',0
rtc_buffer: times 24 db 0
rtc_second:  db 0
rtc_minute:  db 0
rtc_hour:    db 0
rtc_day:     db 0
rtc_month:   db 0
rtc_year:    db 0
rtc_status_b: db 0
