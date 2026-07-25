;=================================
; OrangeOS 32位Kernel API
; kernel32.inc
;=================================

;----------------
; Screen
;----------------
extern clear_screen32        ;清空VGA文本屏幕

;----------------
; Print
;----------------
extern print_string32        ;输出32位字符串

;----------------
; Interrupt
;----------------
extern idt_init32            ;初始化并加载32位IDT
