; OrangeFS v8: dual directories plus per-file data checksums
[BITS 32]

global fs_init32
global fs_list32
global fs_cat32
global fs_write32
global fs_create32
global fs_delete32
global fs_is_ready32
global fs_stat32
global fs_verify_large32
global fs_disk_info32

%include "ata32.inc"

DIR_LBA      equ 42
BACKUP_LBA   equ 75
DATA_LBA     equ 43
FILE_COUNT   equ 7
NAME_SIZE    equ 16
ENTRY_SIZE   equ 24
E_SIZE       equ 16
E_START      equ 18
E_SECTORS    equ 20
E_FLAGS      equ 21
E_CHECKSUM   equ 22
FILE_CAPACITY equ 1024
ENTRY_BASE    equ 8
POOL_SECTORS  equ 32
DIR_VERSION   equ 176

fs_init32:
    push ebx
    mov eax,DIR_LBA
    mov edi,fs_directory
    call ata_read_sector32
    xor ebx,ebx
    cmp dword [fs_directory],0x3846524F ; ORF8
    jne .read_backup
    call fs_verify_directory32
    test eax,eax
    jz .read_backup
    mov ebx,1
.read_backup:
    mov eax,BACKUP_LBA
    mov edi,fs_backup_directory
    call ata_read_sector32
    xor edx,edx
    cmp dword [fs_backup_directory],0x3846524F
    jne .choose
    mov esi,fs_backup_directory
    call fs_verify_buffer32
    test eax,eax
    jz .choose
    mov edx,1
.choose:
    test ebx,ebx
    jz .primary_bad
    test edx,edx
    jz .sync_primary
    mov eax,[fs_backup_directory+DIR_VERSION]
    cmp eax,[fs_directory+DIR_VERSION]
    jbe .sync_primary
    call fs_restore_backup32
    jmp .sync_primary
.primary_bad:
    test edx,edx
    jz .format
    call fs_restore_backup32
.sync_primary:
    call fs_sync_directory32
    jmp .ready
.format:
    call fs_format32
.ready:
    pop ebx
    ret

fs_restore_backup32:
    pushad
    mov esi,fs_backup_directory
    mov edi,fs_directory
    mov ecx,128
    rep movsd
    popad
    ret

fs_format32:
    mov esi,default_directory
    mov edi,fs_directory
    mov ecx,128
    rep movsd
    call fs_save_directory32
    mov esi,default_hello
    mov eax,DATA_LBA
    mov edx,1
    call fs_write_default32
    mov esi,default_about
    mov eax,DATA_LBA+1
    mov edx,1
    call fs_write_default32
    mov esi,default_config
    mov eax,DATA_LBA+2
    mov edx,1
    call fs_write_default32
    mov esi,default_demo
    mov eax,DATA_LBA+3
    mov edx,1
    call fs_write_default32
    mov esi,default_bad
    mov eax,DATA_LBA+4
    mov edx,1
    call fs_write_default32
    call fs_write_large_default32
    call fs_refresh_checksums32
    call fs_save_directory32
    ret

fs_write_large_default32:
    mov edi,file_buffer
    mov ecx,700
    mov al,'A'
    rep stosb
    mov byte [edi],0
    mov eax,DATA_LBA+5
    mov esi,file_buffer
    mov ecx,2
    call fs_write_extent32
    ret

fs_write_default32:
    push eax
    push edx
    mov edi,file_buffer
    xor eax,eax
    mov ecx,FILE_CAPACITY/4
    rep stosd
    mov edi,file_buffer
.copy:
    lodsb
    stosb
    test al,al
    jnz .copy
    pop ecx
    pop eax
    mov esi,file_buffer
    call fs_write_extent32
    ret

fs_save_directory32:
    inc dword [fs_directory+DIR_VERSION]
    call fs_update_checksum32
fs_sync_directory32:
    mov eax,BACKUP_LBA
    mov esi,fs_directory
    call ata_write_sector32
    mov eax,DIR_LBA
    mov esi,fs_directory
    call ata_write_sector32
    ret

; XOR checksum: the XOR of all 128 directory dwords must be zero.
fs_update_checksum32:
    push eax
    push ecx
    push esi
    xor eax,eax
    mov esi,fs_directory
    mov ecx,127
.checksum:
    xor eax,[esi]
    add esi,4
    loop .checksum
    mov [fs_directory+508],eax
    pop esi
    pop ecx
    pop eax
    ret

; Return EAX=1 when the complete directory sector passes its checksum.
fs_verify_directory32:
    mov esi,fs_directory
