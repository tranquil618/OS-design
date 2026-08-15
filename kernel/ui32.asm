; OrangeOS VGA text desktop and mini game
[BITS 32]

global ui_run32
global game_run32
global ui_keyboard32

extern timer_get_ticks32
extern memory_get_free_pages32
extern process_get_switches32
extern keyboard_set_cursor32
extern monitor_run32
extern fs_list32
extern fs_get_name32
extern fs_cat32
extern fs_write32

VGA equ 0xB8000
CELLS equ 80*25

ui_run32:
    pushad
    mov byte [ui_mode],1
    mov byte [ui_exit],0
    mov byte [ui_selected],0
    mov byte [ui_action],0
    mov byte [ui_redraw],0
    call ui_draw_current32
    sti
.wait:
    cmp byte [ui_exit],0
    jne ui_leave32
    cmp byte [ui_redraw],0
    je .check_action
    mov byte [ui_redraw],0
    call ui_draw_current32
.check_action:
    mov al,[ui_action]
    test al,al
    jz .sleep
    mov byte [ui_action],0
    cmp al,1
    je .open_monitor
    cmp al,2
    je .open_files
    cmp al,4
    je .file_open
    cmp al,5
    je .file_save
    call game_run32
    mov byte [ui_mode],1
    call desktop_draw32
    sti
    jmp .sleep
.open_monitor:
    call monitor_run32
    mov byte [ui_mode],1
    call desktop_draw32
    sti
    jmp .sleep
.open_files:
    mov byte [ui_mode],3
    mov byte [file_selected],0
    call file_browser_draw32
    sti
    jmp .sleep
.file_open:
    call editor_open32
    sti
    jmp .sleep
.file_save:
    mov esi,editor_name
    mov edi,editor_buffer
    call fs_write32
    mov byte [editor_saved],1
    call editor_draw32
    mov esi,save_debug
    call ui_debug32
    sti
.sleep:
    hlt
    jmp .wait

game_run32:
    pushad
    mov esi,game_debug
.debug:
    lodsb
    test al,al
    jz .debug_done
    out 0xE9,al
    jmp .debug
.debug_done:
    mov byte [ui_mode],2
    mov byte [ui_exit],0
    mov byte [player_x],40
    mov byte [star_x],20
    mov byte [star_y],3
    mov dword [game_score],0
    mov dword [game_last_tick],0
    sti
.loop:
    cmp byte [ui_exit],0
    jne ui_leave32
    call timer_get_ticks32
    mov edx,eax
    sub edx,[game_last_tick]
    cmp edx,12
    jb .sleep
    mov [game_last_tick],eax
    call game_step32
    call game_draw32
.sleep:
    hlt
    jmp .loop

ui_leave32:
    cli
    mov byte [ui_mode],0
    call ui_clear32
    xor eax,eax
    call keyboard_set_cursor32
    popad
    ret

; AL=Set-1 scan code. Return EAX=1 when consumed.
ui_keyboard32:
    cmp byte [ui_mode],0
    je .not_used
    cmp byte [ui_mode],2
    je .game_keys
    cmp byte [ui_mode],3
    je .file_keys
    cmp byte [ui_mode],4
    je .editor_keys
    cmp al,0x01
    je .exit
    cmp al,0x10
    je .exit
    cmp al,0x48
    je .select_up
    cmp al,0x50
    je .select_down
    cmp al,0x1C
    je .select_open
    jmp .used
.select_up:
    cmp byte [ui_selected],0
    je .used
    dec byte [ui_selected]
    mov byte [ui_redraw],1
    jmp .used
.select_down:
    cmp byte [ui_selected],2
    jae .used
    inc byte [ui_selected]
    mov byte [ui_redraw],1
    jmp .used
.select_open:
    mov al,[ui_selected]
    inc al
    mov [ui_action],al
    jmp .used
.game_keys:
    cmp al,0x01
    je .exit
    cmp al,0x10
    je .exit
    cmp al,0x4B
    je .left
    cmp al,0x4D
    je .right
    jmp .used
