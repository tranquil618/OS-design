# OrangeOS Day7 开发日志

## Kernel代码结构与接口文件调整

## 一、今日开发目标

今天主要整理 OrangeOS 的代码结构和模块接口：

1. 整理 `include` 目录；
2. 使用 `.inc` 文件统一声明 Kernel 接口；
3. 调整 Kernel 模块之间的符号引用关系；
4. 为接口、变量和配置常量补充注释；
5. 配置 NASM 的 include 搜索路径；
6. 让多文件 Kernel 结构更清晰、更容易维护。

## 二、整理 include 目录

当前 `include` 目录包含：

```text
include/
├── config.inc
├── io.inc
├── kernel.inc
└── terminal.inc
```

不同文件负责不同类型的声明。

### 1. config.inc

保存系统常用配置：

- 屏幕宽度；
- 屏幕高度；
- VGA 文本模式显存段地址；
- 默认字符颜色。

### 2. io.inc

声明键盘和输入缓冲区接口：

- `get_key`
- `input_char`
- `input_clear`
- `input_buffer`

### 3. kernel.inc

作为 Kernel 主入口使用的统一 API 声明文件，包含：

- 字符串输出接口；
- 单字符输出接口；
- 清屏接口；
- 终端位置控制接口；
- 键盘读取接口；
- 输入缓冲区接口；
- 光标与输入区域状态。

### 4. terminal.inc

声明终端状态变量：

- `cursor_pos`
- `terminal_start`

## 三、使用 extern 与 global 连接模块

Kernel 已经拆分为多个汇编文件。每个模块通过 `global` 导出自身提供的函数或变量，通过 `extern` 使用其他模块提供的符号。

例如，`print.asm` 导出：

```asm
global print_string
global print_color_string
global put_char
global newline
global set_cursor
global set_terminal_start
global cursor_pos
global terminal_start
```

`kernel.inc` 使用 `extern` 声明这些符号，使 `kernel.asm` 可以调用对应函数并访问终端状态。

这种结构减少了在 Kernel 主入口中重复编写接口声明的问题。

## 四、Kernel主入口使用统一接口

`kernel.asm` 通过：

```asm
%include "kernel.inc"
```

载入 Kernel 所需的外部接口声明。

Kernel 主入口继续负责：

- 设置数据段和显存段；
- 清空屏幕；
- 输出 Kernel 启动信息；
- 显示 `OrangeOS>` 提示符；
- 设置终端输入起点；
- 进入键盘输入循环。

具体功能则分别由屏幕、打印、键盘和输入模块实现。

## 五、调整 NASM include 搜索路径

为了让 NASM 能够找到 `include` 目录中的 `.inc` 文件，在 Makefile 中增加：

```makefile
NASMFLAGS=-I include/ -f elf32
```

Kernel 模块统一使用：

```makefile
$(NASM) $(NASMFLAGS) kernel/kernel.asm -o kernel/kernel.o
```

其中：

- `-I include/` 指定 `.inc` 文件搜索目录；
- `-f elf32` 指定目标文件格式。

这样 `kernel.asm` 可以直接写：

```asm
%include "kernel.inc"
```

实际执行 `make` 时，NASM 能正确读取 `include/kernel.inc`。

## 六、统一模块编译参数

当前 Kernel 相关模块统一使用 `NASMFLAGS`：

```text
kernel.asm
screen.asm
print.asm
keyboard.asm
input.asm
```

这些文件分别生成目标文件：

```text
kernel.o
screen.o
print.o
keyboard.o
input.o
```

最后由链接器生成：

```text
kernel/kernel.bin
```

统一编译参数后，Makefile 更容易继续维护和扩展。

## 七、补充接口注释

今天还为 `.inc` 文件中的函数、变量和配置常量增加了简短注释。

例如：

```asm
extern print_string       ; 输出普通字符串
extern clear_screen       ; 清空屏幕
extern get_key            ; 读取一个键盘字符
extern cursor_pos         ; 当前光标位置
```

这些注释不会改变程序行为，但可以更直观地说明每个接口的用途，方便后续审查和调用。

## 八、当前代码结构

```text
OrangeOS
├── boot/
├── loader/
├── kernel/
│   ├── kernel.asm
│   ├── screen.asm
│   ├── print.asm
│   ├── keyboard.asm
│   ├── input.asm
│   └── data.asm
├── include/
│   ├── config.inc
│   ├── io.inc
│   ├── kernel.inc
│   └── terminal.inc
└── Makefile
```

Kernel 功能实现与接口声明已经开始分离：

```text
kernel/*.asm   → 功能实现
include/*.inc  → 接口与配置声明
Makefile       → 编译和链接规则
```

## 九、今日成果

今天完成了：

- 建立并整理 `include` 接口目录；
- 使用 `kernel.inc` 汇总 Kernel 主入口所需接口；
- 分类键盘、输入和终端状态声明；
- 为接口和配置增加说明注释；
- 在 Makefile 中增加 NASM include 搜索路径；
- 统一 Kernel 模块的汇编参数；
- 验证 `.inc` 文件能够被实际编译过程正确读取；
- 进一步明确 Kernel 各模块的职责。

OrangeOS 的代码已经从功能拆分阶段，继续向接口清晰、结构统一的工程形式发展。

## 十、下一步计划

下一阶段计划：

1. 继续审查各模块的 `global` 与 `extern` 对应关系；
2. 完善输入缓冲区处理；
3. 增加基础命令解析；
4. 将配置常量逐步应用到屏幕和终端模块；
5. 继续减少重复声明和硬编码数值。

## Day7结束
