# OrangeOS Day31 开发日志

## 今日目标

继续完成 README 未落地功能：Shell 命令补全、启动动画，并为 GUI 与 Mini Game
扩充内核空间。

## 内核与磁盘布局扩展

内核由 40 个扇区扩展到 64 个扇区：

```text
LBA 0        boot sector
LBA 1        loader
LBA 2-65     32 KiB kernel
LBA 66       OrangeFS primary directory
LBA 67-98    OrangeFS data pool
LBA 99       OrangeFS backup directory
```

Loader 的 INT 13h Extensions DAP 与 Makefile 镜像大小检查同步更新，避免内核和
文件系统重叠。

## Tab 命令补全

键盘 IRQ 现在识别 Set-1 扫描码 `0x0F`。输入模块扫描命令表，只有一个命令匹配
当前前缀时才补全并重绘输入行；存在多个候选时保持输入不变。

示例：

```text
hel<Tab>  -> help
```

自动验证：

```bash
make test-autocomplete
```

## 启动动画

Loader 完成内核读取后通过 BIOS teletype 输出逐步进度条：

```text
OrangeOS loading [#####]
```

短延时只用于形成可见动画，不影响 3 秒启动冒烟测试。

## 下一阶段

- 增加 GUI 风格桌面；
- 增加可交互 Mini Game；
- 为两项交互功能增加键盘退出和自动化启动测试。
