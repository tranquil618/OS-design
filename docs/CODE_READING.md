# OrangeOS 一周读代码路线

目标不是逐行背诵，而是能从“启动、硬件、内核机制、系统服务、交互展示”五条链路解释设计，并指出每项功能如何验证。

## Day 1：启动链路

阅读 `boot/boot.asm`、`loader/loader.asm`、`kernel/kernel32.asm` 和 `Makefile`。

讲清楚 BIOS 如何加载 Boot Sector，Loader 如何装入内核和视频资源，怎样进入保护模式，以及链接地址、镜像扇区布局为什么不能冲突。

## Day 2：中断与输入输出

阅读 `kernel/idt32.asm`、`pic32.asm`、`timer32.asm`、`keyboard32.asm`、`screen32.asm` 和 `input32.asm`。

讲清楚 IDT/PIC/PIT、IRQ0/IRQ1、VGA 文本缓冲区、硬件光标、长行换行与 scrollback 的数据流。

## Day 3：内存与分页

阅读 `memory32.asm`、`paging32.asm`、`heap32.asm`。

讲清楚物理页位图、页表映射、堆块复用，以及用户进程运行时为什么增加三页、退出后如何归还。

## Day 4：进程、Ring 3 与系统调用

阅读 `process32.asm`、`usermode32.asm`、`syscall32.asm`、`gdt32.asm`。

讲清楚 PCB 状态、时钟调度、TSS/特权级切换、`int 0x80`、正常退出和用户态页故障隔离。

## Day 5：磁盘与 OrangeFS

阅读 `ata32.asm`、`filesystem32.asm`。

画出主目录、数据区、备份目录；讲清楚 extent、位图、目录版本/校验、文件数据校验，以及损坏时如何恢复或拒绝读取。

## Day 6：Shell、Monitor 与 GUI

阅读 `shell32.asm`、`monitor32.asm`、`ui32.asm`、`selftest32.asm`。

从键盘输入跟踪到命令分发，再跟踪 `gui`、`game`、`selftest` 的调用路径。准备解释为什么 GUI 是内核内的全屏交互界面，而不是窗口系统。

## Day 7：模拟答辩

按 `docs/RELEASE_CHECKLIST.md` 完整演示两遍：第一遍边操作边看稿，第二遍脱稿。然后随机抽取三个功能，分别回答：

1. 入口函数在哪里？
2. 核心数据结构或状态是什么？
3. 硬件或内核机制是什么？
4. 失败路径如何处理？
5. 用哪个命令或测试证明它工作？

最后复习 `docs/DEMO.md`，把完整演示压缩到五分钟，并预留故障恢复时间。