fs_verify_buffer32:
    push ecx
    push esi
    xor eax,eax
    mov ecx,128
.verify:
    xor eax,[esi]
    add esi,4
    loop .verify
    test eax,eax
    setz al
    movzx eax,al
    pop esi
    pop ecx
    ret

fs_is_ready32:
    xor eax,eax
    cmp dword [fs_directory],0x3846524F
    jne .done
    call fs_verify_directory32
.done: ret

fs_verify_large32:
    mov eax,DATA_LBA+5
    mov ecx,2
    call fs_read_extent32
    xor eax,eax
    cmp byte [file_buffer],'A'
    jne .verify_done
    cmp byte [file_buffer+511],'A'
    jne .verify_done
    cmp byte [file_buffer+512],'A'
    jne .verify_done
    cmp byte [file_buffer+699],'A'
    jne .verify_done
    cmp byte [file_buffer+700],0
    jne .verify_done
    mov eax,1
.verify_done:
    ret

fs_list32:
    pushad
    mov esi,fs_directory+ENTRY_BASE
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

; ESI=name -> EAX=1, ESI=content.
fs_cat32:
    call fs_find32
    test eax,eax
    jz .done
    movzx eax,word [edi+E_START]
    movzx ecx,byte [edi+E_SECTORS]
    call fs_read_extent32
    movzx ecx,word [edi+E_SIZE]
    mov esi,file_buffer
    call fs_data_checksum32
    cmp ax,[edi+E_CHECKSUM]
    jne .corrupt
    movzx ecx,word [edi+E_SIZE]
    cmp ecx,FILE_CAPACITY-1
    jbe .size_ok
    mov ecx,FILE_CAPACITY-1
.size_ok:
    mov byte [file_buffer+ecx],0
    mov esi,file_buffer
    mov eax,1
    ret
.corrupt:
    mov eax,2
.done: ret

; ESI=name, EDI=text.
fs_write32:
    push ebx
    mov ebx,edi
    call fs_find32
    test eax,eax
    jz .done
    push edi
    mov esi,ebx
    mov edi,file_buffer
    xor ecx,ecx
.copy:
    cmp ecx,FILE_CAPACITY-1
    jae .copied
    lodsb
    test al,al
    jz .copied
    stosb
    inc ecx
    jmp .copy
.copied:
    mov byte [edi],0
    pop edi
    push ecx
    cmp ecx,512
    ja .need_two
    mov ecx,1
    jmp .resize
.need_two:
    mov ecx,2
.resize:
    push edi
    call fs_resize_extent32
    pop edi
    test eax,eax
    jz .allocation_failed
    pop ecx
    mov [edi+E_SIZE],cx
    movzx eax,word [edi+E_START]
    movzx ecx,byte [edi+E_SECTORS]
    mov esi,file_buffer
    call fs_write_extent32
    movzx ecx,word [edi+E_SIZE]
    mov esi,file_buffer
    call fs_data_checksum32
    mov [edi+E_CHECKSUM],ax
    call fs_save_directory32
    mov eax,1
    jmp .done
.allocation_failed:
    pop ecx
    xor eax,eax
.done:
    pop ebx
    ret

; EDI=entry, ECX=required sectors. Return 1 on success.
fs_resize_extent32:
    push ebx
    push ebp
    mov ebp,ecx
    movzx ebx,byte [edi+E_SECTORS]
    cmp ebx,ebp
    je .resize_ok
    test ebx,ebx
    jz .allocate_new
    movzx eax,word [edi+E_START]
    mov ecx,ebx
    call fs_free_extent32
.allocate_new:
    mov ecx,ebp
    call fs_allocate_extent32
    test eax,eax
    jz .resize_failed
    mov [edi+E_START],ax
    mov edx,ebp
    mov [edi+E_SECTORS],dl
.resize_ok:
    mov eax,1
    jmp .resize_done
.resize_failed:
    mov word [edi+E_START],0
    mov byte [edi+E_SECTORS],0
    xor eax,eax
.resize_done:
    pop ebp
    pop ebx
    ret

; ESI=name. Return 1 created, 2 exists, 0 invalid/full.
fs_create32:
    push ebx
    push ecx
    mov ebx,esi
    xor ecx,ecx
.length:
    cmp byte [ebx+ecx],0
    je .length_ok
    inc ecx
    cmp ecx,NAME_SIZE
    jae .failed
    jmp .length
.length_ok:
    test ecx,ecx
    jz .failed
    mov esi,ebx
    call fs_find32
    test eax,eax
    jnz .exists
    mov edi,fs_directory+ENTRY_BASE
    mov ecx,FILE_COUNT
.empty:
    cmp byte [edi],0
    je .found_empty
    add edi,ENTRY_SIZE
    loop .empty
    jmp .failed
.found_empty:
    push edi
    mov esi,ebx
.copy_name:
    lodsb
    stosb
    test al,al
    jnz .copy_name
    pop edi
    mov word [edi+E_SIZE],0
    mov word [edi+E_START],0
    mov byte [edi+E_SECTORS],0
    mov byte [edi+E_FLAGS],1
    mov word [edi+E_CHECKSUM],0
    call fs_save_directory32
    mov eax,1
    jmp .done
.exists: mov eax,2
    jmp .done
.failed: xor eax,eax
.done:
    pop ecx
    pop ebx
    ret

fs_delete32:
    call fs_find32
    test eax,eax
    jz .done
    push edi
    movzx eax,word [edi+E_START]
    movzx ecx,byte [edi+E_SECTORS]
    call fs_free_extent32
    pop edi
    mov byte [edi],0
    mov word [edi+E_SIZE],0
    mov word [edi+E_START],0
    mov byte [edi+E_SECTORS],0
    mov byte [edi+E_FLAGS],0
    mov word [edi+E_CHECKSUM],0
    call fs_save_directory32
    mov eax,1
.done: ret

; ECX=1 or 2 sectors.
fs_allocate_extent32:
    push ebx
    push edx
    push ebp
    mov ebp,ecx
    xor ecx,ecx
.scan_extent:
    cmp ebp,2
    jne .range_ok
    cmp ecx,POOL_SECTORS-1
    jae .alloc_failed
.range_ok:
    mov edx,1
    cmp ebp,2
    jne .mask_ready
    mov edx,3
.mask_ready:
    shl edx,cl
    mov ebx,[fs_directory+4]
    test ebx,edx
    jz .extent_found
    inc ecx
    cmp ecx,POOL_SECTORS
    jb .scan_extent
.alloc_failed:
    xor eax,eax
    jmp .alloc_done
.extent_found:
    or ebx,edx
    mov [fs_directory+4],ebx
    mov eax,DATA_LBA
    add eax,ecx
.alloc_done:
    pop ebp
    pop edx
    pop ebx
    ret

; EAX=start LBA, ECX=count.
fs_free_extent32:
    push ebx
    mov ebx,ecx
    test ebx,ebx
    jz .free_done
    cmp eax,DATA_LBA
    jb .free_done
    sub eax,DATA_LBA
    cmp eax,POOL_SECTORS-1
    ja .free_done
    mov ecx,eax
    mov edx,1
    cmp ebx,2
    jne .free_mask
    mov edx,3
.free_mask:
    shl edx,cl
    not edx
    and [fs_directory+4],edx
.free_done:
    pop ebx
    ret

fs_disk_info32:
    pushad
    xor eax,eax
    xor ecx,ecx
.count_free:
    bt dword [fs_directory+4],ecx
    jc .used
    inc eax
.used:
    inc ecx
    cmp ecx,POOL_SECTORS
    jb .count_free
    mov ebx,eax
    mov edi,disk_buffer
    mov esi,disk_prefix
    call fs_append_string32
    mov eax,ebx
    call fs_append_uint32
    mov esi,disk_suffix
    call fs_append_string32
    mov byte [edi],0
    popad
    mov esi,disk_buffer
    ret

; ESI=name -> printable size/start/sectors.
fs_stat32:
    call fs_find32
    test eax,eax
    jz .done
    pushad
    mov ebx,edi
    mov edi,stat_buffer
    mov esi,stat_size
    call fs_append_string32
    movzx eax,word [ebx+E_SIZE]
    call fs_append_uint32
    mov esi,stat_lba
    call fs_append_string32
    movzx eax,word [ebx+E_START]
    call fs_append_uint32
    mov esi,stat_sectors
    call fs_append_string32
    movzx eax,byte [ebx+E_SECTORS]
    call fs_append_uint32
    mov byte [edi],0
    popad
    mov esi,stat_buffer
    mov eax,1
.done: ret

fs_find32:
    push ebx
    push ecx
    push esi
    mov ebx,esi
    mov edi,fs_directory+ENTRY_BASE
    mov ecx,FILE_COUNT
.scan:
    cmp byte [edi],0
    je .next
    mov esi,ebx
    push edi
.compare:
    mov al,[esi]
    cmp al,[edi]
    jne .different
    test al,al
    je .found_pop
    inc esi
    inc edi
    jmp .compare
