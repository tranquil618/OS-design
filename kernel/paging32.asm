; OrangeOS 32-bit identity paging
[BITS 32]

global paging_init32

%include "memory32.inc"

PAGE_PRESENT_RW equ 0x03
PAGE_SIZE       equ 4096
TABLE_SPAN      equ 0x00400000

; Build enough page tables to identity-map all managed physical memory.
paging_init32:
    pushad

    call memory_alloc_page32
    test eax, eax
    jz .failed
    mov [page_directory], eax

    mov edi, eax
    xor eax, eax
    mov ecx, 1024
    cld
    rep stosd

    call memory_get_limit32
    add eax, TABLE_SPAN-1
    jc .failed
    shr eax, 22
    mov ecx, eax
    test ecx, ecx
    jz .failed
    cmp ecx, 1024
    jbe .table_count_ready
    mov ecx, 1024
.table_count_ready:
    xor ebx, ebx
    xor edx, edx

.next_table:
    push ecx
    call memory_alloc_page32
    test eax, eax
    jz .failed_with_count

    mov esi, eax
    or eax, PAGE_PRESENT_RW
    mov edi, [page_directory]
    mov [edi + edx*4], eax

    mov edi, esi
    mov eax, ebx
    or eax, PAGE_PRESENT_RW
    mov ecx, 1024
.fill_table:
    stosd
    add eax, PAGE_SIZE
    loop .fill_table

    add ebx, TABLE_SPAN
    inc edx
    pop ecx
    loop .next_table

    mov eax, [page_directory]
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    jmp short .paging_active
.paging_active:
    mov byte [paging_enabled], 1
    popad
    ret

.failed_with_count:
    pop ecx
.failed:
    mov byte [paging_enabled], 0
    popad
    ret

page_directory: dd 0
paging_enabled: db 0
