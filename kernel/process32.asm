; OrangeOS three-task round-robin scheduler
[BITS 32]

extern usermode_prepare32
extern usermode_release32
extern usermode_get_entry32

global process_init32
global process_get_info32
global process_get_user_info32
global process_get_switches32
global process_get_runtime32
global process_get_state32
global scheduler_switch32
global process_table
global current_process
global worker_counter
global process_spawn_user32
global process_kill_user32
global process_exit_current32
global process_spawn_fault32
global process_fault_current32
global process_set_exit_code32

PROCESS_STATE_READY   equ 1
PROCESS_STATE_RUNNING equ 2
PROCESS_STATE_EXITED  equ 3
PROCESS_STATE_FAULTED equ 4
PCB_PID    equ 0
PCB_STATE  equ 4
PCB_ESP    equ 8
PCB_STACK  equ 12
PCB_SIZE   equ 16
TASK_COUNT equ 4
USER_ENTRY equ 0x40000000
USER_DATA equ 0x40001000
USER_STACK_TOP equ 0x40003000
USER_KERNEL_FRAME_TOP equ 0x0008E000

process_init32:
    mov dword [process_table + PCB_PID],1
    mov dword [process_table + PCB_STATE],PROCESS_STATE_RUNNING
    mov dword [process_table + PCB_ESP],0
    mov dword [process_table + PCB_STACK],0x90000

    mov dword [process_table + PCB_SIZE + PCB_PID],2
    mov dword [process_table + PCB_SIZE + PCB_STATE],PROCESS_STATE_READY
    mov dword [process_table + PCB_SIZE + PCB_STACK],worker_a_stack_top
    mov edi,worker_a_stack_top
    mov eax,worker_a_entry32
    call build_initial_frame32
    mov [process_table + PCB_SIZE + PCB_ESP],eax

    mov dword [process_table + PCB_SIZE*2 + PCB_PID],3
    mov dword [process_table + PCB_SIZE*2 + PCB_STATE],PROCESS_STATE_READY
    mov dword [process_table + PCB_SIZE*2 + PCB_STACK],worker_b_stack_top
    mov edi,worker_b_stack_top
    mov eax,worker_b_entry32
    call build_initial_frame32
    mov [process_table + PCB_SIZE*2 + PCB_ESP],eax

    mov dword [process_table + PCB_SIZE*3 + PCB_PID],4
    mov dword [process_table + PCB_SIZE*3 + PCB_STATE],PROCESS_STATE_EXITED
    mov dword [process_table + PCB_SIZE*3 + PCB_ESP],0
    mov dword [process_table + PCB_SIZE*3 + PCB_STACK],USER_KERNEL_FRAME_TOP

    mov dword [current_process],0
    mov dword [scheduler_quantum],0
    mov dword [scheduler_switches],0
    mov dword [process_runtime_ticks],0
    mov dword [process_runtime_ticks+4],0
    mov dword [process_runtime_ticks+8],0
    mov dword [process_runtime_ticks+12],0
    ret

; EDI=stack top, EAX=entry. Return EAX=initial pushad/iretd frame.
build_initial_frame32:
    push ebx
    push ecx
    push edx
    mov ebx,eax
    sub edi,44
    xor eax,eax
    mov ecx,8
    mov edx,edi
.clear:
    mov [edx],eax
    add edx,4
    loop .clear
    lea eax,[edi+44]
    mov [edi+12],eax
    mov [edi+32],ebx
    mov dword [edi+36],0x08
    mov dword [edi+40],0x00000202
    mov eax,edi
    pop edx
    pop ecx
    pop ebx
    ret

; EAX=current IRQ frame ESP. Return EAX=frame selected to resume.
scheduler_switch32:
    push ebx
    push ecx
    push edx
    mov ecx,[current_process]
    inc dword [process_runtime_ticks+ecx*4]
    inc dword [scheduler_quantum]
    cmp dword [scheduler_quantum],10
    jb .same_task
    mov dword [scheduler_quantum],0
    inc dword [scheduler_switches]

    mov ecx,[current_process]
    mov edx,ecx
    shl edx,4
    mov [process_table+edx+PCB_ESP],eax
    mov dword [process_table+edx+PCB_STATE],PROCESS_STATE_READY

    mov ebx,TASK_COUNT
.find_next:
    inc ecx
    cmp ecx,TASK_COUNT
    jb .check_ready
    xor ecx,ecx
.check_ready:
    mov edx,ecx
    shl edx,4
    cmp dword [process_table+edx+PCB_STATE],PROCESS_STATE_READY
    je .next_ready
    dec ebx
    jnz .find_next
    mov ecx,[current_process]