.different:
    pop edi
.next:
    add edi,ENTRY_SIZE
    loop .scan
    xor eax,eax
    xor edi,edi
    jmp .done
.found_pop:
    pop edi
    mov eax,1
.done:
    pop esi
    pop ecx
    pop ebx
    ret

; EAX=start LBA, file_buffer destination/source.
fs_read_extent32:
    pushad
    mov ebx,eax
    mov edi,file_buffer
.read:
    mov eax,ebx
    call ata_read_sector32
    inc ebx
    add edi,512
    loop .read
    popad
    ret

fs_write_extent32:
    pushad
    mov ebx,eax
.write:
    mov eax,ebx
    call ata_write_sector32
    inc ebx
    add esi,512
    loop .write
    popad
    ret

; ESI=data, ECX=length -> AX=16-bit additive checksum.
fs_data_checksum32:
    push ebx
    xor ebx,ebx
.data_sum:
    test ecx,ecx
    jz .data_done
    movzx eax,byte [esi]
    add ebx,eax
    inc esi
    dec ecx
    jmp .data_sum
.data_done:
    mov eax,ebx
    and eax,0xFFFF
    pop ebx
    ret

fs_refresh_checksums32:
    pushad
    mov edi,fs_directory+ENTRY_BASE
    mov ebx,FILE_COUNT
.refresh:
    cmp byte [edi],0
    je .refresh_next
    movzx eax,word [edi+E_START]
    movzx ecx,byte [edi+E_SECTORS]
    call fs_read_extent32
    movzx ecx,word [edi+E_SIZE]
    mov esi,file_buffer
    call fs_data_checksum32
    mov [edi+E_CHECKSUM],ax
.refresh_next:
    add edi,ENTRY_SIZE
    dec ebx
    jnz .refresh
    popad
    ret

fs_append_string32:
.s: lodsb
    test al,al
    jz .sd
    stosb
    jmp .s
.sd: ret

fs_append_uint32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
    test eax,eax
    jnz .digits
    mov byte [edi],'0'
    inc edi
    jmp .udone
.digits:
    xor edx,edx
    div ebx
    push edx
    inc ecx
    test eax,eax
    jnz .digits
.out:
    pop edx
    add dl,'0'
    mov [edi],dl
    inc edi
    loop .out
.udone:
    pop edx
    pop ecx
    pop ebx
    ret

%macro DIRENT 4
    db %1,0
    times NAME_SIZE-($-%%start) db 0
%%start:
%endmacro

; Directory entries: name[16], size, start LBA, sectors, flags, reserved.
align 4
default_directory:
    db 'ORF8'
    dd 0x0000007F
%assign slot 0
%macro ENTRY 4
%%base:
    db %1,0
    times NAME_SIZE-($-%%base) db 0
    dw %2
    dw %3
    db %4,1
    dw 0
%assign slot slot+1
%endmacro
    ENTRY 'hello.txt',default_hello_end-default_hello-1,DATA_LBA,1
    ENTRY 'about.txt',default_about_end-default_about-1,DATA_LBA+1,1
    ENTRY 'config.txt',default_config_end-default_config-1,DATA_LBA+2,1
    ENTRY 'demo.oex',default_demo_end-default_demo-1,DATA_LBA+3,1
    ENTRY 'bad.oex',default_bad_end-default_bad-1,DATA_LBA+4,1
    ENTRY 'big.txt',700,DATA_LBA+5,2
empty_entry:
    times NAME_SIZE db 0
    dw 0
    dw 0
    db 0,0
    dw 0
    dd 0                       ; directory version
    times 508-($-default_directory) db 0
    dd 0

default_hello: db 'Hello from OrangeFS v8!',0
default_hello_end:
default_about: db 'OrangeFS v8',0
default_about_end:
default_config: db 'fs=ORF8 paging=on',0
default_config_end:
default_demo: db 'OEX2:00:13:F6:BB2A000000B804000000CD80B803000000CD80',0
default_demo_end:
default_bad: db 'OEX2:00:01:00:90',0
default_bad_end:

stat_size: db 'size=',0
stat_lba: db ' bytes start=',0
stat_sectors: db ' sectors=',0
fs_directory: times 512 db 0
file_buffer: times FILE_CAPACITY db 0
fs_backup_directory equ file_buffer+512
list_buffer: times FILE_COUNT*(NAME_SIZE+2) db 0
stat_buffer: times 64 db 0
disk_prefix: db 'OrangeFS free=',0
disk_suffix: db '/32 sectors',0
disk_buffer: times 40 db 0
