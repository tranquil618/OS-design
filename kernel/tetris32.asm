; OrangeOS text-mode Tetris
[BITS 32]

global tetris_run32
global tetris_keyboard32

extern timer_get_ticks32
extern keyboard_set_cursor32

VGA equ 0xB8000
BOARD_W equ 10
BOARD_H equ 18

tetris_run32:
    pushad
    mov byte [tetris_active],1
    mov byte [tetris_exit],0
    mov byte [tetris_game_over],0
    mov byte [tetris_action],0
    mov dword [tetris_score],0
    mov dword [tetris_lines],0
    mov edi,tetris_board
    xor eax,eax
    mov ecx,BOARD_W*BOARD_H
    rep stosb
    call timer_get_ticks32
    mov [tetris_last_tick],eax
    mov [tetris_seed],eax
    call tetris_spawn32
    call tetris_draw32
    mov esi,tetris_debug
    call tetris_debug32
    sti
.loop:
    cmp byte [tetris_exit],0
    jne .leave
    mov al,[tetris_action]
    mov byte [tetris_action],0
    cmp al,1
    je .left
    cmp al,2
    je .right
    cmp al,3
    je .down
    cmp al,4
    je .rotate
    cmp al,5
    je .drop
    cmp byte [tetris_game_over],0
    jne .sleep
    call timer_get_ticks32
    mov edx,eax
    sub edx,[tetris_last_tick]
    cmp edx,30
    jb .sleep
    mov [tetris_last_tick],eax
    call tetris_step_down32
    call tetris_draw32
    jmp .sleep
.left:
    cmp byte [tetris_game_over],0
    jne .sleep
    mov eax,[piece_x]
    dec eax
    mov ebx,[piece_y]
    mov dl,[piece_rot]
    call tetris_can_place32
    test eax,eax
    jz .sleep
    dec dword [piece_x]
    call tetris_draw32
    jmp .sleep
.right:
    cmp byte [tetris_game_over],0
    jne .sleep
    mov eax,[piece_x]
    inc eax
    mov ebx,[piece_y]
    mov dl,[piece_rot]
    call tetris_can_place32
    test eax,eax
    jz .sleep
    inc dword [piece_x]
    call tetris_draw32
    jmp .sleep
.down:
    cmp byte [tetris_game_over],0
    jne .sleep
    call tetris_step_down32
    call tetris_draw32
    jmp .sleep
.rotate:
    cmp byte [tetris_game_over],0
    jne .sleep
    mov dl,[piece_rot]
    inc dl
    and dl,3
    mov eax,[piece_x]
    mov ebx,[piece_y]
    call tetris_can_place32
    test eax,eax
    jz .sleep
    mov [piece_rot],dl
    call tetris_draw32
    jmp .sleep
.drop:
    cmp byte [tetris_game_over],0
    jne .sleep
.drop_loop:
    mov eax,[piece_x]
    mov ebx,[piece_y]
    inc ebx
    mov dl,[piece_rot]
    call tetris_can_place32
    test eax,eax
    jz .drop_lock
    inc dword [piece_y]
    add dword [tetris_score],2
    jmp .drop_loop
.drop_lock:
    call tetris_lock32
    call tetris_draw32
.sleep:
    hlt
    jmp .loop
.leave:
    cli
    mov byte [tetris_active],0
    mov edi,VGA
    mov ecx,80*25
    mov ax,0x0720
    rep stosw
    xor eax,eax
    call keyboard_set_cursor32
    popad
    ret

; AL=Set-1 scan code, return EAX=1 if Tetris owns the keyboard.
tetris_keyboard32:
    cmp byte [tetris_active],0
    je .unused
    cmp al,0x01
    je .quit
    cmp al,0x10
    je .quit
    cmp al,0x4B
    je .left
    cmp al,0x4D
    je .right
    cmp al,0x50
    je .down
    cmp al,0x48
    je .rotate
    cmp al,0x39
    je .drop
    mov eax,1
    ret
.left:   mov byte [tetris_action],1
    jmp .used
.right:  mov byte [tetris_action],2
    jmp .used
.down:   mov byte [tetris_action],3
    jmp .used
.rotate: mov byte [tetris_action],4
    jmp .used
.drop:   mov byte [tetris_action],5
    jmp .used
.quit:   mov byte [tetris_exit],1
.used:   mov eax,1
    ret