.file_keys:
    cmp al,0x01
    je .file_back
    cmp al,0x10
    je .file_back
    cmp al,0x48
    je .file_up
    cmp al,0x50
    je .file_down
    cmp al,0x1C
    je .file_open_key
    jmp .used
.file_up:
    cmp byte [file_selected],0
    je .used
    dec byte [file_selected]
    mov byte [ui_redraw],1
    jmp .used
.file_down:
    cmp byte [file_selected],6
    jae .used
    movzx eax,byte [file_selected]
    inc eax
    call fs_get_name32
    test eax,eax
    jz .used
    inc byte [file_selected]
    mov byte [ui_redraw],1
    jmp .used
.file_open_key:
    mov byte [ui_action],4
    jmp .used
.file_back:
    mov byte [ui_mode],1
    mov byte [ui_selected],1
    mov byte [ui_redraw],1
    jmp .used
.editor_keys:
    cmp al,0x01
    je .editor_back
    cmp al,0x3C
    je .editor_save_key
    cmp al,0x2A
    je .editor_shift_left_on
    cmp al,0x36
    je .editor_shift_right_on
    cmp al,0xAA
    je .editor_shift_left_off
    cmp al,0xB6
    je .editor_shift_right_off
    test al,0x80
    jnz .used
    cmp al,0x0E
    je .editor_delete
    cmp al,0x1C
    je .editor_newline
    movzx edx,al
    cmp edx,editor_scan_end-editor_scan
    jae .used
    cmp byte [editor_shift],0
    jne .editor_shifted
    mov al,[editor_scan+edx]
    jmp .editor_char_ready
.editor_shifted:
    mov al,[editor_shift_scan+edx]
.editor_char_ready:
    test al,al
    jz .used
    call editor_append32
    jmp .used
.editor_newline:
    mov al,10
    call editor_append32
    jmp .used
.editor_delete:
    cmp dword [editor_length],0
    je .used
    dec dword [editor_length]
    mov edx,[editor_length]
    mov byte [editor_buffer+edx],0
    mov byte [editor_saved],0
    mov byte [ui_redraw],1
    jmp .used
.editor_save_key:
    mov byte [ui_action],5
    jmp .used
.editor_back:
    mov byte [ui_mode],3
    mov byte [ui_redraw],1
    jmp .used
.editor_shift_left_on:
    or byte [editor_shift],1
    jmp .used
.editor_shift_right_on:
    or byte [editor_shift],2
    jmp .used
.editor_shift_left_off:
    and byte [editor_shift],0xFE
    jmp .used
.editor_shift_right_off:
    and byte [editor_shift],0xFD
    jmp .used
.left:
    cmp byte [player_x],2
    jbe .used
    dec byte [player_x]
    jmp .used
.right:
    cmp byte [player_x],77
    jae .used
    inc byte [player_x]
    jmp .used
.exit:
    mov byte [ui_exit],1
.used:
    mov eax,1
    ret
.not_used:
    xor eax,eax
    ret

desktop_draw32:
    call ui_clear32
    mov edi,VGA
    mov ecx,80
    mov ax,0x1F20
    rep stosw
    mov esi,desktop_title
    mov edi,VGA+2*22
    mov ah,0x1F
    call ui_text32
    mov esi,desktop_system
    mov edi,VGA+160*5+2*8
    mov ah,0x0B
    cmp byte [ui_selected],0
    jne .system_ready
    mov ah,0x1F
.system_ready:
    call ui_text32
    mov esi,desktop_files
    mov edi,VGA+160*9+2*8
    mov ah,0x0E
    cmp byte [ui_selected],1
    jne .files_ready
    mov ah,0x1F
.files_ready:
    call ui_text32
    mov esi,desktop_apps
    mov edi,VGA+160*13+2*8
    mov ah,0x0D
    cmp byte [ui_selected],2
    jne .apps_ready
    mov ah,0x1F
