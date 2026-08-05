# OrangeOS 演示流程

## 1. 构建和启动

```bash
make clean
make
make run
```

启动后确认：

- 显示 `OrangeOS 32-bit Kernel Started!`
- 右上角两个彩色字符持续变化
- 出现 `OrangeOS>` 提示符

## 2. 核心状态

```text
info
date
task
monitor
syscall
selftest
```

重点说明：

- 系统运行在 32 位保护模式并启用分页。
- 三个任务通过 PIT 时钟抢占式轮转。
- `int 0x80` 返回系统 tick、空闲页和 PID。
- `selftest` 应显示全项 PASS。

## 3. 内存管理

```text
mem
alloc
mem
dealloc
mem
malloc
free
malloc
```

观察：

- `alloc` 后 Free Pages 减少 1。
- `dealloc` 后页数恢复，再次分配复用同一地址。
- Heap 释放后再次申请复用同一块地址。

## 4. 持久化文件系统

```text
ls
touch demo.txt
write demo.txt OrangeOS disk persistence
cat demo.txt
reboot
cat demo.txt
rm demo.txt
ls
```

重启后内容仍存在，证明数据已经通过 ATA PIO 写入磁盘镜像。

## 5. 命令历史

依次执行几条命令，然后：

- 连续按 `↑` 浏览更旧的命令。
- 连续按 `↓` 返回更新的命令。
- 先输入草稿再浏览历史，回到最新位置后草稿应恢复。

## 6. 终端滚屏

连续执行多条 `help`、`monitor` 或 `date`，确认：

- 内容自动向上滚动。
- 顶部 Kernel 状态区域保持不动。
- 提示符始终出现在正确位置。

## 7. 最后执行的命令

以下命令会结束当前运行环境，只能放在演示最后：

```text
fault
```

预期显示红色：

```text
PAGE FAULT CR2=0x40000000
```

重新启动后可测试：

```text
shutdown
```

QEMU 窗口应直接关闭。

## 演示注意事项

- 不要在持久化测试中执行 `make clean`，否则磁盘镜像会重新生成。
- 文件名和命令区分大小写。
- OrangeFS 最多保存 4 个文件，文件名不超过 15 字符。
- `date` 显示 UTC，不是北京时间。
