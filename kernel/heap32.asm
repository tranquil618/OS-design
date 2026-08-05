; OrangeOS one-page first-fit kernel heap
[BITS 32]

global heap_init32
global kmalloc32
global kfree32
global heap_alloc_info32
global heap_free_info32

%include "memory32.inc"

HEAP_PAGE_SIZE equ 4096
BLOCK_HEADER   equ 8

heap_init32:
    call memory_alloc_page32
    test eax,eax
    jz .failed
    mov [heap_base],eax
    mov [free_head],eax
    mov dword [eax],HEAP_PAGE_SIZE-BLOCK_HEADER
    mov dword [eax+4],0
    mov dword [last_allocation],0
    ret
.failed:
    mov dword [heap_base],0
    mov dword [free_head],0
    ret

; EAX=requested bytes. Return EAX=payload address or zero.
kmalloc32:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    test eax,eax
    jz .not_found
    add eax,7
    and eax,0xFFFFFFF8
    mov edi,eax
    xor ebx,ebx
    mov esi,[free_head]
.search:
    test esi,esi
    jz .not_found
    mov ecx,[esi]
    cmp ecx,edi
    jae .found
    mov ebx,esi
    mov esi,[esi+4]
    jmp .search
.found:
    mov edx,ecx
    sub edx,edi
    cmp edx,BLOCK_HEADER+8
    jb .consume_whole

    lea eax,[esi+BLOCK_HEADER+edi]
    sub edx,BLOCK_HEADER
    mov [eax],edx
    mov edx,[esi+4]
    mov [eax+4],edx
    test ebx,ebx
    jz .replace_head
    mov [ebx+4],eax
    jmp .allocated
.replace_head:
    mov [free_head],eax
    jmp .allocated

.consume_whole:
    mov eax,[esi+4]
    test ebx,ebx
    jz .consume_head
    mov [ebx+4],eax
    jmp .allocated_whole
.consume_head:
    mov [free_head],eax
.allocated_whole:
    mov edi,ecx

.allocated:
    mov [esi],edi
    lea eax,[esi+BLOCK_HEADER]
    jmp .done
.not_found:
    xor eax,eax
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; EAX=payload address. Insert the block and coalesce neighbours.
kfree32:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    test eax,eax
    jz .done
    lea edi,[eax-BLOCK_HEADER]
    xor ebx,ebx
    mov esi,[free_head]
.find_position:
    test esi,esi
    jz .insert
    cmp esi,edi
    ja .insert
    mov ebx,esi
    mov esi,[esi+4]
    jmp .find_position
.insert:
    mov [edi+4],esi
    test ebx,ebx
    jz .insert_head
    mov [ebx+4],edi
    jmp .merge_next
.insert_head:
    mov [free_head],edi

.merge_next:
    test esi,esi
    jz .merge_previous
    mov edx,[edi]
    lea ecx,[edi+BLOCK_HEADER+edx]
    cmp ecx,esi
    jne .merge_previous
    add edx,BLOCK_HEADER
    add edx,[esi]
    mov [edi],edx
    mov edx,[esi+4]
    mov [edi+4],edx

.merge_previous:
    test ebx,ebx
    jz .done
    mov edx,[ebx]
    lea ecx,[ebx+BLOCK_HEADER+edx]
    cmp ecx,edi
    jne .done
    add edx,BLOCK_HEADER
    add edx,[edi]
    mov [ebx],edx
    mov edx,[edi+4]
    mov [ebx+4],edx
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

heap_alloc_info32:
    pushad
    mov eax,64
    call kmalloc32
    mov [last_allocation],eax
    mov edi,heap_message_buffer
    test eax,eax
    jz .allocation_failed
    mov edx,eax
    mov esi,heap_alloc_prefix
    call heap_append_string32
    mov eax,edx
    call heap_append_hex32
    mov byte [edi],0
    jmp .alloc_ready
.allocation_failed:
    mov esi,heap_no_memory
    call heap_append_string32
    mov byte [edi],0
.alloc_ready:
    popad
    mov esi,heap_message_buffer
    ret

heap_free_info32:
    pushad
    mov eax,[last_allocation]
    mov edi,heap_message_buffer
    test eax,eax
    jz .nothing_to_free
    call kfree32
    mov dword [last_allocation],0
    mov esi,heap_free_ok
    call heap_append_string32
    mov byte [edi],0
    jmp .free_ready
.nothing_to_free:
    mov esi,heap_free_none
    call heap_append_string32
    mov byte [edi],0
.free_ready:
    popad
    mov esi,heap_message_buffer
    ret

heap_append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

heap_append_hex32:
    mov ecx,8
.digit:
    rol eax,4
    mov edx,eax
    and edx,0x0F
    mov dl,[heap_hex_digits+edx]
    mov [edi],dl
    inc edi
    loop .digit
    ret

heap_alloc_prefix: db 'Heap allocated 64 bytes at 0x',0
heap_no_memory:    db 'Kernel heap out of memory',0
heap_free_ok:      db 'Last heap block freed',0
heap_free_none:    db 'No heap block to free',0
heap_hex_digits:   db '0123456789ABCDEF'
heap_message_buffer: times 48 db 0

align 4
heap_base:       dd 0
free_head:       dd 0
last_allocation: dd 0