.apps_ready:
    call ui_text32
    mov esi,desktop_hint
    mov edi,VGA+160*22+2*17
    mov ah,0x0A
    call ui_text32
    ret

ui_draw_current32:
    cmp byte [ui_mode],3
    je file_browser_draw32
    cmp byte [ui_mode],4
    je editor_draw32
    jmp desktop_draw32

file_browser_draw32:
    call ui_clear32
    mov edi,VGA
    mov ecx,80
    mov ax,0x1F20
    rep stosw
    mov esi,file_title
    mov edi,VGA+2*24
    mov ah,0x1F
    call ui_text32
    xor ebx,ebx
.row:
    mov eax,ebx
    call fs_get_name32
    test eax,eax
    jz .rows_done
    mov eax,ebx
    imul eax,eax,160
    lea edi,[VGA+160*4+eax+2*8]
    mov ah,0x0F
    cmp bl,[file_selected]
    jne .draw_name
    mov ah,0x1E
.draw_name:
    call ui_text32
    inc ebx
    cmp ebx,7
    jb .row
.rows_done:
    mov esi,file_hint
    mov edi,VGA+160*22+2*12
    mov ah,0x0A
    call ui_text32
    mov esi,file_debug
    call ui_debug32
    ret

editor_open32:
    movzx eax,byte [file_selected]
    call fs_get_name32
    test eax,eax
    jz .done
    mov edi,editor_name
.copy_name:
    lodsb
    stosb
    test al,al
    jnz .copy_name
    mov esi,editor_name
    call fs_cat32
    cmp eax,1
    jne .done
    mov edi,editor_buffer
    xor ecx,ecx
.copy_text:
    cmp ecx,1023
    jae .copied
    lodsb
    stosb
    test al,al
    jz .copied
    inc ecx
    jmp .copy_text
.copied:
    mov byte [editor_buffer+ecx],0
    mov [editor_length],ecx
    mov byte [editor_saved],1
    mov byte [editor_shift],0
    mov byte [ui_mode],4
    call editor_draw32
    mov esi,editor_debug
    call ui_debug32
.done:
    ret

editor_append32:
    push edx
    mov edx,[editor_length]
    cmp edx,1023
    jae .done
    mov [editor_buffer+edx],al
    inc edx
    mov [editor_length],edx
    mov byte [editor_buffer+edx],0
    mov byte [editor_saved],0
    mov byte [ui_redraw],1
.done:
    pop edx
    ret

editor_draw32:
    call ui_clear32
    mov edi,VGA
    mov ecx,80
    mov ax,0x1F20
    rep stosw
    mov esi,editor_title
    mov edi,VGA+2*3
    mov ah,0x1F
    call ui_text32
    mov esi,editor_name
    call ui_text32
    mov esi,editor_status_saved
    cmp byte [editor_saved],0
    jne .draw_status
    mov esi,editor_status_modified
.draw_status:
    mov edi,VGA+2*58
    mov ah,0x1F
    call ui_text32
    mov esi,editor_buffer
    mov edi,VGA+160*3+2*2
    mov ebx,3
    mov ecx,20
    mov edx,76
.character:
    lodsb
    test al,al
    jz .cursor
    cmp al,10
    je .next_line
    stosw
    dec edx
    jnz .character
.next_line:
    dec ecx
    jz .footer
    inc ebx
    imul edi,ebx,160
    add edi,VGA+2*2
    mov edx,76
    jmp .character
.cursor:
    mov word [edi],0x7020
.footer:
    mov esi,editor_hint
    mov edi,VGA+160*23+2*16
    mov ah,0x0A
    call ui_text32
    ret

ui_debug32:
    lodsb
    test al,al
    jz .done
    out 0xE9,al
    jmp ui_debug32
.done:
    ret

game_step32:
    inc byte [star_y]
    cmp byte [star_y],20
    jb .done
    mov al,[star_x]
    cmp al,[player_x]
    jne .reset
    inc dword [game_score]
