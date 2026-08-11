; OrangeOS input buffer and eight-entry command history
[BITS 32]

global input_append32
global input_backspace32
global input_submit32
global input_poll32
global input_history_up32
global input_history_down32
global input_complete32
global input_buffer
global input_length
global command_ready

%include "shell32.inc"

BUFFER_SIZE   equ 64
HISTORY_SIZE  equ 8

; AL=ASCII. Return EAX=1 when appended.
input_append32:
    push ecx
    push edx
    mov dl,al
    xor eax,eax
    cmp byte [command_ready],0
    jne .done
    mov ecx,[input_length]
    cmp ecx,BUFFER_SIZE-1
    jae .done
    mov [input_buffer+ecx],dl
    inc ecx
    mov [input_length],ecx
    mov byte [input_buffer+ecx],0
    mov dword [history_view],-1
    mov eax,1
.done:
    pop edx
    pop ecx
    ret

; Return EAX=1 when a character was removed.
input_backspace32:
    push ecx
    xor eax,eax
    cmp byte [command_ready],0
    jne .done
    mov ecx,[input_length]
    test ecx,ecx
    jz .done
    dec ecx
    mov [input_length],ecx
    mov byte [input_buffer+ecx],0
    mov dword [history_view],-1
    mov eax,1
.done:
    pop ecx
    ret

; Complete a unique command prefix. EDX=1 and EAX=new length when redrawing.
input_complete32:
    xor edx,edx
    mov ecx,[input_length]
    test ecx,ecx
    jz .complete_done
    mov esi,input_buffer
    mov eax,ecx
.reject_space:
    cmp byte [esi],' '
    je .complete_done
    inc esi
    dec eax
    jnz .reject_space
    mov esi,command_words
    xor ebx,ebx
    xor ebp,ebp
.candidate:
    cmp byte [esi],0
    je .selection
    mov edi,input_buffer
    mov eax,ecx
    push esi
.prefix:
    mov dl,[edi]
    cmp dl,[esi]
    jne .not_match
    inc edi
    inc esi
    dec eax
    jnz .prefix
    inc ebx
    mov ebp,[esp]
.not_match:
    pop esi
.skip_word:
    lodsb
    test al,al
    jnz .skip_word
    jmp .candidate
.selection:
    xor edx,edx
    cmp ebx,1
    jne .complete_done
    mov esi,ebp
    mov edi,input_buffer
    call copy_buffer32
    call measure_input32
    mov edx,1
.complete_done:
    ret

; Mark the current input as ready for the kernel loop.
input_submit32:
    push ecx
    xor eax,eax
    cmp byte [command_ready],0
    jne .done
    mov ecx,[input_length]
    mov byte [input_buffer+ecx],0
    mov byte [command_ready],1
    mov eax,1
.done:
    pop ecx
    ret

; Move toward older history. EDX=1 when redraw is required.
input_history_up32:
    cmp dword [history_count],0
    je history_unavailable32
    cmp dword [history_view],-1
    jne .older
    mov esi,input_buffer
    mov edi,history_draft
    call copy_buffer32
    mov dword [history_view],0
    jmp history_load_view32
.older:
    mov eax,[history_view]
    inc eax
    cmp eax,[history_count]
    jae history_load_view32
    mov [history_view],eax
    jmp history_load_view32

; Move toward newer history or restore the original draft.
input_history_down32:
    cmp dword [history_view],-1
    je history_unavailable32
    cmp dword [history_view],0
    je .restore_draft
    dec dword [history_view]
    jmp history_load_view32
.restore_draft:
    mov dword [history_view],-1
    mov esi,history_draft
    mov edi,input_buffer
    call copy_buffer32
    call measure_input32
    mov edx,1
    ret

history_load_view32:
    mov eax,[history_head]
    dec eax
    sub eax,[history_view]
    and eax,HISTORY_SIZE-1
    shl eax,6
    lea esi,[history_entries+eax]
    mov edi,input_buffer
    call copy_buffer32
    call measure_input32
    mov edx,1
    ret

history_unavailable32:
    xor eax,eax
    xor edx,edx
    ret

; Execute a submitted command from the kernel idle task.
input_poll32:
    pushfd
    cli
    cmp byte [command_ready],0
    je .done
    cmp dword [input_length],0
    je .execute
    call history_store32
.execute:
    mov esi,input_buffer
    call shell_execute32
    mov dword [input_length],0
    mov byte [input_buffer],0
    mov byte [command_ready],0
    mov dword [history_view],-1
    call shell_prompt32
.done:
    popfd
    ret

history_store32:
    mov eax,[history_head]
    shl eax,6
    lea edi,[history_entries+eax]
    mov esi,input_buffer
    call copy_buffer32
    inc dword [history_head]
    and dword [history_head],HISTORY_SIZE-1
    cmp dword [history_count],HISTORY_SIZE
    jae .full
    inc dword [history_count]
.full:
    ret

; Copy one zero-terminated command, bounded by BUFFER_SIZE.
copy_buffer32:
    push ecx
    mov ecx,BUFFER_SIZE-1
.copy:
    lodsb
    stosb
    test al,al
    jz .done
    loop .copy
    mov byte [edi],0
.done:
    pop ecx
    ret

; Measure input_buffer. Return EAX=length and ESI=input_buffer.
measure_input32:
    xor eax,eax
.measure:
    cmp byte [input_buffer+eax],0
    je .ready
    inc eax
    jmp .measure
.ready:
    mov [input_length],eax
    mov esi,input_buffer
    ret

input_buffer: times BUFFER_SIZE db 0
input_length: dd 0
command_ready: db 0

align 4
history_entries: times HISTORY_SIZE*BUFFER_SIZE db 0
history_draft:   times BUFFER_SIZE db 0
history_head:    dd 0
history_count:   dd 0
history_view:    dd -1

command_words:
    db 'help',0,'info',0,'clear',0,'ls',0,'mem',0,'memmap',0
    db 'task',0,'ps',0,'run',0,'runfault',0,'alloc',0,'dealloc',0
    db 'malloc',0,'free',0,'monitor',0,'status',0,'date',0,'disk',0
    db 'selftest',0,'user',0,'reboot',0,'shutdown',0,'syscall',0,0