.next_ready:
    mov [current_process],ecx
    mov edx,ecx
    shl edx,4
    mov dword [process_table+edx+PCB_STATE],PROCESS_STATE_RUNNING
    mov eax,[process_table+edx+PCB_ESP]
.same_task:
    pop edx
    pop ecx
    pop ebx
    ret

worker_a_entry32:
    inc dword [worker_counter]
    mov eax,[worker_counter]
    and eax,0x0F
    mov al,[hex_digits+eax]
    mov byte [0xB8000+156],al
    mov byte [0xB8000+157],0x0B
    hlt
    jmp worker_a_entry32

worker_b_entry32:
    inc dword [worker_b_counter]
    mov eax,[worker_b_counter]
    and eax,0x0F
    mov al,[hex_digits+eax]
    mov byte [0xB8000+158],al
    mov byte [0xB8000+159],0x0D
    hlt
    jmp worker_b_entry32

process_get_info32:
    mov esi,process_info
    ret

process_get_user_info32:
    pushad
    mov edi,process_info_buffer
    mov esi,user_info_prefix
    call process_append_string32
    mov eax,[process_table+PCB_SIZE*3+PCB_STATE]
    cmp eax,PROCESS_STATE_READY
    je .info_ready
    cmp eax,PROCESS_STATE_RUNNING
    je .info_running
    cmp eax,PROCESS_STATE_FAULTED
    je .info_faulted
    mov esi,state_exited
    jmp .info_state
.info_ready:
    mov esi,state_ready
    jmp .info_state
.info_running:
    mov esi,state_running
    jmp .info_state
.info_faulted:
    mov esi,state_faulted
.info_state:
    call process_append_string32
    mov esi,user_ticks_prefix
    call process_append_string32
    mov eax,[process_runtime_ticks+12]
    call process_append_uint32
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_FAULTED
    jne .check_exit_code
    mov esi,user_fault_prefix
    call process_append_string32
    mov eax,[process_fault_address]
    call process_append_hex32
    mov esi,user_error_prefix
    call process_append_string32
    mov eax,[process_fault_error]
    call process_append_hex32
    jmp .info_done
.check_exit_code:
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_EXITED
    jne .info_done
    mov esi,user_code_prefix
    call process_append_string32
    mov eax,[process_exit_code]
    call process_append_uint32
.info_done:
    mov byte [edi],0
    popad
    mov esi,process_info_buffer
    ret

process_append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

process_append_uint32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
    test eax,eax
    jnz .digits
    mov byte [edi],'0'
    inc edi
    jmp .number_done
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
.number_done:
    pop edx
    pop ecx
    pop ebx
    ret

process_append_hex32:
    push eax
    push ecx
    push edx
    mov ecx,8
.hex:
    rol eax,4
    mov edx,eax
    and edx,0x0F
    mov dl,[hex_digits+edx]
    mov [edi],dl
    inc edi
    loop .hex
    pop edx
    pop ecx
    pop eax
    ret

process_get_switches32:
    mov eax,[scheduler_switches]
    ret

; EAX=zero-based task index. Return its accumulated scheduled PIT ticks.
process_get_runtime32:
    cmp eax,TASK_COUNT
    jae .invalid
    mov eax,[process_runtime_ticks+eax*4]
    ret
.invalid:
    xor eax,eax
    ret

process_get_state32:
    cmp eax,TASK_COUNT
    jae .state_invalid
    shl eax,4
    mov eax,[process_table+eax+PCB_STATE]
    ret
.state_invalid:
    xor eax,eax
    ret

process_spawn_user32:
    pushad
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_READY
    je .spawn_busy
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_RUNNING
    je .spawn_busy
    call usermode_prepare32
    test eax,eax
    jz .spawn_failed
    mov edi,USER_KERNEL_FRAME_TOP-52
    xor eax,eax
    mov ecx,13
    rep stosd
    mov edi,USER_KERNEL_FRAME_TOP-52
    lea eax,[edi+52]
    mov [edi+12],eax
    call usermode_get_entry32
    mov [edi+32],eax
    mov dword [edi+36],0x1B
    mov dword [edi+40],0x00000202
    mov dword [edi+44],USER_STACK_TOP
    mov dword [edi+48],0x23
    mov dword [USER_DATA],0
    mov dword [USER_DATA+4],0
    mov dword [USER_DATA+8],0
    mov dword [USER_DATA+12],0
    mov dword [process_table+PCB_SIZE*3+PCB_ESP],USER_KERNEL_FRAME_TOP-52
    mov dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_READY
    mov dword [process_runtime_ticks+12],0
    mov dword [process_exit_code],0
    mov esi,spawn_ok
    jmp .spawn_done
