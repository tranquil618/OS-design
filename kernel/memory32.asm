; OrangeOS BIOS memory-map reader
[BITS 32]

global memory_get_info32
global memory_init32
global memory_alloc_page32
global memory_alloc_info32
global memory_get_limit32

BOOT_MEMORY_KB  equ 0x0500
E820_COUNT      equ 0x0504
E820_TABLE      equ 0x0508
E820_ENTRY_SIZE equ 20
E820_TYPE       equ 16
E820_LENGTH_LOW equ 8

PAGE_SIZE       equ 4096
ALLOC_MIN_ADDR  equ 0x00100000

; Select the largest usable E820 region above 1 MB.
memory_init32:
    pushad
    mov dword [page_next], 0
    mov dword [page_limit], 0
    mov dword [free_pages], 0
    xor ebx, ebx
    mov ecx, [E820_COUNT]
    cmp ecx, 16
    jbe .count_ready
    mov ecx, 16
.count_ready:
    mov esi, E820_TABLE
.scan:
    test ecx, ecx
    jz .finish
    cmp dword [esi + E820_TYPE], 1
    jne .next
    cmp dword [esi + 4], 0
    jne .next
    cmp dword [esi + 12], 0
    jne .next

    mov edx, [esi]
    mov eax, [esi + E820_LENGTH_LOW]
    add eax, edx
    jc .next
    cmp eax, ALLOC_MIN_ADDR
    jbe .next
    cmp edx, ALLOC_MIN_ADDR
    jae .start_ready
    mov edx, ALLOC_MIN_ADDR
.start_ready:
    add edx, PAGE_SIZE-1
    and edx, 0xFFFFF000
    cmp eax, edx
    jbe .next
    sub eax, edx
    cmp eax, ebx
    jbe .next
    mov ebx, eax
    mov [page_next], edx
    add eax, edx
    and eax, 0xFFFFF000
    mov [page_limit], eax
.next:
    add esi, E820_ENTRY_SIZE
    dec ecx
    jmp .scan
.finish:
    mov eax, [page_limit]
    sub eax, [page_next]
    shr eax, 12
    mov [free_pages], eax
    popad
    ret

; Allocate one 4 KB physical page. Return EAX=address or zero.
memory_alloc_page32:
    pushfd
    cli
    push edx
    mov eax, [page_next]
    test eax, eax
    jz .failed
    mov edx, eax
    add edx, PAGE_SIZE
    cmp edx, [page_limit]
    ja .failed
    mov [page_next], edx
    dec dword [free_pages]
    pop edx
    popfd
    ret
.failed:
    xor eax, eax
    pop edx
    popfd
    ret

; Return the exclusive upper bound of managed physical memory in EAX.
memory_get_limit32:
    mov eax, [page_limit]
    ret

; Return ESI pointing to a summary built from BIOS boot information.
memory_get_info32:
    pushad
    mov edi, memory_buffer

    mov esi, memory_base_prefix
    call append_string32
    movzx eax, word [BOOT_MEMORY_KB]
    call append_uint32

    mov esi, memory_usable_prefix
    call append_string32

    xor eax, eax
    mov ecx, [E820_COUNT]
    cmp ecx, 16
    jbe .count_ready
    mov ecx, 16
.count_ready:
    mov esi, E820_TABLE
.sum_entries:
    test ecx, ecx
    jz .sum_done
    cmp dword [esi + E820_TYPE], 1
    jne .next_entry
    add eax, [esi + E820_LENGTH_LOW]
.next_entry:
    add esi, E820_ENTRY_SIZE
    dec ecx
    jmp .sum_entries
.sum_done:
    shr eax, 20
    call append_uint32

    mov esi, memory_suffix
    call append_string32
    mov eax, [free_pages]
    call append_uint32
    mov esi, memory_pages_suffix
    call append_string32
    mov byte [edi], 0

    popad
    mov esi, memory_buffer
    ret

; Allocate a page and return a printable result in ESI.
memory_alloc_info32:
    pushad
    call memory_alloc_page32
    mov edx, eax
    mov edi, allocation_buffer
    test edx, edx
    jz .no_memory
    mov esi, allocation_prefix
    call append_string32
    mov eax, edx
    call append_hex32
    mov byte [edi], 0
    jmp .ready
.no_memory:
    mov esi, allocation_failed
    call append_string32
    mov byte [edi], 0
.ready:
    popad
    mov esi, allocation_buffer
    ret

; Append the zero-terminated string at ESI to EDI.
append_string32:
.copy:
    lodsb
    test al, al
    jz .done
    stosb
    jmp .copy
.done:
    ret

; Append unsigned EAX in decimal to EDI.
append_uint32:
    push ebx
    push ecx
    push edx
    xor ecx, ecx
    mov ebx, 10
    test eax, eax
    jnz .make_digits
    mov byte [edi], '0'
    inc edi
    jmp .done
.make_digits:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .make_digits
.write_digits:
    pop edx
    add dl, '0'
    mov [edi], dl
    inc edi
    loop .write_digits
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Append EAX as eight hexadecimal digits.
append_hex32:
    push eax
    push ecx
    push edx
    mov ecx, 8
.hex_loop:
    rol eax, 4
    mov edx, eax
    and edx, 0x0F
    mov dl, [hex_digits + edx]
    mov [edi], dl
    inc edi
    loop .hex_loop
    pop edx
    pop ecx
    pop eax
    ret

memory_base_prefix:   db 'Memory: base=', 0
memory_usable_prefix: db ' KB usable=', 0
memory_suffix:        db ' MB free=', 0
memory_pages_suffix:  db ' pages', 0
allocation_prefix:    db 'Allocated page: 0x', 0
allocation_failed:    db 'Out of physical memory', 0
hex_digits:           db '0123456789ABCDEF'
memory_buffer:        times 64 db 0
allocation_buffer:    times 40 db 0

align 4
page_next:  dd 0
page_limit: dd 0
free_pages: dd 0
