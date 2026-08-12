; OrangeOS 32-bit shell
[BITS 32]

global shell_prompt32
global shell_execute32

%include "keyboard32.inc"
%include "filesystem32.inc"
%include "memory32.inc"
%include "process32.inc"
%include "heap32.inc"
%include "monitor32.inc"
%include "power32.inc"
%include "syscall32.inc"
%include "rtc32.inc"
%include "selftest32.inc"
%include "usermode32.inc"
%include "ui32.inc"

extern print_string32
extern clear_screen32
extern scroll_input32

VGA_MEMORY equ 0xB8000
INPUT_START equ 320
INPUT_BASE equ VGA_MEMORY + INPUT_START
INPUT_SIZE equ 23 * 160

shell_prompt32:
    push eax
    push esi
    push edi
    call keyboard_get_cursor32
    mov edi, INPUT_BASE
    add edi, eax
    mov esi, shell_prompt
    call print_string32
    mov eax, edi
    sub eax, INPUT_BASE
    call keyboard_set_cursor32
    pop edi
    pop esi
    pop eax
    ret

; Execute the zero-terminated command at ESI.
shell_execute32:
    pushad
    mov ebx, esi
    cmp byte [ebx], 0
    je .done

    mov esi, ebx
    mov edi, command_help
    call string_equal32
    test eax, eax
    jnz .help
    mov esi, ebx
    mov edi, command_info
    call string_equal32
    test eax, eax
    jnz .info
    mov esi, ebx
    mov edi, command_clear
    call string_equal32
    test eax, eax
    jnz .clear

    mov esi,ebx
    mov edi,command_gui
    call string_equal32
    test eax,eax
    jnz .gui
    mov esi,ebx
    mov edi,command_game
    call string_equal32
    test eax,eax
    jnz .game

    mov esi, ebx
    mov edi, command_ls
    call string_equal32
    test eax, eax
    jnz .ls

    mov esi, ebx
    mov edi, command_mem
    call string_equal32
    test eax, eax
    jnz .mem

    mov esi, ebx
    mov edi, command_memmap
    call string_equal32
    test eax, eax
    jnz .memmap

    mov esi, ebx
    mov edi, command_task
    call string_equal32
    test eax, eax
    jnz .task

    mov esi, ebx
    mov edi, command_ps
    call string_equal32
    test eax, eax
    jnz .ps

    mov esi, ebx
    mov edi, command_run
    call string_equal32
    test eax, eax
    jnz .run_user

    mov esi, ebx
    mov edi, command_runfault
    call string_equal32
    test eax, eax
    jnz .run_fault

    mov esi, ebx
    mov edi, command_alloc
    call string_equal32
    test eax, eax
    jnz .alloc

    mov esi, ebx
    mov edi, command_fault
    call string_equal32
    test eax, eax
    jnz .fault

    mov esi, ebx
    mov edi, command_malloc
    call string_equal32
    test eax, eax
    jnz .heap_alloc

    mov esi, ebx
    mov edi, command_free
    call string_equal32
    test eax, eax
    jnz .heap_free

    mov esi, ebx
    mov edi, command_monitor
    call string_equal32
    test eax, eax
    jnz .monitor

    mov esi, ebx
    mov edi, command_status
    call string_equal32
    test eax, eax
    jnz .status

    mov esi, ebx
    mov edi, command_dealloc
    call string_equal32
    test eax, eax
    jnz .dealloc

    mov esi, ebx
    mov edi, command_reboot
    call string_equal32
    test eax, eax
    jnz .reboot

    mov esi, ebx
    mov edi, command_shutdown
    call string_equal32
    test eax, eax
    jnz .shutdown

    mov esi, ebx
    mov edi, command_syscall
    call string_equal32
    test eax, eax
    jnz .syscall

    mov esi, ebx
    mov edi, command_date
    call string_equal32
    test eax, eax
    jnz .date

    mov esi,ebx
    mov edi,command_disk
    call string_equal32
    test eax,eax
    jnz .disk

    mov esi, ebx
    mov edi, command_selftest
    call string_equal32
    test eax, eax
    jnz .selftest

    mov esi, ebx
    mov edi, command_user
    call string_equal32
    test eax, eax
    jnz .user

    ; Show OrangeFS v3 metadata.
    cmp byte [ebx],'s'
    jne .check_exec
    cmp byte [ebx+1],'t'
    jne .check_exec
    cmp byte [ebx+2],'a'
    jne .check_exec
    cmp byte [ebx+3],'t'
    jne .check_exec
    cmp byte [ebx+4],' '
    jne .check_exec
    lea esi,[ebx+5]
    call fs_stat32
    test eax,eax
    jz .file_not_found
    call shell_print_line32
    jmp .done
