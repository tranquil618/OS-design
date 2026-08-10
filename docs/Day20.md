# OrangeOS Day20 开发日志

## 今日目标

把 Ring 3 演示程序升级为调度器管理的独立用户进程，并提供基本进程生命周期命令。

## 完成内容

### 1. PID 4 用户进程

进程表从三个内核任务扩展为四个任务：

```text
PID 1  kernel
PID 2  workerA
PID 3  workerB
PID 4  user
```

PID 4 拥有独立的 Ring 3 初始中断帧、用户栈和累计运行 tick。调度器会跳过
`EXITED` 任务，只轮转 `READY` 任务。

### 2. 进程命令

```text
run       创建或重新启动 PID 4
ps        查看 PID 4 状态和累计运行 tick
kill 4    终止等待调度的 PID 4
```

用户程序运行约五秒后调用 `SYS_EXIT`。Shell 在它运行期间仍会获得时间片，可以执行
`ps` 或 `kill 4`，证明用户程序不是同步内核函数。

典型过程：

```text
OrangeOS> run
PID4 user READY (about 5 seconds)
OrangeOS> ps
PID4 user state=READY ticks=30
OrangeOS> ps
PID4 user state=EXITED ticks=130
```

### 3. 调度退出路径

PID 4 调用 `SYS_EXIT` 时：

1. 将当前 PCB 标记为 `EXITED`；
2. 搜索下一个 `READY` 任务；
3. 切换到该任务保存的 IRQ 帧；
4. 通过 `IRETD` 恢复执行。

同步 `user` 命令仍保留，用于单独验证 Shell 到 Ring 3 再返回 Shell 的路径。

### 4. Monitor

实时 Monitor 的进程表扩展为四行，可以观察 PID 4 的状态、tick 和 CPU 占比。

### 5. 自动测试

```bash
make test-process
```

测试通过 QEMU 键盘自动执行 `run` 和两次 `ps`，检查 PID 4 经历：

```text
READY -> EXITED
```

成功输出：

```text
OrangeOS user process lifecycle test passed
```

## 当前边界

- 当前仅有一个固定用户进程槽位；
- 用户代码、数据和栈页面在启动时分配并在多次运行间复用；
- `kill` 当前只接受 PID 4；
- 尚未实现通用进程镜像加载和页级资源回收；
- 用户态异常隔离仍是下一阶段任务。

## 下一阶段

- 用户态页故障只终止 PID 4，不停止内核；
- 增加 `FAULTED` 状态和异常原因；
- 完成用户页销毁、重新分配和通用进程槽位。
