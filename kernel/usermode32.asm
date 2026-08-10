; OrangeOS isolated Ring-3 demonstration program
[BITS 32]

global usermode_init32
global usermode_run32
global usermode_return32
global usermode_is_ready32
global usermode_prepare32
global usermode_release32
global usermode_load_oex32
global usermode_get_entry32

extern memory_alloc_page32
extern memory_free_page32
extern paging_map_user32
extern paging_unmap_user32

USER_CODE equ 0x40000000
USER_DATA equ 0x40001000
USER_STACK_TOP equ 0x40003000
USER_CS equ 0x1B
USER_DS equ 0x23
KERNEL_DS equ 0x10

usermode_init32:
    mov dword [user_code_phys],0
    mov dword [user_data_phys],0
    mov dword [user_stack_phys],0
    mov byte [user_pages_active],0
    mov byte [user_ready],1
    ; Create the reusable user page-table skeleton, then return all three
    ; process-owned pages so the first run has the same accounting baseline.
    call usermode_prepare32
    test eax,eax
    jz .init_failed
    call usermode_release32
    ret
.init_failed:
    mov byte [user_ready],0
    ret

usermode_prepare32:
    cmp byte [user_pages_active],0
    jne .already_active
    pushad
    mov dword [prepare_result],0
    call memory_alloc_page32
    test eax,eax
    jz .done
    mov [user_code_phys],eax
    mov ebx,eax
    mov eax,USER_CODE
    call paging_map_user32
    test eax,eax
    jz .done

    call memory_alloc_page32
    test eax,eax
    jz .done
    mov [user_data_phys],eax
    mov ebx,eax
    mov eax,USER_DATA
    call paging_map_user32
    test eax,eax
    jz .done

    call memory_alloc_page32
    test eax,eax
    jz .done
    mov [user_stack_phys],eax
    mov ebx,eax
    mov eax,USER_STACK_TOP-4096
    call paging_map_user32
    test eax,eax
    jz .done

    mov esi,user_blob_start
    mov edi,[user_code_phys]
    mov ecx,user_blob_end-user_blob_start
    rep movsb
    mov edi,[user_data_phys]
    xor eax,eax
    mov ecx,1024
    rep stosd
    mov byte [user_pages_active],1
    mov dword [user_entry_address],USER_CODE
    mov dword [prepare_result],1
.done:
    popad
    cmp dword [prepare_result],1
    je .prepare_return
    call usermode_release32
.prepare_return:
    mov eax,[prepare_result]
    ret
.already_active:
    mov eax,1
    ret

usermode_release32:
    pushad
    cmp dword [user_code_phys],0
    je .release_data
    mov eax,USER_CODE
    call paging_unmap_user32
    mov eax,[user_code_phys]
    call memory_free_page32
    mov dword [user_code_phys],0
.release_data:
    cmp dword [user_data_phys],0
    je .release_stack
    mov eax,USER_DATA
    call paging_unmap_user32
    mov eax,[user_data_phys]
    call memory_free_page32
    mov dword [user_data_phys],0
.release_stack:
    cmp dword [user_stack_phys],0
    je .release_done
    mov eax,USER_STACK_TOP-4096
    call paging_unmap_user32
    mov eax,[user_stack_phys]
    call memory_free_page32
    mov dword [user_stack_phys],0
.release_done:
    mov byte [user_pages_active],0
    popad
    ret

; ESI="OEX2:EE:LL:CC:" + hex code. EE=entry, LL=length, CC=sum8.
; Return EAX=1 on success; ESI points to a diagnostic message.
usermode_load_oex32:
    mov [load_source],esi
    call usermode_prepare32
    test eax,eax
    jz oex_load_no_memory32
    mov esi,[load_source]
    mov edi,oex_magic
    mov ecx,5
.magic:
    mov al,[esi]
    cmp al,[edi]
    jne oex_load_invalid32
    inc esi
    inc edi
    loop .magic

    call oex_read_byte32
    cmp eax,0xFFFFFFFF
    je oex_load_invalid32
    mov [oex_entry],eax
    cmp byte [esi],':'
    jne oex_load_invalid32
    inc esi
    call oex_read_byte32
    cmp eax,0xFFFFFFFF
    je oex_load_invalid32
    test eax,eax
    jz oex_load_invalid32
    mov [oex_length],eax
    cmp byte [esi],':'
    jne oex_load_invalid32
    inc esi
    call oex_read_byte32
    cmp eax,0xFFFFFFFF
    je oex_load_invalid32
    mov [oex_checksum],eax
    cmp byte [esi],':'
    jne oex_load_invalid32
    inc esi
    mov eax,[oex_entry]
    cmp eax,[oex_length]
    jae oex_load_invalid32

    mov edi,[user_code_phys]
    push esi
    push edi
    xor eax,eax
    mov ecx,1024
    rep stosd
    pop edi
    pop esi
    xor ecx,ecx
    xor edx,edx
