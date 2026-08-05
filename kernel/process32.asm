; OrangeOS three-task round-robin scheduler
[BITS 32]

global process_init32
global process_get_info32
global process_get_switches32
global scheduler_switch32
global process_table
global current_process
global worker_counter

PROCESS_STATE_READY   equ 1
PROCESS_STATE_RUNNING equ 2
PCB_PID    equ 0
PCB_STATE  equ 4
PCB_ESP    equ 8
PCB_STACK  equ 12
PCB_SIZE   equ 16
TASK_COUNT equ 3

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

    mov dword [current_process],0
    mov dword [scheduler_quantum],0
    mov dword [scheduler_switches],0
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

    inc ecx
    cmp ecx,TASK_COUNT
    jb .next_ready
    xor ecx,ecx
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

process_get_switches32:
    mov eax,[scheduler_switches]
    ret

align 4
process_table:
    times PCB_SIZE*TASK_COUNT db 0
current_process:    dd 0
scheduler_quantum:  dd 0
scheduler_switches: dd 0
worker_counter:     dd 0
worker_b_counter:   dd 0
process_info:
    db 'PID1 kernel | PID2 workerA | PID3 workerB | RR enabled',0
hex_digits:
    db '0123456789ABCDEF'

align 16
worker_a_stack:
    times 512 db 0
worker_a_stack_top:
worker_b_stack:
    times 512 db 0
worker_b_stack_top:
