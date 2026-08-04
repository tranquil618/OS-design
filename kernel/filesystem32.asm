; OrangeOS simple read-only filesystem
[BITS 32]

global fs_list32
global fs_cat32
global fs_write32

; Return the file-list string in ESI.
fs_list32:
    mov esi, file_list
    ret

; Find the zero-terminated filename at ESI.
; Return EAX=1 and ESI=file contents on success, otherwise EAX=0.
fs_cat32:
    push edi
    push edx
    mov edx, esi

    mov edi, name_hello
    call fs_string_equal32
    test eax, eax
    jnz .hello

    mov esi, edx
    mov edi, name_about
    call fs_string_equal32
    test eax, eax
    jnz .about

    mov esi, edx
    mov edi, name_config
    call fs_string_equal32
    test eax, eax
    jnz .config

    xor eax, eax
    jmp .done

.hello:
    mov esi, content_hello
    jmp .found
.about:
    mov esi, content_about
    jmp .found
.config:
    mov esi, content_config
.found:
    mov eax, 1
.done:
    pop edx
    pop edi
    ret

; Write text to an existing RAM file.
; ESI=filename, EDI=contents. Return EAX=1 or EAX=0 if not found.
fs_write32:
    push ebx
    push ecx
    push edx
    push edi
    mov edx, esi
    mov ebx, edi

    mov edi, name_hello
    call fs_string_equal32
    test eax, eax
    jnz .write_hello
    mov esi, edx
    mov edi, name_about
    call fs_string_equal32
    test eax, eax
    jnz .write_about
    mov esi, edx
    mov edi, name_config
    call fs_string_equal32
    test eax, eax
    jnz .write_config
    xor eax, eax
    jmp .write_done

.write_hello:
    mov edi, content_hello
    jmp .copy_content
.write_about:
    mov edi, content_about
    jmp .copy_content
.write_config:
    mov edi, content_config
.copy_content:
    mov esi, ebx
    mov ecx, 63
.copy_byte:
    lodsb
    stosb
    test al, al
    jz .write_success
    loop .copy_byte
    mov byte [edi], 0
.write_success:
    mov eax, 1
.write_done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; Compare zero-terminated strings at ESI and EDI.
fs_string_equal32:
.loop:
    mov al, [esi]
    cmp al, [edi]
    jne .different
    test al, al
    je .same
    inc esi
    inc edi
    jmp .loop
.same:
    mov eax, 1
    ret
.different:
    xor eax, eax
    ret

file_list:       db 'hello.txt  about.txt  config.txt', 0
name_hello:      db 'hello.txt', 0
name_about:      db 'about.txt', 0
name_config:     db 'config.txt', 0
content_hello:   db 'Hello from OrangeFS!', 0
                times 64-($-content_hello) db 0
content_about:   db 'OrangeOS educational operating system', 0
                times 64-($-content_about) db 0
content_config:  db 'mode=protected bits=32', 0
                times 64-($-content_config) db 0
