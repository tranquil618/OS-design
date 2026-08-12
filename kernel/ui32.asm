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

VGA equ 0xB8000
CELLS equ 80*25

ui_run32:
    pushad
    mov byte [ui_mode],1
    mov byte [ui_exit],0
    mov byte [ui_selected],0
    mov byte [ui_action],0
    mov byte [ui_redraw],0
    call desktop_draw32
    sti
.wait:
    cmp byte [ui_exit],0
    jne ui_leave32
    cmp byte [ui_redraw],0
    je .check_action
    mov byte [ui_redraw],0
    call desktop_draw32
.check_action:
    mov al,[ui_action]
    test al,al
    jz .sleep
    mov byte [ui_action],0
    cmp al,1
    je .open_monitor
    cmp al,2
    je .open_files
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
    call desktop_draw32
    call fs_list32
    mov edi,VGA+160*17+2*4
    mov ah,0x0F
    call ui_text32
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
    cmp al,0x01
    je .exit
    cmp al,0x10
    je .exit
    cmp byte [ui_mode],2
    je .game_keys
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
    cmp al,0x4B
    je .left
    cmp al,0x4D
    je .right
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
