; OrangeOS 32-bit identity paging
[BITS 32]

global paging_init32
global paging_map_user32
global paging_unmap_user32

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

; EAX=user virtual address, EBX=physical page. Return EAX=1 on success.
paging_map_user32:
    pushfd
    cli
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi,eax
    mov edi,ebx
    test esi,PAGE_SIZE-1
    jnz .map_failed
    test edi,PAGE_SIZE-1
    jnz .map_failed
    mov edx,esi
    shr edx,22
    mov ebx,[page_directory]
    mov eax,[ebx+edx*4]
    test eax,1
    jnz .table_present
    call memory_alloc_page32
    test eax,eax
    jz .map_failed
    mov ecx,eax
    push edi
    mov edi,eax
    xor eax,eax
    push ecx
    mov ecx,1024
    rep stosd
    pop ecx
    pop edi
    mov eax,ecx
    or eax,0x07
    mov [ebx+edx*4],eax
    jmp .table_ready
.table_present:
    or dword [ebx+edx*4],0x04
    and eax,0xFFFFF000
    mov ecx,eax
.table_ready:
    mov eax,esi
    shr eax,12
    and eax,0x3FF
    or edi,0x07
    mov [ecx+eax*4],edi
    invlpg [esi]
    mov eax,1
    jmp .map_done
.map_failed:
    xor eax,eax
.map_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popfd
    ret

; EAX=user virtual page. Clear its PTE and invalidate the TLB entry.
paging_unmap_user32:
    pushfd
    cli
    push ebx
    push ecx
    push edx
    mov edx,eax
    test edx,PAGE_SIZE-1
    jnz .unmap_failed
    mov ecx,edx
    shr ecx,22
    mov ebx,[page_directory]
    mov ebx,[ebx+ecx*4]
    test ebx,1
    jz .unmap_failed
    and ebx,0xFFFFF000
    mov ecx,edx
    shr ecx,12
    and ecx,0x3FF
    mov dword [ebx+ecx*4],0
    invlpg [edx]
    mov eax,1
    jmp .unmap_done
.unmap_failed:
    xor eax,eax
.unmap_done:
    pop edx
    pop ecx
    pop ebx
    popfd
    ret

page_directory: dd 0
paging_enabled: db 0