.unused: xor eax,eax
    ret

tetris_step_down32:
    mov eax,[piece_x]
    mov ebx,[piece_y]
    inc ebx
    mov dl,[piece_rot]
    call tetris_can_place32
    test eax,eax
    jz tetris_lock32
    inc dword [piece_y]
    ret

tetris_lock32:
    pushad
    xor ecx,ecx
.block:
    call tetris_shape_offset32
    mov eax,[piece_x]
    add eax,esi
    mov ebx,[piece_y]
    add ebx,edi
    test ebx,ebx
    js .next
    imul ebx,ebx,BOARD_W
    add ebx,eax
    mov byte [tetris_board+ebx],1
.next:
    inc ecx
    cmp ecx,4
    jb .block
    popad
    call tetris_clear_lines32
    call tetris_spawn32
    ret

tetris_spawn32:
    inc dword [tetris_seed]
    mov eax,[tetris_seed]
    imul eax,eax,1103515245
    add eax,12345
    mov [tetris_seed],eax
    xor edx,edx
    mov ecx,7
    div ecx
    mov [piece_type],dl
    mov byte [piece_rot],0
    mov dword [piece_x],3
    mov dword [piece_y],0
    mov eax,3
    xor ebx,ebx
    xor edx,edx
    call tetris_can_place32
    test eax,eax
    jnz .done
    mov byte [tetris_game_over],1
    mov esi,tetris_over_debug
    call tetris_debug32
.done:
    ret

; EAX=x, EBX=y, DL=rotation. Return EAX=1 if all four cells fit.
tetris_can_place32:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov [trial_x],eax
    mov [trial_y],ebx
    mov [trial_rot],dl
    xor ecx,ecx
.cell:
    call tetris_trial_offset32
    mov eax,[trial_x]
    add eax,esi
    cmp eax,0
    jl .blocked
    cmp eax,BOARD_W
    jge .blocked
    mov ebx,[trial_y]
    add ebx,edi
    cmp ebx,BOARD_H
    jge .blocked
    test ebx,ebx
    js .next
    imul ebp,ebx,BOARD_W
    add ebp,eax
    cmp byte [tetris_board+ebp],0
    jne .blocked
.next:
    inc ecx
    cmp ecx,4
    jb .cell
    mov eax,1
    jmp .done
.blocked:
    xor eax,eax
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ECX=block -> ESI=dx, EDI=dy for current piece.
tetris_shape_offset32:
    movzx eax,byte [piece_type]
    movzx ebx,byte [piece_rot]
    jmp tetris_offset_common32
; ECX=block -> offsets for trial rotation.
tetris_trial_offset32:
    movzx eax,byte [piece_type]
    movzx ebx,byte [trial_rot]
tetris_offset_common32:
    shl eax,2
    add eax,ebx
    shl eax,3
    lea eax,[eax+ecx*2]
    movsx esi,byte [tetris_shapes+eax]
    movsx edi,byte [tetris_shapes+eax+1]
    ret

tetris_clear_lines32:
    pushad
    mov ebx,BOARD_H-1
.row:
    xor ecx,ecx
    imul esi,ebx,BOARD_W
.scan:
    cmp byte [tetris_board+esi+ecx],0
    je .not_full
    inc ecx
    cmp ecx,BOARD_W
    jb .scan
    mov edx,ebx
.shift:
    test edx,edx
    jz .clear_top
    mov eax,edx
    imul edi,eax,BOARD_W
    dec eax
    imul esi,eax,BOARD_W
    add edi,tetris_board
    add esi,tetris_board
    mov ecx,BOARD_W
    rep movsb
    dec edx
    jmp .shift
.clear_top:
    mov edi,tetris_board
    xor eax,eax
    mov ecx,BOARD_W
    rep stosb
    inc dword [tetris_lines]
    add dword [tetris_score],100
    mov esi,tetris_line_debug
    call tetris_debug32
    jmp .row
.not_full:
    dec ebx
    jns .row
    popad
    ret

