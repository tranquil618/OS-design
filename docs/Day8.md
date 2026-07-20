# OrangeOS Day8 开发日志

## Kernel栈初始化、多扇区加载与GDT结构

## 一、今日开发目标

今天开始为 OrangeOS 进入保护模式做准备，主要完成：

1. 为 Kernel 初始化独立栈；
2. 将 Kernel 的加载空间从一个扇区扩展到八个扇区；
3. 调整磁盘镜像中的 Kernel 大小；
4. 修正 Loader 的段寄存器设置；
5. 在 Loader 中建立基础 GDT；
6. 验证修改后系统仍然可以正常启动。

今天暂时没有开启 A20，也没有正式切换到保护模式。当前重点是先把所需的基础结构准备好，并保证每一步都可以独立运行验证。

## 二、初始化Kernel独立栈

Kernel 已经使用多个函数调用，例如：

```asm
call clear_screen
call print_color_string
call newline
call get_key
```

`call` 和 `ret` 都需要使用栈。此前 Kernel 没有主动初始化 `SS:SP`，可能继续使用 BIOS 或 Loader 遗留下来的栈环境。

今天在 Kernel 入口增加：

```asm
cli

mov ax,0x1000
mov ss,ax
mov sp,0xFFFE

mov ds,ax

sti
```

其中：

- `cli` 在修改栈段期间关闭中断；
- `SS = 0x1000` 设置 Kernel 栈段；
- `SP = 0xFFFE` 设置栈顶偏移；
- `sti` 在栈初始化完成后重新开启中断。

当前栈顶物理地址为：

```text
0x1000 × 16 + 0xFFFE = 0x1FFFE
```

Kernel 从物理地址 `0x10000` 开始加载，栈从较高地址向低地址增长。

完成这一步后，Kernel 的函数调用不再完全依赖启动前遗留的栈状态。

## 三、扩大Kernel加载空间

此前 Loader 只读取一个 Kernel 扇区：

```asm
mov al,1
```

一个磁盘扇区只有：

```text
512 bytes
```

随着键盘、输入、终端和后续 GDT 相关代码增加，单个扇区很快会无法容纳完整 Kernel。

今天将 Loader 修改为：

```asm
mov al,8
```

因此 Loader 现在会从第 3 扇区开始，连续读取八个扇区：

```text
8 × 512 = 4096 bytes
```

当前读取参数为：

```asm
mov ch,0
mov cl,3
mov dh,0
mov dl,0x80
```

表示从第 0 柱面、第 0 磁头的第 3 扇区开始读取 Kernel。

## 四、补齐Kernel镜像

为了保证磁盘镜像中实际存在八个完整的 Kernel 扇区，在 Makefile 的链接规则后增加：

```makefile
truncate -s 4096 kernel/kernel.bin
```

Kernel 完成链接后，会被补齐到：

```text
4096 bytes
```

当前生成文件大小为：

```text
boot/boot.bin       512 bytes
loader/loader.bin   512 bytes
kernel/kernel.bin  4096 bytes
orange.img         5120 bytes
```

当前磁盘镜像布局：

```text
第 1 扇区       Boot Sector
第 2 扇区       Loader
第 3～10 扇区   Kernel
```

整个镜像大小：

```text
512 + 512 + 4096 = 5120 bytes
```

这为后续增加保护模式和中断相关代码预留了更多空间。

## 五、调整Loader段寄存器

Loader 使用：

```asm
org 0x9000
```

并从：

```text
0000:9000
```

开始执行。

为了让 Loader 能够正确访问自己内部的 GDT 和 GDT 描述符，数据段设置为：

```asm
mov ax,0x0000
mov ds,ax
```

加载 Kernel 时，目标内存地址仍然使用：

```asm
mov ax,0x1000
mov es,ax
mov bx,0x0000
```

因此：

```text
DS       → Loader自身的数据
ES:BX    → Kernel加载目标地址
```

Kernel 的实际加载地址为：

```text
0x1000:0x0000 = 0x10000
```

## 六、建立基础GDT

今天在 Loader 中加入了 Global Descriptor Table。

当前 GDT 包含三个描述符：

```text
GDT
├── 空描述符
├── 32位代码段描述符
└── 32位数据段描述符
```

### 1. 空描述符

```asm
gdt_null:
    dq 0x0000000000000000
```

GDT 的第一个描述符必须为空描述符。

### 2. 32位代码段描述符

```asm
gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00
```

该描述符定义了一个基地址为 `0`、可读、可执行的 32 位代码段。

### 3. 32位数据段描述符

```asm
gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
```

该描述符定义了一个基地址为 `0`、可读写的 32 位数据段。

## 七、GDT描述符与段选择子

GDT 描述符记录 GDT 的长度和基地址：

```asm
gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start
```

其中：

- `gdt_end-gdt_start-1` 是 GDT 的界限；
- `gdt_start` 是 GDT 的线性基地址。

代码段和数据段选择子定义为：

```asm
CODE_SELECTOR equ gdt_code-gdt_start
DATA_SELECTOR equ gdt_data-gdt_start
```

对应结果：

```text
CODE_SELECTOR = 0x08
DATA_SELECTOR = 0x10
```

每个 GDT 描述符占八个字节，因此：

```text
0x00  空描述符
0x08  代码段描述符
0x10  数据段描述符
```

## 八、当前GDT状态

GDT 目前已经作为静态数据写入 Loader，但还没有执行：

```asm
lgdt [gdt_descriptor]
```

也还没有修改：

```text
CR0.PE
```

因此 OrangeOS 当前仍然运行在：

```text
16位实模式
```

今天只建立 GDT 数据结构，没有提前进行 CPU 模式切换，便于单独验证 GDT 的加入是否影响原有启动过程。

## 九、运行验证

完成修改后重新构建并启动，系统仍然能够：

- 从 BIOS 启动；
- 加载 Boot Sector；
- 进入 Loader；
- 读取八个 Kernel 扇区；
- 跳转到 Kernel；
- 初始化独立栈；
- 显示 Kernel 启动信息；
- 显示 `OrangeOS>`；
- 正常接收键盘输入。

`loader.bin` 仍然保持为：

```text
512 bytes
```

说明 GDT 数据结构仍然可以放入当前 Loader 扇区。

## 十、今日成果总结

今天完成了：

- Kernel 独立栈初始化；
- 在修改栈期间正确控制中断；
- Loader 从一个扇区升级为读取八个 Kernel 扇区；
- Kernel 镜像补齐到 4096 字节；
- 磁盘镜像扩展到 5120 字节；
- 明确 Loader 的 `DS` 与 Kernel 加载地址 `ES:BX`；
- 建立 GDT 空描述符；
- 建立 32 位代码段描述符；
- 建立 32 位数据段描述符；
- 定义 GDT 描述符和段选择子；
- 验证系统仍可正常启动。

OrangeOS 已经完成进入保护模式前的重要基础准备。

## 十一、下一步计划

下一阶段计划：

1. 开启 A20 地址线；
2. 使用 `lgdt` 加载 GDT；
3. 关闭中断；
4. 设置 `CR0.PE`；
5. 通过远跳转进入 32 位代码段；
6. 重新设置保护模式下的段寄存器和栈；
7. 使用 VGA 显存显示保护模式启动信息。

目标显示：

```text
Protected Mode
32-bit
```

## Day8结束
