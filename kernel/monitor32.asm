; OrangeOS compact system monitor
[BITS 32]

global monitor_get_info32
global monitor_run32
global monitor_keyboard32

extern timer_get_ticks32
extern memory_get_free_pages32
extern memory_get_total_pages32
extern memory_get_used_pages32
extern process_get_switches32
extern process_get_runtime32
extern process_get_state32
extern current_process
extern keyboard_set_cursor32

VGA_MEMORY equ 0xB8000
INPUT_BASE equ VGA_MEMORY+320
INPUT_CELLS equ 23*80

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

    mov esi,text_used
    call monitor_append_string32
    call memory_get_used_pages32
    call monitor_append_uint32

    mov esi,text_total
    call monitor_append_string32
    call memory_get_total_pages32
    call monitor_append_uint32

    mov esi,text_pid
    call monitor_append_string32
    mov eax,[current_process]
    inc eax
    call monitor_append_uint32

    mov esi,text_switches
    call monitor_append_string32
    call process_get_switches32
    call monitor_append_uint32

    mov byte [edi],0
    popad
    mov esi,monitor_buffer
    ret

; Full-screen live monitor. Q or Esc sets the exit flag from IRQ1.
monitor_run32:
    pushad
    mov byte [monitor_exit],0
    mov byte [monitor_active],1
    mov dword [monitor_last_tick],0xFFFFFFFF
    sti
.refresh_loop:
    cmp byte [monitor_exit],0
    jne .exit
    call timer_get_ticks32
    mov edx,eax
    sub edx,[monitor_last_tick]
    cmp edx,10
    jb .wait
    mov [monitor_last_tick],eax
    call monitor_draw32
.wait:
    hlt
    jmp .refresh_loop
.exit:
    cli
    mov byte [monitor_active],0
    call monitor_clear_input32
    xor eax,eax
    call keyboard_set_cursor32
    popad
    ret

; AL=Set-1 scan code. EAX=1 if the live monitor consumed the key.
monitor_keyboard32:
    cmp byte [monitor_active],0
    je .not_active
    cmp al,0x01
    je .request_exit
    cmp al,0x10
    jne .consumed
.request_exit:
    mov byte [monitor_exit],1
.consumed:
    mov eax,1
    ret
.not_active:
    xor eax,eax
    ret

monitor_draw32:
    pushad
    call monitor_clear_input32

    mov edi,INPUT_BASE
    mov esi,live_title
    call monitor_draw_string32

    mov edi,INPUT_BASE+320
    mov esi,text_uptime
    call monitor_build_begin32
    call timer_get_ticks32
    xor edx,edx
    mov ecx,100
    div ecx
    call monitor_append_uint32
    mov esi,live_seconds
    call monitor_append_string32
    mov byte [edi],0
    mov esi,monitor_buffer
    mov edi,INPUT_BASE+320
    call monitor_draw_string32

    mov edi,monitor_buffer
    mov esi,live_memory
    call monitor_append_string32
    call memory_get_used_pages32
    call monitor_append_uint32
    mov byte [edi],'/'; inc edi
    call memory_get_total_pages32
    call monitor_append_uint32
    mov esi,live_free
    call monitor_append_string32
    call memory_get_free_pages32
    call monitor_append_uint32
    mov byte [edi],0
    mov esi,monitor_buffer
    mov edi,INPUT_BASE+480
    call monitor_draw_string32

    mov edi,monitor_buffer
    mov esi,live_scheduler
    call monitor_append_string32
    call process_get_switches32
    call monitor_append_uint32
    mov esi,live_current
    call monitor_append_string32
    mov eax,[current_process]
    inc eax
    call monitor_append_uint32
    mov byte [edi],0
    mov esi,monitor_buffer
    mov edi,INPUT_BASE+640
    call monitor_draw_string32

    mov esi,live_header
    mov edi,INPUT_BASE+960
    call monitor_draw_string32
    xor ebx,ebx
.task_row:
    mov edi,monitor_buffer
    mov esi,live_pid
    call monitor_append_string32
    mov eax,ebx
    inc eax
    call monitor_append_uint32
    mov esi,live_state
    call monitor_append_string32
    mov eax,ebx
    call process_get_state32
    cmp eax,2
    jne .check_faulted_state
    mov esi,live_running
    jmp .state_ready
.check_faulted_state:
    cmp eax,4
    jne .check_exited_state
    mov esi,live_faulted
    jmp .state_ready
.check_exited_state:
    cmp eax,3
    jne .ready_state
    mov esi,live_exited
    jmp .state_ready
.ready_state:
    mov esi,live_ready
.state_ready:
    call monitor_append_string32
    mov esi,live_ticks
    call monitor_append_string32
    mov eax,ebx
    call process_get_runtime32
    mov ebp,eax
    call monitor_append_uint32
    mov esi,live_cpu
    call monitor_append_string32
    call timer_get_ticks32
    test eax,eax
    jz .zero_percent
    mov ecx,eax
    mov eax,ebp
    imul eax,eax,100
    xor edx,edx
    div ecx
    jmp .percent_ready
.zero_percent:
    xor eax,eax
.percent_ready:
    call monitor_append_uint32
    mov byte [edi],'%'; inc edi
    mov byte [edi],0
    mov esi,monitor_buffer
    mov eax,ebx
    imul eax,eax,160
    lea edi,[INPUT_BASE+1120+eax]
    call monitor_draw_string32
    inc ebx
    cmp ebx,4
    jb .task_row

    mov esi,live_exit
    mov edi,INPUT_BASE+1760
    call monitor_draw_string32
    popad
    ret

monitor_build_begin32:
    mov edi,monitor_buffer
    call monitor_append_string32
    ret

monitor_clear_input32:
    push eax
    push ecx
    push edi
    mov edi,INPUT_BASE
    mov ecx,INPUT_CELLS
    mov ax,0x0720
    rep stosw
    pop edi
    pop ecx
    pop eax
    ret

monitor_draw_string32:
    push eax
.draw:
    lodsb
    test al,al
    jz .draw_done
    mov [edi],al
    mov byte [edi+1],0x0A
    add edi,2
    jmp .draw
.draw_done:
    pop eax
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
text_used:     db ' Used=',0
text_total:    db '/',0
text_pid:      db ' | PID=',0
text_switches: db ' | Switches=',0
monitor_buffer: times 112 db 0
live_title:     db 'Orange Monitor - Live System View',0
live_seconds:   db ' seconds',0
live_memory:    db 'Memory pages: used=',0
live_free:      db ' free=',0
live_scheduler: db 'Scheduler: switches=',0
live_current:   db ' current PID=',0
live_header:    db 'PROCESS TABLE',0
live_pid:       db 'PID ',0
live_state:     db '  State=',0
live_running:   db 'RUNNING',0
live_ready:     db 'READY  ',0
live_exited:    db 'EXITED ',0
live_faulted:   db 'FAULTED',0
live_ticks:     db '  Ticks=',0
live_cpu:       db '  CPU=',0
live_exit:      db 'Press Q or Esc to return to OrangeOS Shell',0
monitor_active: db 0
monitor_exit:   db 0
align 4
monitor_last_tick: dd 0
