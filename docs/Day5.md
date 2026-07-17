# OrangeOS Day5 开发日志

## Kernel模块化与自动构建系统


日期：2026年7月17日


## 一、今日开发目标


今天主要目标：

1. 将原本集中在kernel.asm中的功能进行模块化拆分；
2. 实现独立的屏幕控制模块screen.asm；
3. 实现独立的字符串输出模块print.asm；
4. 学习多文件汇编、目标文件生成以及链接过程；
5. 编写Makefile，实现OrangeOS自动编译。


经过前几天的开发，OrangeOS已经能够完成：

BIOS启动
    ↓
Boot Sector加载
    ↓
Loader读取Kernel
    ↓
Kernel运行并输出信息


但是目前所有功能都集中在一个kernel.asm中。

随着后续功能增加，例如：

- 键盘驱动
- 内存管理
- 文件系统
- Shell

继续使用单文件结构会导致代码难以维护。

因此今天开始向真正操作系统工程结构靠近。


## 二、Kernel模块化设计


### 1. 修改前结构

之前：

kernel.asm

包含：

- Kernel入口
- 清屏代码
- VGA显存操作
- 字符打印代码


所有功能混合在一起。


### 2. 修改后结构


kernel/

├── kernel.asm

    Kernel主入口


├── screen.asm

    屏幕相关功能


└── print.asm

    字符输出功能


新的结构：

                Kernel入口

                    |

        -------------------------

        |                       |

        ↓                       ↓


   screen模块              print模块

 clear_screen()       print_string()

                      print_color_string()
这样设计以后：
kernel.asm只负责：
- 初始化环境
- 调用系统功能
具体功能由不同模块完成。
这种设计类似现代操作系统：
Kernel负责调度
驱动模块负责硬件控制

## 三、screen.asm 屏幕控制模块

今天实现了第一个Kernel函数：
clear_screen
功能：
清空屏幕内容。
计算机启动后，BIOS会留下启动信息：
例如：
SeaBIOS
iPXE
Booting from Hard Disk...
为了让OrangeOS拥有自己的显示环境，
需要清除原来的屏幕内容。
VGA文本模式显存地址：
0xB8000
由于8086实模式使用：
段地址:偏移地址
公式：
物理地址 = 段地址 × 16 + 偏移
因此：
0xB800:0000
实际地址：
0xB800 × 16
0xB8000
屏幕中每个字符占两个字节：
第1字节：
字符ASCII码
第2字节：
颜色属性
例如：
字符：
'A'
颜色：
0x07
在显存中：
'A'  0x07
所以清屏需要：
循环写入：
空格字符
+
默认颜色

## 四、print.asm 字符输出模块

今天将打印功能从kernel.asm中拆出。
实现两个函数：
### 1. print_string
普通字符串输出。
输入：
DS:SI
字符串地址
ES:DI
显存位置
输出：白色字符。
### 2. print_color_string
彩色字符串输出。
输入：
DS:SI
字符串地址
DS:BX
颜色表地址
ES:DI
显存位置
VGA显示格式：
字符：1 byte
颜色：1 byte
例如：
字符：'O'颜色：0x0C
显存：'O' 0x0C
通过分别写入字符和颜色，实现：OrangeOS每个字母不同颜色显示。
最终效果：
OrangeOS Kernel Started!
其中：OrangeOS显示为彩色。

## 五、多文件汇编与链接

今天学习了新的编译流程。
之前：.asm
直接生成：.bin
流程：
ASM
↓
BIN
这种方式适合简单Boot代码。
但是Kernel开始模块化以后：一个文件已经无法满足需求。
因此改为：
.asm
↓
.o目标文件
↓
ld链接
↓
kernel.bin
具体流程：
kernel.asm
        |
        ↓
kernel.o
screen.asm
        |
        ↓
screen.o
print.asm
        |
        ↓
print.o
三个目标文件经过ld链接：生成最终Kernel。
这种方式与真实操作系统开发更加接近。

## 六、重要问题：[BITS16]与ELF32

今天遇到了一个重要问题。
使用：nasm -f elf32生成目标文件以后，程序运行异常。
原因：误认为：elf32代表CPU运行在32位模式。
实际上：这是两个不同概念。
ELF32：表示目标文件格式。
[BITS16]:表示生成16位CPU指令。
OrangeOS当前运行环境：
BIOS启动
↓
16位Real Mode
所以Kernel仍然需要：
[BITS 16]
否则：NASM会按照32位模式生成指令，但是CPU仍然按照16位模式执行。
最终导致：机器码解释错误。
总结：文件格式 ≠ CPU运行模式

## 七、地址模型理解

今天进一步理解了：链接地址和加载地址
### 1. Kernel加载地址
Loader中：jmp 0x1000:0x0000
计算：0x1000 × 16=0x10000
所以：
Kernel实际运行地址：0x10000
### 2. 链接地址
为了避免16位地址限制，
Kernel使用：-Ttext 0
表示：Kernel内部偏移从0开始。
实际运行时：
段地址提供：0x10000
偏移提供：代码内部地址
最终：段地址 + 偏移得到真实物理地址。

## 八、Makefile自动构建

今天完成Makefile编写。
之前每次编译需要输入：
nasm
nasm
ld
cat
qemu步骤繁琐。
加入Makefile后：
编译：make
自动完成：
1. 编译Boot
2. 编译Loader
3. 编译Kernel模块
4. 链接Kernel
5. 生成orange.img
运行：make run
直接启动QEMU。
这使OrangeOS具备了基础工程管理能力。

## 九、今日成果总结

截至Day5：
OrangeOS结构：
BIOS
 ↓
Boot Sector
 ↓
Loader
 ↓
Kernel
 ↓
-----------------
screen.asm
clear_screen()
-----------------
print.asm
print_color_string()
-----------------
目前已经实现：
✓ Boot启动
✓ Loader加载
✓ Kernel独立运行
✓ VGA显存操作
✓ 彩色字符输出
✓ Kernel模块化
✓ 多文件编译
✓ Makefile自动构建
OrangeOS已经从简单启动程序，
逐渐发展成为具有基本结构的小型操作系统。

## 十、下一步计划


下一阶段准备实现：
### 1. 键盘驱动 keyboard.asm

目标：
实现从键盘读取输入。
### 2. 简单Shell

实现：

OrangeOS>
输入命令：
help
clear
about


### 3. 完善Kernel API
增加：

print
clear
input
等基础接口。

### 4. 后续进入保护模式

当前：
16位Real Mode

未来：
16位Boot
↓
开启A20
↓
建立GDT
↓
进入32位Protected Mode
↓
32位Kernel

## Day5结束
