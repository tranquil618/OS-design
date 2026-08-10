# OrangeOS Day18 开发日志

## 今日目标

将 Orange Monitor 从单行快照升级为实时系统监视界面，并增加按任务统计的运行时间和 CPU 占比。

## 完成内容

### 1. 实时 Monitor

执行：

```text
monitor
```

进入独立实时界面，每 10 个 PIT tick（约 0.1 秒）刷新一次。界面展示：

- 系统运行时间；
- 已用、总计和空闲物理页；
- 调度切换次数；
- 当前运行 PID；
- 三个任务的状态、累计运行 tick 和 CPU 百分比。

按 `Q` 或 `Esc` 清理 Monitor 界面并返回 Shell。Monitor 激活期间的其他按键会被消费，
不会泄漏到 Shell 输入缓冲区。

### 2. 调度运行时间统计

调度器在每次 PIT IRQ 中为当前任务累计一个运行 tick，并提供按任务读取接口。

当前 CPU 百分比计算：

```text
task runtime ticks * 100 / total PIT ticks
```

### 3. 快照命令

原单行 `monitor` 行为保留为：

```text
status
```

用于演示、日志和不希望进入实时界面时的快速检查。

### 4. 自检

`selftest` 现在除检查调度切换次数外，还要求三个任务的累计运行 tick 总和非零。

## 验证方式

```text
monitor
```

观察数值持续变化，按 `Q` 返回后执行：

```text
status
selftest
```

自动启动回归：

```bash
make test
```

预期：

```text
OrangeOS boot smoke test passed
```

## 下一阶段

开始正式用户态基础设施：内核 GDT、Ring 3 描述符、TSS、内核中断栈和用户页权限。