tetris_draw32:
    pushad
    mov edi,VGA
    mov ecx,80*25
    mov ax,0x0120
    rep stosw
    mov esi,tetris_title
    mov edi,VGA+2*29
    mov ah,0x0E
    call tetris_text32
    mov esi,tetris_hint
    mov edi,VGA+160*23+2*10
    mov ah,0x0A
    call tetris_text32
    mov esi,tetris_score_text
    mov edi,VGA+160*4+2*53
    mov ah,0x0F
    call tetris_text32
    mov eax,[tetris_score]
    call tetris_number32
    mov esi,tetris_lines_text
    mov edi,VGA+160*6+2*53
    mov ah,0x0F
    call tetris_text32
    mov eax,[tetris_lines]
    call tetris_number32
    xor ebx,ebx
.board_row:
    mov eax,ebx
    add eax,3
    imul eax,eax,160
    lea edi,[VGA+eax+2*28]
    mov word [edi],0x0F7C
    add edi,2
    xor ecx,ecx
.board_cell:
    imul edx,ebx,BOARD_W
    add edx,ecx
    mov ax,0x0720
    cmp byte [tetris_board+edx],0
    je .store
    mov ax,0x0B23
.store:
    stosw
    inc ecx
    cmp ecx,BOARD_W
    jb .board_cell
    mov word [edi],0x0F7C
    inc ebx
    cmp ebx,BOARD_H
    jb .board_row
    cmp byte [tetris_game_over],0
    jne .over
    xor ecx,ecx
.piece:
    call tetris_shape_offset32
    mov eax,[piece_x]
    add eax,esi
    mov ebx,[piece_y]
    add ebx,edi
    test ebx,ebx
    js .piece_next
    add ebx,3
    imul ebx,ebx,160
    lea edx,[VGA+ebx+2*29+eax*2]
    mov word [edx],0x0E40
.piece_next:
    inc ecx
    cmp ecx,4
    jb .piece
    jmp .done
.over:
    mov esi,tetris_over
    mov edi,VGA+160*12+2*48
    mov ah,0x0C
    call tetris_text32
.done:
    popad
    ret

tetris_text32:
    lodsb
    test al,al
    jz .done
    stosw
    jmp tetris_text32
.done: ret

tetris_number32:
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

tetris_debug32:
    lodsb
    test al,al
    jz .done
    out 0xE9,al
    jmp tetris_debug32
.done: ret

tetris_title: db 'ORANGE TETRIS',0
tetris_hint: db 'Left/Right move  Up rotate  Down soft drop  Space hard drop  Q/Esc exit',0
tetris_score_text: db 'Score: ',0
tetris_lines_text: db 'Lines: ',0
tetris_over: db 'GAME OVER - Q TO EXIT',0
tetris_debug: db 'TETRIS READY',0
tetris_line_debug: db 'TETRIS LINE',0
tetris_over_debug: db 'TETRIS GAME OVER',0
tetris_active: db 0
tetris_exit: db 0
tetris_game_over: db 0
tetris_action: db 0
piece_type: db 0
piece_rot: db 0
trial_rot: db 0
align 4
piece_x: dd 3
piece_y: dd 0
trial_x: dd 0
trial_y: dd 0
tetris_score: dd 0
tetris_lines: dd 0
tetris_last_tick: dd 0
tetris_seed: dd 1
tetris_board: times BOARD_W*BOARD_H db 0

; Seven tetrominoes, four rotations, four (x,y) cells per rotation.
tetris_shapes:
; I
db 0,1,1,1,2,1,3,1, 2,0,2,1,2,2,2,3, 0,1,1,1,2,1,3,1, 2,0,2,1,2,2,2,3
; O
db 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1
; T
db 1,0,0,1,1,1,2,1, 1,0,1,1,2,1,1,2, 0,1,1,1,2,1,1,2, 1,0,0,1,1,1,1,2
; S
db 1,0,2,0,0,1,1,1, 1,0,1,1,2,1,2,2, 1,1,2,1,0,2,1,2, 0,0,0,1,1,1,1,2
; Z
db 0,0,1,0,1,1,2,1, 2,0,1,1,2,1,1,2, 0,1,1,1,1,2,2,2, 1,0,0,1,1,1,0,2
; J
db 0,0,0,1,1,1,2,1, 1,0,2,0,1,1,1,2, 0,1,1,1,2,1,2,2, 1,0,1,1,0,2,1,2
; L
db 2,0,0,1,1,1,2,1, 1,0,1,1,1,2,2,2, 0,1,1,1,2,1,0,2, 0,0,1,0,1,1,1,2
