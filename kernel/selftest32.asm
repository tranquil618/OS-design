; OrangeOS runtime self-test
[BITS 32]

global selftest_run32

extern memory_get_free_pages32
extern memory_get_total_pages32
extern memory_get_used_pages32
extern process_get_switches32
extern process_get_runtime32
extern kmalloc32
extern kfree32
extern fs_is_ready32
extern fs_verify_large32
extern gdt_is_ready32
extern usermode_is_ready32

selftest_run32:
    pushad

    call gdt_is_ready32
    test eax,eax
    jz .fail_cpu

    mov eax,cr0
    and eax,0x80000001
    cmp eax,0x80000001
    jne .fail_cpu

    sidt [test_idtr]
    cmp dword [test_idtr+2],0
    je .fail_idt

    call memory_get_free_pages32
    test eax,eax
    jz .fail_memory
    mov ebx,eax
    call memory_get_total_pages32
    cmp eax,ebx
    jb .fail_memory
    mov ecx,eax
    call memory_get_used_pages32
    add eax,ebx
    cmp eax,ecx
    jne .fail_memory

    mov eax,16
    call kmalloc32
    test eax,eax
    jz .fail_heap
    call kfree32

    call process_get_switches32
    test eax,eax
    jz .fail_tasks
    xor ebx,ebx
    xor ecx,ecx
.sum_task_ticks:
    mov eax,ebx
    call process_get_runtime32
    add ecx,eax
    inc ebx
    cmp ebx,3
    jb .sum_task_ticks
    test ecx,ecx
    jz .fail_tasks

    call fs_is_ready32
    test eax,eax
    jz .fail_fs
    call fs_verify_large32
    test eax,eax
    jz .fail_fs

    call usermode_is_ready32
    test eax,eax
    jz .fail_user

    xor eax,eax
    int 0x80
    cmp eax,0xFFFFFFFF
    je .fail_syscall

    mov esi,message_pass
    jmp .done
.fail_cpu:
    mov esi,message_cpu
    jmp .done
.fail_idt:
    mov esi,message_idt
    jmp .done
.fail_memory:
    mov esi,message_memory
    jmp .done
.fail_heap:
    mov esi,message_heap
    jmp .done
.fail_tasks:
    mov esi,message_tasks
    jmp .done
.fail_fs:
    mov esi,message_fs
    jmp .done
.fail_syscall:
    mov esi,message_syscall
    jmp .done
.fail_user:
    mov esi,message_user
.done:
    mov [test_result],esi
    popad
    mov esi,[test_result]
    ret

message_pass:    db 'SELFTEST PASS: CPU PG IDT MEM HEAP TASK INT80 ATA FS RING3',0
message_cpu:     db 'SELFTEST FAIL: protected mode or paging',0
message_idt:     db 'SELFTEST FAIL: IDT',0
message_memory:  db 'SELFTEST FAIL: physical memory',0
message_heap:    db 'SELFTEST FAIL: kernel heap',0
message_tasks:   db 'SELFTEST FAIL: scheduler',0
message_fs:      db 'SELFTEST FAIL: OrangeFS',0
message_syscall: db 'SELFTEST FAIL: int 0x80',0
message_user:    db 'SELFTEST FAIL: Ring3 user pages',0

align 4
test_result: dd 0
test_idtr:   dw 0
             dd 0