.check_exec:
    ; Load an OEX2 executable from OrangeFS into the PID 4 user slot.
    cmp byte [ebx],'e'
    jne .check_kill
    cmp byte [ebx+1],'x'
    jne .check_kill
    cmp byte [ebx+2],'e'
    jne .check_kill
    cmp byte [ebx+3],'c'
    jne .check_kill
    cmp byte [ebx+4],' '
    jne .check_kill
    mov eax,3
    call process_get_state32
    cmp eax,1
    je .exec_busy
    cmp eax,2
    je .exec_busy
    lea esi,[ebx+5]
    call fs_cat32
    cmp eax,2
    je .file_corrupt
    test eax,eax
    jz .file_not_found
    call usermode_load_oex32
    test eax,eax
    jz .exec_error
    call process_spawn_user32
    call shell_print_line32
    jmp .done
.exec_busy:
    mov esi,message_exec_busy
    call shell_print_line32
    jmp .done
.exec_error:
    call shell_print_line32
    jmp .done

.check_kill:
    ; The first managed user process is PID 4.
    cmp byte [ebx],'k'
    jne .check_cat
    cmp byte [ebx+1],'i'
    jne .check_cat
    cmp byte [ebx+2],'l'
    jne .check_cat
    cmp byte [ebx+3],'l'
    jne .check_cat
    cmp byte [ebx+4],' '
    jne .check_cat
    cmp byte [ebx+5],'4'
    jne .kill_usage
    cmp byte [ebx+6],0
    jne .kill_usage
    call process_kill_user32
    call shell_print_line32
    jmp .done
.kill_usage:
    mov esi,message_kill_usage
    call shell_print_line32
    jmp .done
.check_cat:
    ; Commands beginning with "cat " pass the remaining text as a filename.
    cmp byte [ebx], 'c'
    jne .check_touch
    cmp byte [ebx+1], 'a'
    jne .check_touch
    cmp byte [ebx+2], 't'
    jne .check_touch
    cmp byte [ebx+3], ' '
    jne .check_touch
    lea esi, [ebx+4]
    call fs_cat32
    cmp eax,2
    je .file_corrupt
    test eax, eax
    jz .file_not_found
    call shell_print_line32
    jmp .done
.file_corrupt:
    mov esi,message_file_corrupt
    call shell_print_line32
    jmp .done

.check_touch:
    cmp byte [ebx],'t'
    jne .check_rm
    cmp byte [ebx+1],'o'
    jne .check_rm
    cmp byte [ebx+2],'u'
    jne .check_rm
    cmp byte [ebx+3],'c'
    jne .check_rm
    cmp byte [ebx+4],'h'
    jne .check_rm
    cmp byte [ebx+5],' '
    jne .check_rm
    lea esi,[ebx+6]
    call fs_create32
    cmp eax,1
    je .file_created
    cmp eax,2
    je .file_exists
    mov esi,message_create_failed
    call shell_print_line32
    jmp .done
.file_created:
    mov esi,message_file_created
    call shell_print_line32
    jmp .done
.file_exists:
    mov esi,message_file_exists
    call shell_print_line32
    jmp .done

.check_rm:
    cmp byte [ebx],'r'
    jne .check_write
    cmp byte [ebx+1],'m'
    jne .check_write
    cmp byte [ebx+2],' '
    jne .check_write
    lea esi,[ebx+3]
    call fs_delete32
    test eax,eax
    jz .file_not_found
    mov esi,message_file_deleted
    call shell_print_line32
    jmp .done

.check_write:
    cmp byte [ebx], 'w'
    jne .unknown
    cmp byte [ebx+1], 'r'
    jne .unknown
    cmp byte [ebx+2], 'i'
    jne .unknown
    cmp byte [ebx+3], 't'
    jne .unknown
    cmp byte [ebx+4], 'e'
    jne .unknown
    cmp byte [ebx+5], ' '
    jne .unknown

    lea esi, [ebx+6]
    mov edi, esi
.find_write_space:
    cmp byte [edi], 0
    je .write_usage
    cmp byte [edi], ' '
    je .write_ready
    inc edi
    jmp .find_write_space
.write_ready:
    mov byte [edi], 0
    inc edi
    cmp byte [edi], 0
    je .write_usage
    call fs_write32
    test eax, eax
    jz .file_not_found
    mov esi, message_write_ok
    call shell_print_line32
    jmp .done
.write_usage:
    mov esi, message_write_usage
    call shell_print_line32
    jmp .done

.unknown:
    mov esi, message_unknown
    call shell_print_line32
    jmp .done
.help:
    mov esi, message_help_core
    call shell_print_line32
    mov esi, message_help_memory
    call shell_print_line32
    mov esi, message_help_system
    call shell_print_line32
    mov esi, message_help_test
    call shell_print_line32
    jmp .done
.info:
    mov esi, message_info
    call shell_print_line32
    jmp .done
.clear:
    call clear_screen32
    xor eax, eax
    call keyboard_set_cursor32
    jmp .done
.gui:
    mov esi,message_gui_ready
    call shell_print_line32
    call ui_run32
    jmp .done
.game:
    mov esi,message_game_ready
    call shell_print_line32
    call game_run32
    jmp .done
.ls:
    call fs_list32
    call shell_print_line32
    jmp .done
