# OrangeOS Day21 开发日志

## 今日目标

实现用户态异常隔离：Ring 3 页故障只终止故障进程，不再停止整个内核。

## 完成内容

### 1. CPL 感知的 Page Fault Handler

页故障处理器读取 CPU 异常帧中的 CS，并检查 RPL：

- RPL 0：属于内核页故障，显示 CR2 后停机；
- RPL 3：记录异常并终止当前用户进程，然后恢复下一个 READY 任务。

异常帧中的 error code 会被正确跳过，不会混入下一个任务的 `IRETD` 帧。

### 2. FAULTED 进程状态

新增 `FAULTED` 状态，并记录：

- CR2 故障地址；
- Page Fault error code；
- 故障 EIP（内核内部记录）。

`ps` 示例：

```text
PID4 user state=FAULTED ticks=0 fault=0x50000000 err=0x00000004
```

错误码 `0x00000004` 表示 Ring 3 对不存在页面执行读取。

### 3. 故障测试程序

Shell 新增：

```text
runfault
```

它启动 PID 4，并在 Ring 3 主动读取未映射地址 `0x50000000`。预期 PID 4
变为 `FAULTED`，Shell、时钟中断和其他任务继续运行。

### 4. Monitor

实时 Monitor 现在能够区分并显示：

- `READY`
- `RUNNING`
- `EXITED`
- `FAULTED`

### 5. 内核布局扩展

异常隔离加入后内核实际大小超过原 16 KiB 上限，因此磁盘布局扩展为：

```text
LBA 0       Boot Sector
LBA 1       Loader
LBA 2-41    Kernel（40 sectors / 20 KiB）
LBA 42      OrangeFS 数据扇区
```

Loader、构建大小检查和 OrangeFS LBA 已同步调整。

### 6. 自动验证

```bash
make test-userfault
```

自动执行 `runfault`、`ps` 和 `selftest`，并确认：

- PID 4 状态为 `FAULTED`；
- CR2 为 `0x50000000`；
- `selftest` 仍然通过。

成功输出：

```text
OrangeOS user page-fault isolation test passed
```

## 下一阶段

- 用户页按进程创建与释放；
- 清理 FAULTED/EXITED 进程资源；
- 从 OrangeFS 加载用户程序镜像；
- 将固定 PID 4 扩展为通用进程槽位。
