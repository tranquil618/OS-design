; OrangeOS int 0x80 system-call dispatcher
[BITS 32]

global isr_syscall32
global syscall_get_info32

extern timer_get_ticks32
extern memory_get_free_pages32
extern current_process

SYS_GET_TICKS equ 0
SYS_GET_FREE  equ 1
SYS_GET_PID   equ 2

; EAX=call number. Return value in EAX; preserve all other registers.
isr_syscall32:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    cmp eax,SYS_GET_TICKS
    je .ticks
    cmp eax,SYS_GET_FREE
    je .free
    cmp eax,SYS_GET_PID
    je .pid
    mov eax,0xFFFFFFFF
    jmp .return
.ticks:
    call timer_get_ticks32
    jmp .return
.free:
    call memory_get_free_pages32
    jmp .return
.pid:
    mov eax,[current_process]
    inc eax
.return:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    iretd

; Exercise the ABI and return a printable summary in ESI.
syscall_get_info32:
    pushad
    mov edi,syscall_buffer
    mov esi,text_ticks
    call append_string32
    mov eax,SYS_GET_TICKS
    int 0x80
    call append_uint32
    mov esi,text_free
    call append_string32
    mov eax,SYS_GET_FREE
    int 0x80
    call append_uint32
    mov esi,text_pid
    call append_string32
    mov eax,SYS_GET_PID
    int 0x80
    call append_uint32
    mov byte [edi],0
    popad
    mov esi,syscall_buffer
    ret

append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

append_uint32:
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

text_ticks: db 'int80 ticks=',0
text_free:  db ' free=',0
text_pid:   db ' pid=',0
syscall_buffer: times 48 db 0