.mem:
    call memory_get_info32
    call shell_print_line32
    jmp .done
.memmap:
    call memory_get_map32
    call shell_print_line32
    jmp .done
.task:
    call process_get_info32
    call shell_print_line32
    jmp .done
.ps:
    call process_get_user_info32
    call shell_print_line32
    jmp .done
.run_user:
    call process_spawn_user32
    call shell_print_line32
    jmp .done
.run_fault:
    call process_spawn_fault32
    call shell_print_line32
    jmp .done
.alloc:
    call memory_alloc_info32
    call shell_print_line32
    jmp .done
.fault:
    ; Deliberately access an unmapped address to test vector 14.
    mov byte [0x40000000], 0
    jmp .done
.heap_alloc:
    call heap_alloc_info32
    call shell_print_line32
    jmp .done
.heap_free:
    call heap_free_info32
    call shell_print_line32
    jmp .done
.monitor:
    call monitor_run32
    jmp .done
.status:
    call monitor_get_info32
    call shell_print_line32
    jmp .done
.dealloc:
    call memory_free_info32
    call shell_print_line32
    jmp .done
.reboot:
    call system_reboot32
    jmp .done
.shutdown:
    call system_shutdown32
    jmp .done
.syscall:
    call syscall_get_info32
    call shell_print_line32
    jmp .done
.date:
    call rtc_get_info32
    call shell_print_line32
    jmp .done
.disk:
    call fs_disk_info32
    call shell_print_line32
    jmp .done
.selftest:
    call selftest_run32
    call shell_print_line32
    jmp .done
.user:
    call usermode_run32
    call shell_print_line32
    jmp .done
.file_not_found:
    mov esi, message_file_not_found
    call shell_print_line32
.done:
    popad
    ret

; Compare strings at ESI and EDI. Return EAX=1 when equal.
string_equal32:
    push esi
    push edi
    push edx
.compare:
    mov al, [esi]
    mov dl, [edi]
    cmp al, dl
    jne .not_equal
    test al, al
    je .equal
    inc esi
    inc edi
    jmp .compare
.equal:
    mov eax, 1
    jmp .finish
.not_equal:
    xor eax, eax
.finish:
    pop edx
    pop edi
    pop esi
    ret

; Print the string at ESI and move the cursor to the next line.
shell_print_line32:
    push eax
    push ecx
    push edx
    push esi
    push edi
    call keyboard_get_cursor32
    mov edi, INPUT_BASE
    add edi, eax
    call print_string32
    mov eax, edi
    sub eax, INPUT_BASE
    xor edx, edx
    mov ecx, 160
    div ecx
    inc eax
    imul eax, eax, 160
    cmp eax, INPUT_SIZE
    jb .set_cursor
    call scroll_input32
    mov eax, INPUT_SIZE - 160
.set_cursor:
    call keyboard_set_cursor32
    pop edi
    pop esi
    pop edx
    pop ecx
    pop eax
    ret

shell_prompt:     db 'OrangeOS> ', 0
command_help:     db 'help', 0
command_info:     db 'info', 0
command_clear:    db 'clear', 0
command_ls:       db 'ls', 0
command_mem:      db 'mem', 0
command_memmap:   db 'memmap',0
command_task:     db 'task', 0
command_ps:       db 'ps',0
command_run:      db 'run',0
command_runfault: db 'runfault',0
command_alloc:    db 'alloc', 0
command_fault:    db 'fault', 0
command_malloc:   db 'malloc', 0
command_free:     db 'free', 0
command_monitor:  db 'monitor', 0
command_status:   db 'status',0
command_dealloc:  db 'dealloc', 0
command_reboot:   db 'reboot', 0
command_shutdown: db 'shutdown', 0
command_syscall:  db 'syscall',0
command_date:     db 'date',0
command_disk:     db 'disk',0
command_selftest: db 'selftest',0
command_gui: db 'gui',0
command_game: db 'game',0
command_user:     db 'user',0
message_help_core:   db 'Core: help info clear date monitor status task ps run runfault kill',0
message_help_memory: db 'Memory: mem memmap alloc dealloc malloc free',0
message_help_system: db 'Files: ls cat stat write touch rm exec | Apps: gui game | Power: reboot shutdown',0
message_help_test:   db 'Tests: syscall selftest user | User fault: runfault',0
message_info:     db 'OrangeOS 32-bit Protected Mode + Paging', 0
message_unknown:  db 'Unknown command', 0
message_file_not_found: db 'File not found', 0
message_file_corrupt: db 'File data corrupt',0
message_write_ok: db 'File updated', 0
message_write_usage: db 'Usage: write <file> <text>', 0
message_file_created: db 'File created',0
message_file_exists: db 'File already exists',0
message_create_failed: db 'Invalid name or directory full',0
message_file_deleted: db 'File deleted',0
message_kill_usage: db 'Usage: kill 4',0
message_exec_busy: db 'PID4 is active; wait or kill it first',0
message_gui_ready: db 'GUI READY',0
message_game_ready: db 'GAME READY',0
