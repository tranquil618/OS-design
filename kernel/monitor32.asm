; OrangeOS compact system monitor
[BITS 32]

global monitor_get_info32

extern timer_get_ticks32
extern memory_get_free_pages32
extern process_get_switches32

monitor_get_info32:
    pushad
    mov edi,monitor_buffer

    mov esi,text_uptime
    call monitor_append_string32
    call timer_get_ticks32
    xor edx,edx
    mov ecx,100
    div ecx
    call monitor_append_uint32

    mov esi,text_free
    call monitor_append_string32
    call memory_get_free_pages32
    call monitor_append_uint32

    mov esi,text_switches
    call monitor_append_string32
    call process_get_switches32
    call monitor_append_uint32

    mov byte [edi],0
    popad
    mov esi,monitor_buffer
    ret

monitor_append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

monitor_append_uint32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
    test eax,eax
    jnz .digits
    mov byte [edi],'0'
    inc edi
    jmp .done
.digits:
    xor edx,edx
    div ebx
    push edx
    inc ecx
    test eax,eax
    jnz .digits
.write:
    pop edx
    add dl,'0'
    mov [edi],dl
    inc edi
    loop .write
.done:
    pop edx
    pop ecx
    pop ebx
    ret

text_uptime:   db 'Uptime=',0
text_free:     db 's | Free=',0
text_switches: db ' pages | Switches=',0
monitor_buffer: times 64 db 0