.decode:
    cmp ecx,[oex_length]
    jae .decode_done
    call oex_read_byte32
    cmp eax,0xFFFFFFFF
    je oex_load_invalid32
    mov [edi],al
    add dl,al
    inc edi
    inc ecx
    jmp .decode
.decode_done:
    cmp byte [esi],0
    jne oex_load_invalid32
    movzx eax,dl
    cmp eax,[oex_checksum]
    jne oex_load_invalid32
    mov eax,[oex_entry]
    add eax,USER_CODE
    mov [user_entry_address],eax
    mov eax,1
    mov esi,oex_loaded
    ret

; Read two hexadecimal characters at ESI; advance ESI by two.
oex_read_byte32:
    mov al,[esi]
    call oex_hex_nibble32
    cmp eax,0xFFFFFFFF
    je .read_bad
    mov bh,al
    shl bh,4
    inc esi
    mov al,[esi]
    call oex_hex_nibble32
    cmp eax,0xFFFFFFFF
    je .read_bad
    or al,bh
    movzx eax,al
    inc esi
    ret
.read_bad:
    mov eax,0xFFFFFFFF
    ret
oex_load_invalid32:
    call usermode_release32
    xor eax,eax
    mov esi,oex_invalid
    ret
oex_load_no_memory32:
    xor eax,eax
    mov esi,oex_no_memory
    ret

oex_hex_nibble32:
    movzx eax,al
    cmp al,'0'
    jb .bad
    cmp al,'9'
    jbe .decimal
    cmp al,'A'
    jb .lowercase
    cmp al,'F'
    jbe .upper
.lowercase:
    cmp al,'a'
    jb .bad
    cmp al,'f'
    ja .bad
    sub eax,'a'-10
    ret
.upper:
    sub eax,'A'-10
    ret
.decimal:
    sub eax,'0'
    ret
.bad:
    mov eax,0xFFFFFFFF
    ret

usermode_is_ready32:
    movzx eax,byte [user_ready]
    ret

usermode_get_entry32:
    mov eax,[user_entry_address]
    ret

usermode_run32:
    cmp byte [user_ready],1
    jne usermode_not_ready32
    call usermode_prepare32
    test eax,eax
    jz usermode_not_ready32
    mov dword [USER_DATA+12],0
    mov [kernel_saved_esp],esp
    push dword USER_DS
    push dword USER_STACK_TOP
    pushfd
    or dword [esp],0x200
    push dword USER_CS
    push dword USER_CODE
    iretd

usermode_return32:
    cli
    mov ax,KERNEL_DS
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov esp,[kernel_saved_esp]
    call user_build_result32
    call usermode_release32
    mov esi,user_result
    ret
usermode_not_ready32:
    mov esi,user_not_ready
    ret

user_build_result32:
    mov edi,user_result
    mov esi,user_result_prefix
    call user_append_string32
    mov eax,[USER_DATA]
    call user_append_uint32
    mov esi,user_free
    call user_append_string32
    mov eax,[USER_DATA+4]
    call user_append_uint32
    mov esi,user_pid
    call user_append_string32
    mov eax,[USER_DATA+8]
    call user_append_uint32
    mov byte [edi],0
    mov esi,user_result
    ret

user_append_string32:
.copy:
    lodsb
    test al,al
    jz .done
    stosb
    jmp .copy
.done:
    ret

user_append_uint32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
    test eax,eax
    jnz .digits
    mov byte [edi],'0'
    inc edi
    jmp .finished
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
.finished:
    pop edx
    pop ecx
    pop ebx
    ret

; Copied to the user-only code page. It can access only USER_DATA/stack.
user_blob_start:
    mov ax,USER_DS
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    cmp dword [USER_DATA+12],0
    je .normal_program
    mov eax,[0x50000000]
.normal_program:
    xor eax,eax
    int 0x80
    mov [USER_DATA],eax
    mov ebx,eax
.run_loop:
    xor eax,eax
    int 0x80
    sub eax,ebx
    cmp eax,500
    jb .run_loop
    mov eax,1
    int 0x80
    mov [USER_DATA+4],eax
    mov eax,2
    int 0x80
    mov [USER_DATA+8],eax
    mov eax,3
    int 0x80
.hang:
    jmp .hang
user_blob_end:

user_result_prefix: db 'Ring3 OK: ticks=',0
user_free: db ' free=',0
user_pid: db ' pid=',0
user_not_ready: db 'Ring3 unavailable: user pages not initialized',0
user_result: times 64 db 0
user_ready: db 0
user_pages_active: db 0
align 4
prepare_result: dd 0
kernel_saved_esp: dd 0
user_code_phys: dd 0
user_data_phys: dd 0
user_stack_phys: dd 0
load_source: dd 0
oex_magic: db 'OEX2:'
oex_loaded: db 'OEX2 image loaded',0
oex_invalid: db 'Invalid OEX2 executable',0
oex_no_memory: db 'OEX2 load failed: no memory',0
user_entry_address: dd USER_CODE
oex_entry: dd 0
oex_length: dd 0
oex_checksum: dd 0
