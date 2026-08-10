# OrangeOS 演示流程

## 1. 构建和启动

```bash
make clean
make
make test
make run
```

`make test` 会无界面启动 QEMU 并验证 Kernel 与 Shell 启动标志，成功时输出
`OrangeOS boot smoke test passed`。测试采用快照模式，不会修改持久化文件系统。

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
memmap
status
syscall
selftest
user
run
ps
runfault
exec demo.oex
```

重点说明：

- 系统运行在 32 位保护模式并启用分页。
- 三个任务通过 PIT 时钟抢占式轮转。
- `int 0x80` 返回系统 tick、空闲页和 PID。
- `selftest` 应显示全项 PASS。
- `user` 应进入 Ring 3，调用内核服务后输出 `Ring3 OK` 并返回 Shell。
- `run` 创建独立 PID 4；运行期间用 `ps` 查看 READY/ticks，约五秒后状态变为 EXITED。
- `runfault` 令 PID 4 访问未映射页面；`ps` 应显示 FAULTED 和 `fault=0x50000000`，Shell 继续运行。
- `exec demo.oex` 从 OrangeFS 校验、解码并运行 OEX2 程序；随后 `ps` 应显示 `code=42`。
- `exec bad.oex` 应显示 `Invalid OEX2 executable`，验证长度与校验和保护。
- 在 `run` 前、运行中和退出后执行 `memmap`，已用页数应呈现 `N -> N+3 -> N`。
- `memmap` 使用 20 格占用条显示受管物理页的已用/空闲比例。
- `monitor` 进入实时系统界面，显示内存、调度器以及每个任务的运行 tick/CPU 占比；按 `Q` 或 `Esc` 返回。
- `status` 输出适合日志记录的单行系统快照。

## 3. 内存管理

```text
mem
memmap
alloc
mem
memmap
dealloc
mem
memmap
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
stat big.txt
disk
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
- OrangeFS ORF4 提供 7 个文件槽，每个文件最多占用两个扇区（1023 字节文本）。
- OrangeFS ORF4 使用 32 位空闲扇区位图；`touch` 分配 extent，`rm` 归还并允许复用。
- `date` 显示 UTC，不是北京时间。
