# OrangeOS Day17 开发日志

## 今日目标

完成 README Week 4 的 Memory Visualization，并增强 Orange Monitor 的运行状态展示。

## 完成内容

### 1. 物理页统计 API

内存管理器新增：

- 总受管物理页数；
- 当前已用页数；
- 当前空闲页数；
- `used + free == total` 一致性检查。

页分配和释放后，统计与可视化会同步变化。

### 2. Memory Visualization

Shell 新增命令：

```text
memmap
```

示例：

```text
Memory Map used=4/16128 pages [#-------------------]
```

- `#` 表示已经分配给内核、分页结构或 Heap 的受管页；
- `-` 表示仍可分配的物理页；
- 显示条共 20 格，并对少量真实占用向上取整，避免占用存在但完全不可见。

可使用以下命令观察变化：

```text
memmap
alloc
memmap
dealloc
memmap
```

### 3. Orange Monitor 增强

`monitor` 现在显示：

- Uptime；
- Free Pages；
- Used/Total Pages；
- 当前 PID；
- Context Switches。

示例：

```text
Uptime=12s | Free=16124 Used=4/16128 | PID=1 | Switches=120
```

### 4. 自检增强

`selftest` 增加内存页账目检查，确认：

```text
used pages + free pages == total managed pages
```

## 验证

```bash
make test
```

结果：

```text
OrangeOS boot smoke test passed
```

### 验证修正

手动演示发现首版 `memmap` 的 `used` 数字会显示为 0，而占用条和 `monitor`
仍显示真实占用。原因是字符串追加函数使用 `AL` 复制字符，覆盖了待格式化的数值。
现已调整取值顺序：先追加标签，再读取已用页数，确保数字、占用条和 Monitor
来自同一份内存账目。

## 下一阶段

- 将 Monitor 从单次快照升级为可退出的实时刷新界面；
- 增加每个进程的状态、运行 tick 和调度占比；
- 完成后开始 Ring 3、TSS 和用户地址空间。
