; OrangeOS persistent fixed-slot filesystem
[BITS 32]

global fs_init32
global fs_list32
global fs_cat32
global fs_write32
global fs_create32
global fs_delete32
global fs_is_ready32

%include "ata32.inc"

ORANGEFS_LBA equ 34
FILE_COUNT   equ 4
NAME_SIZE    equ 16
CONTENT_SIZE equ 64
ENTRY_SIZE   equ NAME_SIZE+CONTENT_SIZE

fs_init32:
    mov eax,ORANGEFS_LBA
    mov edi,fs_sector
    call ata_read_sector32
    cmp dword [fs_sector],0x3246524F ; "ORF2"
    je .ready
    mov esi,default_sector
    mov edi,fs_sector
    mov ecx,128
    cld
    rep movsd
    call fs_save32
.ready:
    ret

fs_save32:
    mov eax,ORANGEFS_LBA
    mov esi,fs_sector
    call ata_write_sector32
    ret

fs_is_ready32:
    xor eax,eax
    cmp dword [fs_sector],0x3246524F
    jne .done
    mov eax,1
.done:
    ret

; Return a generated file list in ESI.
fs_list32:
    pushad
    mov esi,fs_sector+4
    mov edi,list_buffer
    mov ecx,FILE_COUNT
.entry:
    cmp byte [esi],0
    je .next
    push esi
.name:
    lodsb
    test al,al
    jz .separator
    stosb
    jmp .name
.separator:
    mov al,' '
    stosb
    stosb
    pop esi
.next:
    add esi,ENTRY_SIZE
    loop .entry
    cmp edi,list_buffer
    je .terminate
    sub edi,2
.terminate:
    mov byte [edi],0
    popad
    mov esi,list_buffer
    ret

; ESI=filename. Return EAX=1 and ESI=contents, otherwise EAX=0.
fs_cat32:
    call fs_find32
    test eax,eax
    jz .done
    lea esi,[edi+NAME_SIZE]
.done:
    ret

; ESI=filename, EDI=contents. Return EAX=1 or zero.
fs_write32:
    push ebx
    mov ebx,edi
    call fs_find32
    test eax,eax
    jz .done
    lea edi,[edi+NAME_SIZE]
    mov esi,ebx
    mov ecx,CONTENT_SIZE-1
    call fs_copy_limited32
    call fs_save32
    mov eax,1
.done:
    pop ebx
    ret

; ESI=filename. Return 1=created, 2=exists, 0=invalid/full.
fs_create32:
    push ebx
    push ecx
    push edx
    mov ebx,esi
    xor ecx,ecx
.length:
    cmp byte [ebx+ecx],0
    je .length_ready
    inc ecx
    cmp ecx,NAME_SIZE
    jae .failed
    jmp .length
.length_ready:
    test ecx,ecx
    jz .failed
    mov esi,ebx
    call fs_find32
    test eax,eax
    jnz .exists
    mov edi,fs_sector+4
    mov ecx,FILE_COUNT
.find_empty:
    cmp byte [edi],0
    je .empty
    add edi,ENTRY_SIZE
    loop .find_empty
    jmp .failed
.empty:
    push edi
    mov esi,ebx
    mov ecx,NAME_SIZE-1
    call fs_copy_limited32
    pop edi
    add edi,NAME_SIZE
    xor eax,eax
    mov ecx,CONTENT_SIZE/4
    rep stosd
    call fs_save32
    mov eax,1
    jmp .done
.exists:
    mov eax,2
    jmp .done
.failed:
    xor eax,eax
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ESI=filename. Return EAX=1 when deleted.
fs_delete32:
    call fs_find32
    test eax,eax
    jz .done
    xor eax,eax
    mov ecx,ENTRY_SIZE/4
    rep stosd
    call fs_save32
    mov eax,1
.done:
    ret

; ESI=filename. Return EAX=1 and EDI=entry, otherwise zero.
fs_find32:
    push ebx
    push ecx
    push edx
    push esi
    mov ebx,esi
    mov edi,fs_sector+4
    mov ecx,FILE_COUNT
.scan:
    cmp byte [edi],0
    je .next
    mov esi,ebx
    call fs_name_equal32
    test eax,eax
    jnz .found
.next:
    add edi,ENTRY_SIZE
    loop .scan
    xor eax,eax
    xor edi,edi
    jmp .done
.found:
    mov eax,1
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

fs_name_equal32:
    push esi
    push edi
.compare:
    mov al,[esi]
    cmp al,[edi]
    jne .different
    test al,al
    je .same
    inc esi
    inc edi
    jmp .compare
.same:
    mov eax,1
    jmp .done
.different:
    xor eax,eax
.done:
    pop edi
    pop esi
    ret

; Copy at most ECX characters and always append zero.
fs_copy_limited32:
.copy:
    lodsb
    test al,al
    jz .terminate
    stosb
    loop .copy
.terminate:
    mov byte [edi],0
    ret

align 4
default_sector:
    db 'ORF2'
    db 'hello.txt',0
    times NAME_SIZE-($-(default_sector+4)) db 0
    db 'Hello from OrangeFS!',0
    times CONTENT_SIZE-($-(default_sector+4+NAME_SIZE)) db 0
    db 'about.txt',0
    times NAME_SIZE-($-(default_sector+4+ENTRY_SIZE)) db 0
    db 'OrangeOS educational operating system',0
    times CONTENT_SIZE-($-(default_sector+4+ENTRY_SIZE+NAME_SIZE)) db 0
    db 'config.txt',0
    times NAME_SIZE-($-(default_sector+4+ENTRY_SIZE*2)) db 0
    db 'mode=protected bits=32 paging=on',0
    times CONTENT_SIZE-($-(default_sector+4+ENTRY_SIZE*2+NAME_SIZE)) db 0
    times ENTRY_SIZE db 0
    times 512-($-default_sector) db 0

fs_sector:   times 512 db 0
list_buffer: times FILE_COUNT*(NAME_SIZE+2) db 0
