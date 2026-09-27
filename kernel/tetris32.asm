; OrangeOS text-mode Tetris
[BITS 32]

global tetris_run32
global tetris_keyboard32

extern timer_get_ticks32
extern keyboard_set_cursor32

VGA equ 0xB8000
BOARD_W equ 10
BOARD_H equ 18

; 启动一局俄罗斯方块并进入事件循环。
; 游戏状态由主循环统一修改；键盘中断只写入动作标志。
; 调用约定：无参数、无返回值；退出后恢复进入游戏前的通用寄存器。
tetris_run32:
    pushad
    ; 重置本局的运行标志、计分和棋盘。
    mov byte [tetris_active],1
    mov byte [tetris_exit],0
    mov byte [tetris_game_over],0
    mov byte [tetris_action],0
    mov dword [tetris_score],0
    mov dword [tetris_lines],0
    ; 棋盘按行连续保存，共 10×18=180 个字节。
    mov edi,tetris_board
    xor eax,eax
    mov ecx,BOARD_W*BOARD_H
    rep stosb
    call timer_get_ticks32
    ; 当前 tick 同时作为首次自动下落的基准和伪随机序列的初始种子。
    mov [tetris_last_tick],eax
    mov [tetris_seed],eax
    call tetris_spawn32
    call tetris_draw32
    ; 主循环依赖 PIT 和键盘中断唤醒，因此进入循环前开启中断。
    mov esi,tetris_debug
    call tetris_debug32
    sti
.loop:
    cmp byte [tetris_exit],0
    jne .leave
    ; 取出 IRQ1 留下的单个动作并立即清零，避免重复执行。
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
    ; 没有键盘动作时才检查自动下落，避免一次循环重复处理两个动作。
    cmp byte [tetris_game_over],0
    jne .sleep
    ; PIT 约为 100 Hz，累计 30 tick 后自动下降一格。
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
    ; 所有移动均先试探，碰撞检测通过后才提交坐标。
    mov eax,[piece_x]
    dec eax
    mov ebx,[piece_y]
    mov dl,[piece_rot]
    ; EAX/EBX/DL 分别传入候选 x、y 和旋转状态。
    call tetris_can_place32
    test eax,eax
    jz .sleep
    dec dword [piece_x]
    call tetris_draw32
    jmp .sleep
.right:
    cmp byte [tetris_game_over],0
    jne .sleep
    ; 右移与左移使用同一碰撞检测，只改变候选 x。
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
    ; 软降只尝试一格；失败时 tetris_step_down32 会直接锁定方块。
    call tetris_step_down32
    call tetris_draw32
    jmp .sleep
.rotate:
    cmp byte [tetris_game_over],0
    jne .sleep
    ; 四种旋转状态按模 4 循环，非法旋转保持原状态。
    mov dl,[piece_rot]
    inc dl
    ; 与 3 后只保留低两位，使旋转状态在 0～3 之间循环。
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
    ; 硬降持续试探下一行，每成功下降一格增加 2 分。
.drop_loop:
    ; 硬降不逐帧绘制，直到找到最后一个合法 y 后再统一重绘。
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
    ; 下一格已不可放置，当前位置就是最终落点。
    call tetris_lock32
    call tetris_draw32
.sleep:
    ; 没有待处理事件时等待下一次硬件中断，避免忙等。
    hlt
    jmp .loop
.leave:
    cli
    ; 退出前释放键盘焦点、清屏并恢复 Shell 光标位置。
    mov byte [tetris_active],0
    mov edi,VGA
    mov ecx,80*25
    mov ax,0x0720
    rep stosw
    xor eax,eax
    call keyboard_set_cursor32
    popad
    ret

; 键盘事件入口。
; 输入：AL=Set-1 扫描码。
; 输出：EAX=1 表示按键已由 Tetris 消费，EAX=0 表示交给其他模块。
; 即使活动状态下的按键不是游戏控制键，也返回 1，避免字符进入 Shell 输入区。
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
    ; Tetris 活动期间吞掉其他按键，保持应用独占键盘焦点。
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

; 尝试让活动方块下降一格；若下方被阻挡则直接锁定。
; 当前 x 和旋转状态保持不变，仅把候选 y 增加 1。
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

; 将活动方块的四个格子写入棋盘，随后消行并生成下一块。
; pushad 保护调用者现场；锁定结束后再调用可能修改寄存器的后续步骤。
tetris_lock32:
    pushad
    xor ecx,ecx
.block:
    call tetris_shape_offset32
    ; 绝对坐标 = 方块原点 + 当前小格的相对偏移。
    mov eax,[piece_x]
    add eax,esi
    mov ebx,[piece_y]
    add ebx,edi
    test ebx,ebx
    ; 位于棋盘上边界之外的格子暂不写入数组，避免负下标。
    js .next
    ; 一维棋盘下标 = y×BOARD_W+x。
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

; 生成新的活动方块。
; 使用 PIT tick 初始化的线性同余序列，并对 7 取余得到方块类型。
tetris_spawn32:
    ; LCG：seed = seed*1103515245+12345，32 位溢出自然截断。
    inc dword [tetris_seed]
    mov eax,[tetris_seed]
    imul eax,eax,1103515245
    add eax,12345
    mov [tetris_seed],eax
    xor edx,edx
    mov ecx,7
    div ecx
    ; div 的余数位于 EDX，范围为 0～6，对应七种方块。
    mov [piece_type],dl
    ; 新方块统一以旋转状态 0、参考坐标 (3,0) 出生。
    mov byte [piece_rot],0
    mov dword [piece_x],3
    mov dword [piece_y],0
    ; 新方块在出生位置无法放置时，本局结束。
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

; 检查候选方块能否放置。
; 输入：EAX=x，EBX=y，DL=旋转状态。
; 输出：EAX=1 表示四个格子均合法，EAX=0 表示越界或发生重叠。
; 该函数不修改正式的 piece_x/piece_y/piece_rot，只写入 trial_* 临时变量。
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
    ; ECX 依次表示当前四格方块中的第 0～3 个小格。
    xor ecx,ecx
.cell:
    ; 取得当前小格相对方块原点的 (dx,dy)，再换算为棋盘坐标。
    call tetris_trial_offset32
    mov eax,[trial_x]
    add eax,esi
    cmp eax,0
    jl .blocked
    cmp eax,BOARD_W
    ; x 必须位于 [0,BOARD_W)，否则越过左右边界。
    jge .blocked
    mov ebx,[trial_y]
    add ebx,edi
    cmp ebx,BOARD_H
    ; y 不能达到 BOARD_H；负 y 则按“尚未进入可见区域”处理。
    jge .blocked
    ; 允许方块出生时部分格子位于可见棋盘上方，不访问负下标。
    test ebx,ebx
    js .next
    imul ebp,ebx,BOARD_W
    add ebp,eax
    ; 非零棋盘格表示已有锁定方块，候选位置发生重叠。
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

; 查询当前活动姿态中第 ECX 个小格的相对坐标。
; 输出：ESI=dx，EDI=dy。
tetris_shape_offset32:
    movzx eax,byte [piece_type]
    movzx ebx,byte [piece_rot]
    jmp tetris_offset_common32
; 查询候选旋转姿态中第 ECX 个小格的相对坐标。
tetris_trial_offset32:
    movzx eax,byte [piece_type]
    movzx ebx,byte [trial_rot]
tetris_offset_common32:
    ; 布局为 7 种方块 × 4 种旋转 × 4 个小格 × (x,y)。
    ; type*4+rotation 先选中一种姿态；每种姿态占 4*2=8 字节。
    shl eax,2
    add eax,ebx
    shl eax,3
    ; ECX*2 定位当前小格的 x、y 两个有符号字节。
    lea eax,[eax+ecx*2]
    movsx esi,byte [tetris_shapes+eax]
    movsx edi,byte [tetris_shapes+eax+1]
    ret

; 从底部向上扫描并消除满行。
; 消行后重新检查当前行，避免漏掉连续满行。
tetris_clear_lines32:
    pushad
    ; EBX 保存当前检查的行号，从最底部 BOARD_H-1 开始。
    mov ebx,BOARD_H-1
.row:
    xor ecx,ecx
    ; ESI 指向当前行在一维棋盘数组中的起始下标。
    imul esi,ebx,BOARD_W
.scan:
    cmp byte [tetris_board+esi+ecx],0
    je .not_full
    inc ecx
    cmp ecx,BOARD_W
    jb .scan
    ; 当前行已满：把它上方的所有行依次向下移动一行。
    mov edx,ebx
.shift:
    test edx,edx
    jz .clear_top
    mov eax,edx
    ; 目标行为 edx，源行为 edx-1；从下向上复制不会覆盖尚未搬移的数据。
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
    ; 所有行下移完成后，将最顶行清空。
    mov edi,tetris_board
    xor eax,eax
    mov ecx,BOARD_W
    rep stosb
    inc dword [tetris_lines]
    add dword [tetris_score],100
    ; 调试端口标志供 QEMU 自动测试观察消行事件。
    mov esi,tetris_line_debug
    call tetris_debug32
    jmp .row
.not_full:
    dec ebx
    jns .row
    popad
    ret

; 把当前游戏状态完整绘制到 80×25 VGA 文本显存。
; VGA 文本单元占 2 字节：低字节为字符，高字节为颜色属性。
tetris_draw32:
    pushad
    ; 先清空整屏，再绘制标题、提示、统计信息和棋盘。
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
    ; 右侧信息区显示分数和累计消行数。
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
    ; 固定棋盘格使用 '#'，左右边框使用 '|'。
    ; 每个屏幕文本行占 80*2=160 字节，棋盘从屏幕第 3 行开始。
    mov eax,ebx
    add eax,3
    imul eax,eax,160
    lea edi,[VGA+eax+2*28]
    mov word [edi],0x0F7C
    add edi,2
    xor ecx,ecx
.board_cell:
    ; 将棋盘二维坐标 (row,column) 换算为一维数组下标。
    imul edx,ebx,BOARD_W
    add edx,ecx
    mov ax,0x0720
    cmp byte [tetris_board+edx],0
    je .store
    ; 0x0B23：字符 '#'（0x23），颜色属性 0x0B。
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
    ; 活动方块不写入棋盘数组，绘制时单独叠加为 '@'。
    xor ecx,ecx
.piece:
    call tetris_shape_offset32
    ; 活动方块使用与固定棋盘相同的坐标换算，但字符为 '@'。
    mov eax,[piece_x]
    add eax,esi
    mov ebx,[piece_y]
    add ebx,edi
    test ebx,ebx
    js .piece_next
    add ebx,3
    imul ebx,ebx,160
    lea edx,[VGA+ebx+2*29+eax*2]
    ; 0x0E40：字符 '@'（0x40），颜色属性 0x0E。
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

; 在 EDI 指向的 VGA 单元连续输出零结尾字符串，AH 保存颜色属性。
; lodsb 读取字符到 AL，stosw 同时写出 AL 字符与 AH 颜色。
tetris_text32:
    lodsb
    test al,al
    jz .done
    stosw
    jmp tetris_text32
.done: ret

; 把 EAX 中的无符号整数以十进制写入 VGA 文本显存。
tetris_number32:
    push ebx
    push ecx
    push edx
    xor ecx,ecx
    mov ebx,10
.digits:
    ; 反复除以 10，把余数压栈以反转十进制数字顺序。
    xor edx,edx
    div ebx
    push edx
    inc ecx
    test eax,eax
    jnz .digits
.write:
    pop edx
    ; 数值 0～9 加上字符 '0' 后写入显存。
    mov al,dl
    add al,'0'
    mov ah,0x0F
    stosw
    loop .write
    pop edx
    pop ecx
    pop ebx
    ret

; 将测试标志字符串写入 QEMU/Bochs 调试端口 0xE9。
; 该输出不参与游戏逻辑，只用于自动回归判断关键路径是否发生。
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

; 运行状态与当前输入动作；这些字节会在 IRQ1 和游戏主循环之间共享。
tetris_active: db 0       ; 1 表示 Tetris 当前拥有键盘焦点
tetris_exit: db 0         ; IRQ1 设置，主循环读取并退出
tetris_game_over: db 0    ; 新方块无法出生时置 1
tetris_action: db 0       ; 0 无动作，1～5 对应移动/旋转/硬降
piece_type: db 0          ; 0～6：I、O、T、S、Z、J、L
piece_rot: db 0           ; 当前旋转状态 0～3
trial_rot: db 0           ; 碰撞检测使用的候选旋转状态
align 4

; 活动方块、候选位置、计分以及 PIT 时间状态。
piece_x: dd 3             ; 活动方块参考点的棋盘 x
piece_y: dd 0             ; 活动方块参考点的棋盘 y
trial_x: dd 0             ; 候选位置 x
trial_y: dd 0             ; 候选位置 y
tetris_score: dd 0        ; 当前分数
tetris_lines: dd 0        ; 累计消除行数
tetris_last_tick: dd 0    ; 上一次自动下落时的系统 tick
tetris_seed: dd 1         ; 线性同余伪随机种子

; 固定棋盘：每格 0 表示空，1 表示已有锁定方块。
tetris_board: times BOARD_W*BOARD_H db 0

; Seven tetrominoes, four rotations, four (x,y) cells per rotation.
; 七种方块分别保存四个旋转状态，每个状态由四组 (dx,dy) 坐标组成。
tetris_shapes:
; I：横向与纵向两种有效姿态，其余状态重复。
db 0,1,1,1,2,1,3,1, 2,0,2,1,2,2,2,3, 0,1,1,1,2,1,3,1, 2,0,2,1,2,2,2,3
; O：旋转后形状不变，四种状态使用同一组坐标。
db 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1, 1,0,2,0,1,1,2,1
; T：上、右、下、左四种姿态。
db 1,0,0,1,1,1,2,1, 1,0,1,1,2,1,1,2, 0,1,1,1,2,1,1,2, 1,0,0,1,1,1,1,2
; S：四种旋转坐标。
db 1,0,2,0,0,1,1,1, 1,0,1,1,2,1,2,2, 1,1,2,1,0,2,1,2, 0,0,0,1,1,1,1,2
; Z：四种旋转坐标。
db 0,0,1,0,1,1,2,1, 2,0,1,1,2,1,1,2, 0,1,1,1,1,2,2,2, 1,0,0,1,1,1,0,2
; J：四种旋转坐标。
db 0,0,0,1,1,1,2,1, 1,0,2,0,1,1,1,2, 0,1,1,1,2,1,2,2, 1,0,1,1,0,2,1,2
; L：四种旋转坐标。
db 2,0,0,1,1,1,2,1, 1,0,1,1,1,2,2,2, 0,1,1,1,2,1,0,2, 0,0,1,0,1,1,1,2