.spawn_busy:
    mov esi,spawn_busy
    jmp .spawn_done
.spawn_failed:
    mov esi,spawn_failed
.spawn_done:
    mov [process_message_ptr],esi
    popad
    mov esi,[process_message_ptr]
    ret

process_spawn_fault32:
    pushad
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_READY
    je .fault_busy
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_RUNNING
    je .fault_busy
    call process_spawn_user32
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_READY
    jne .fault_spawn_done
    mov dword [USER_DATA+12],1
    mov esi,spawn_fault_ok
    jmp .fault_spawn_done
.fault_busy:
    mov esi,spawn_busy
.fault_spawn_done:
    mov [process_message_ptr],esi
    popad
    mov esi,[process_message_ptr]
    ret

process_kill_user32:
    pushad
    cmp dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_READY
    jne .kill_none
    mov dword [process_table+PCB_SIZE*3+PCB_STATE],PROCESS_STATE_EXITED
    call usermode_release32
    mov esi,kill_ok
    jmp .kill_done
.kill_none:
    mov esi,kill_none
.kill_done:
    mov [process_message_ptr],esi
    popad
    mov esi,[process_message_ptr]
    ret

; Terminate current task and select a READY frame to resume.
process_exit_current32:
    mov eax,PROCESS_STATE_EXITED
    jmp process_terminate_current32

process_set_exit_code32:
    mov [process_exit_code],ebx
    ret

; EAX=CR2, EBX=error code, ECX=faulting EIP. Return next task frame.
process_fault_current32:
    mov [process_fault_address],eax
    mov [process_fault_error],ebx
    mov [process_fault_eip],ecx
    mov eax,PROCESS_STATE_FAULTED

process_terminate_current32:
    push ebx
    push ecx
    push edx
    push ebp
    mov ebp,eax
    mov ecx,[current_process]
    mov edx,ecx
    shl edx,4
    mov [process_table+edx+PCB_STATE],ebp
    cmp ecx,3
    jne .resources_released
    call usermode_release32
.resources_released:
    mov ebx,TASK_COUNT
.exit_find:
    inc ecx
    cmp ecx,TASK_COUNT
    jb .exit_check
    xor ecx,ecx
.exit_check:
    mov edx,ecx
    shl edx,4
    cmp dword [process_table+edx+PCB_STATE],PROCESS_STATE_READY
    je .exit_found
    dec ebx
    jnz .exit_find
    xor ecx,ecx
    xor edx,edx
.exit_found:
    mov [current_process],ecx
    mov dword [process_table+edx+PCB_STATE],PROCESS_STATE_RUNNING
    mov eax,[process_table+edx+PCB_ESP]
    inc dword [scheduler_switches]
    pop ebp
    pop edx
    pop ecx
    pop ebx
    ret

align 4
process_table:
    times PCB_SIZE*TASK_COUNT db 0
current_process:    dd 0
scheduler_quantum:  dd 0
scheduler_switches: dd 0
process_runtime_ticks: times TASK_COUNT dd 0
worker_counter:     dd 0
worker_b_counter:   dd 0
process_info:
    db 'PID1 kernel | PID2 workerA | PID3 workerB | PID4 user (run)',0
spawn_ok: db 'PID4 user READY (about 5 seconds)',0
spawn_busy: db 'PID4 user is already active',0
spawn_fault_ok: db 'PID4 fault test READY',0
spawn_failed: db 'PID4 user page allocation failed',0
kill_ok: db 'PID4 terminated',0
kill_none: db 'PID4 is not READY',0
process_message_ptr: dd 0
user_info_prefix: db 'PID4 user state=',0
state_ready: db 'READY',0
state_running: db 'RUNNING',0
state_exited: db 'EXITED',0
state_faulted: db 'FAULTED',0
user_ticks_prefix: db ' ticks=',0
user_fault_prefix: db ' fault=0x',0
user_error_prefix: db ' err=0x',0
user_code_prefix: db ' code=',0
process_info_buffer: times 96 db 0
process_fault_address: dd 0
process_fault_error: dd 0
process_fault_eip: dd 0
process_exit_code: dd 0
hex_digits:
    db '0123456789ABCDEF'

align 16
worker_a_stack:
    times 512 db 0
worker_a_stack_top:
worker_b_stack:
    times 512 db 0
worker_b_stack_top:
