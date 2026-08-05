# OrangeOS Day15 开发日志

## 今日目标

将 OrangeOS 从“可交互的 32 位内核”推进为具备完整演示链路的教学型操作系统，重点补齐任务调度、内存管理、分页、持久化文件系统、系统调用和系统监视能力。

## 完成内容

### 1. Kernel 加载空间扩展

- Loader 改用 BIOS `INT 13h AH=42h` 扩展 LBA 读取。
- Kernel 从 16 个扇区扩展到 32 个扇区。
- Kernel 镜像上限从 8 KiB 提升至 16 KiB。
- Makefile 增加真实大小检查，超过限制时停止构建，避免静默截断。

当前磁盘布局：

```text
LBA 0       Boot Sector
LBA 1       Loader
LBA 2-33    Kernel（32 sectors / 16 KiB）
LBA 34      OrangeFS 数据扇区
其余空间    预留
```

### 2. 多任务与调度

- 建立 PCB：PID、状态、ESP 和栈顶。
- 为三个任务建立独立内核栈：Kernel、Worker A、Worker B。
- IRQ0 每 10 tick 保存当前 ESP 并轮转到下一个任务。
- Worker A/B 在屏幕右上角显示独立活动标记。
- `task` 显示任务表，`monitor` 显示累计切换次数。

### 3. 内存检测和物理页管理

- Loader 使用 BIOS E820 获取内存映射。
- 内核汇总 type=1 的可用内存区域。
- 建立 4 KiB 物理页分配器。
- 支持已释放页的回收和复用。
- `alloc`、`dealloc` 和 `mem` 可直接验证页数变化。

### 4. 分页与异常诊断

- 动态分配页目录和页表。
- 对受管物理内存建立恒等映射。
- 加载 CR3 并设置 `CR0.PG`。
- IDT 向量 14 安装页故障处理器。
- 页故障时显示 CR2 地址并安全停机。
- `fault` 用于主动验证异常处理。

### 5. 内核堆

- 使用一张 4 KiB 物理页建立初始 Kernel Heap。
- 支持 8 字节对齐、first-fit、块拆分和相邻块合并。
- 提供 `kmalloc32` 和 `kfree32`。
- `malloc`、`free` 用于演示地址复用。

### 6. ATA PIO 与持久化 OrangeFS

- 新增 Primary Master ATA PIO 单扇区读写。
- 文件写入后执行 Cache Flush。
- OrangeFS 升级为 `ORF2` 动态目录格式。
- 支持最多 4 个文件、15 字符文件名和 63 字符内容。
- 支持 `ls`、`cat`、`write`、`touch` 和 `rm`。
- 文件内容写入 LBA 34，重新启动后仍然存在。

### 7. Shell 与终端

- 支持自动滚屏，同时保留顶部状态区域。
- 帮助内容拆成多行，避免 VGA 边界越界。
- 建立 8 条循环命令历史。
- `↑` 浏览旧命令，`↓` 返回新命令并恢复输入草稿。
- 命令和文件名采用大小写敏感规则。

### 8. 系统调用与硬件功能

- 将 `int 0x80` 改为系统调用分派器。
- 提供 ticks、空闲页数和当前 PID 查询。
- 系统调用门设置为 DPL3，为未来用户态预留。
- `date` 读取 CMOS RTC，并明确显示 UTC。
- `reboot` 通过 8042 控制器复位。
- `shutdown` 通过 QEMU/Bochs ACPI 端口关机。

### 9. 系统监视与自检

- `monitor` 显示 Uptime、Free Pages 和 Context Switches。
- `selftest` 检查保护模式、分页、IDT、内存、堆、调度、系统调用、ATA 和 OrangeFS。

成功结果：

```text
SELFTEST PASS: CPU PG IDT MEM HEAP TASK INT80 ATA FS
```

## 当前 Shell 命令

```text
help info clear date monitor task syscall selftest
mem alloc dealloc malloc free
ls cat write touch rm
reboot shutdown fault
```

## 当前限制

- 当前为 Ring 0 教学内核，尚未正式进入 Ring 3 用户态。
- 调度器管理三个预置内核任务，尚未支持运行时创建和退出任务。
- Kernel Heap 当前使用一张 4 KiB 初始页。
- OrangeFS 使用一个固定数据扇区，最多保存 4 个小文件。
- RTC 显示 UTC 时间。
- `fault` 会按设计停止系统，必须放在演示最后测试。

## 阶段结论

OrangeOS 已形成从 BIOS 启动、保护模式、硬件中断、多任务、分页、内存分配、磁盘持久化、Shell、系统调用到运行时自检的完整闭环，已经具备教学演示和项目答辩价值。
