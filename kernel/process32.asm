; OrangeOS process control block foundation
[BITS 32]

global process_init32
global process_get_info32
global process_table
global current_process
global scheduler_switch32
global worker_counter

PROCESS_STATE_READY   equ 1
PROCESS_STATE_RUNNING equ 2
PCB_PID    equ 0
PCB_STATE  equ 4
PCB_ESP    equ 8
PCB_STACK  equ 12
PCB_SIZE   equ 16

process_init32:
    mov dword [process_table + PCB_PID], 1
    mov dword [process_table + PCB_STATE], PROCESS_STATE_RUNNING
    mov dword [process_table + PCB_ESP], 0
    mov dword [process_table + PCB_STACK], 0x90000
    mov dword [process_table + PCB_SIZE + PCB_PID], 2
    mov dword [process_table + PCB_SIZE + PCB_STATE], PROCESS_STATE_READY
    ; Build the initial interrupt-return frame for the worker task.
    mov edi, worker_stack_top
    sub edi, 44
    xor eax, eax
    mov ecx, 8
    mov edx, edi
.clear_worker_registers:
    mov [edx], eax
    add edx, 4
    loop .clear_worker_registers
    mov dword [edi + 12], worker_stack_top
    mov dword [edi + 32], worker_entry32
    mov dword [edi + 36], 0x08
    mov dword [edi + 40], 0x00000202
    mov [process_table + PCB_SIZE + PCB_ESP], edi
    mov dword [process_table + PCB_SIZE + PCB_STACK], worker_stack_top
    mov dword [current_process], 0
    ret

; EAX is the current IRQ register-frame ESP.
; Return EAX as the frame ESP that IRQ0 should restore.
scheduler_switch32:
    push ebx
    push ecx
    push edx

    inc dword [scheduler_quantum]
    cmp dword [scheduler_quantum], 10
    jb .same_task
    mov dword [scheduler_quantum], 0

    mov ecx, [current_process]
    mov edx, ecx
    shl edx, 4
    mov [process_table + edx + PCB_ESP], eax
    mov dword [process_table + edx + PCB_STATE], PROCESS_STATE_READY

    xor ecx, 1
    mov [current_process], ecx
    mov edx, ecx
    shl edx, 4
    mov dword [process_table + edx + PCB_STATE], PROCESS_STATE_RUNNING
    mov eax, [process_table + edx + PCB_ESP]

.same_task:
    pop edx
    pop ecx
    pop ebx
    ret

; A small independent task used to prove that context switching works.
worker_entry32:
    inc dword [worker_counter]
    mov eax, [worker_counter]
    and eax, 0x0F
    mov al, [hex_digits + eax]
    mov byte [0xB8000 + 158], al
    mov byte [0xB8000 + 159], 0x0B
    hlt
    jmp worker_entry32

process_get_info32:
    mov esi, process_info
    ret

align 4
process_table:
    times PCB_SIZE * 2 db 0
current_process:
    dd 0
scheduler_quantum:
    dd 0
worker_counter:
    dd 0
process_info:
    db 'PID 1 kernel | PID 2 worker | round-robin enabled', 0
hex_digits:
    db '0123456789ABCDEF'

align 16
worker_stack:
    times 512 db 0
worker_stack_top:
