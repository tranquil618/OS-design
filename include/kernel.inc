;=================================
; OrangeOS Kernel API
;kernel.inc
;=================================

;----------------
; Print
;----------------
;function
extern print_string          ; 输出普通字符串
extern print_color_string    ; 输出彩色字符串
extern put_char              ; 在当前光标位置输出一个字符
;data
extern cursor_pos            ; 当前光标位置
extern terminal_start        ; 用户输入区域起始位置

;----------------
; Screen
;----------------
extern clear_screen          ; 清空屏幕

;----------------
; Terminal
;----------------
extern newline               ; 将光标移动到下一行
extern set_cursor            ; 设置当前光标位置
extern set_terminal_start    ; 设置用户输入区域起始位置

;----------------
; Keyboard
;----------------
extern get_key               ; 读取一个键盘字符

;=================================
; Input
;=================================
extern input_char            ; 将字符写入输入缓冲区
extern input_clear           ; 清空输入缓冲区