.reset:
    mov byte [star_y],3
    call timer_get_ticks32
    xor edx,edx
    mov ecx,74
    div ecx
    add dl,3
    mov [star_x],dl
.done:
    ret

game_draw32:
    call ui_clear32
    mov esi,game_title
    mov edi,VGA+2*25
    mov ah,0x0E
    call ui_text32
    mov esi,game_hint
    mov edi,VGA+160*23+2*16
    mov ah,0x0A
    call ui_text32
    movzx eax,byte [star_y]
    imul eax,eax,160
    movzx edi,byte [star_x]
    lea edi,[VGA+eax+edi*2]
    mov word [edi],0x0E2A
    movzx edi,byte [player_x]
    lea edi,[VGA+160*20+edi*2]
    mov word [edi],0x0B5E
    mov esi,score_text
    mov edi,VGA+160*2+2*3
    mov ah,0x0F
    call ui_text32
    mov eax,[game_score]
    call ui_number32
    ret

ui_clear32:
    push eax
    push ecx
    push edi
    mov edi,VGA
    mov ecx,CELLS
    mov ax,0x0120
    rep stosw
    pop edi
    pop ecx
    pop eax
    ret

; ESI=text, EDI=cell, AH=attribute.
ui_text32:
    lodsb
    test al,al
    jz .done
    stosw
    jmp ui_text32
.done:
    ret

; EAX=unsigned number, EDI=cell, AH already colour.
ui_number32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
.digits:
    xor edx,edx
    div ebx
    push edx
    inc ecx
    test eax,eax
    jnz .digits
.write:
    pop edx
    mov al,dl
    add al,'0'
    mov ah,0x0F
    stosw
    loop .write
    pop edx
    pop ecx
    pop ebx
    ret

desktop_title:  db 'OrangeOS Desktop',0
desktop_system: db '[ SYSTEM ]  monitor  memmap  status',0
desktop_files:  db '[ FILES  ]  ls  cat  write  exec',0
desktop_apps:   db '[ APPS   ]  shell  game  user',0
desktop_hint:   db 'Up/Down: select  Enter: open  Q/Esc: return',0
game_title:     db 'ORANGE CATCH',0
game_hint:      db 'Left/Right: move   Catch * with ^   Q/Esc: exit',0
score_text:     db 'Score: ',0
game_debug:     db 'GAME ACTIVE',0
file_title:     db 'OrangeFS File Manager',0
file_hint:      db 'Up/Down: select   Enter: edit   Q/Esc: desktop',0
file_debug:     db 'FILE MANAGER READY',0
editor_title:   db 'EDITOR: ',0
editor_status_saved: db '[SAVED]',0
editor_status_modified: db '[MODIFIED]',0
editor_hint:    db 'Type to edit   F2: save   Esc: file manager',0
editor_debug:   db 'EDITOR READY',0
save_debug:     db 'FILE SAVED',0
ui_mode:        db 0
ui_exit:        db 0
ui_selected:    db 0
ui_action:      db 0
ui_redraw:      db 0
player_x:       db 40
star_x:         db 20
star_y:         db 3
align 4
game_score:     dd 0
game_last_tick: dd 0
file_selected:  db 0
editor_saved:   db 1
editor_shift:   db 0
align 4
editor_length:  dd 0
editor_name:    times 16 db 0
editor_buffer:  times 1024 db 0

editor_scan:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0
    db 'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s'
    db 'd','f','g','h','j','k','l',';',39,96,0,92,'z','x','c','v'
    db 'b','n','m',',','.','/',0,'*',0,' ',0
editor_scan_end:
editor_shift_scan:
    db 0,0,'!','@','#','$','%','^','&','*','(',')','_','+',0,0
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S'
    db 'D','F','G','H','J','K','L',':',34,'~',0,'|','Z','X','C','V'
    db 'B','N','M','<','>','?',0,'*',0,' ',0
