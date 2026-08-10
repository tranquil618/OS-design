# OrangeOS Day19 开发日志

## 今日目标

建立正式的 Ring 3 用户态基础设施，并完成“Shell → 用户态 → 系统调用 → 安全退出 → Shell”的闭环。

## 完成内容

### 1. 内核 GDT

内核不再长期依赖 Loader 的最小 GDT。新 GDT 包含：

- Ring 0 code：`0x08`；
- Ring 0 data：`0x10`；
- Ring 3 code：`0x18`，用户选择子 `0x1B`；
- Ring 3 data：`0x20`，用户选择子 `0x23`；
- 32 位 Available TSS：`0x28`。

### 2. TSS 与特权级中断栈

- TSS 配置 `SS0=0x10`；
- `ESP0=0x0008F000`，与普通内核栈分离；
- 使用 `LTR` 装载 TSS；
- Ring 3 发生 IRQ 或 `int 0x80` 时，CPU 自动切换到内核栈。

### 3. 隔离的用户页

运行时分配并映射三个用户页：

```text
0x40000000  用户代码页  U/S=1, R/W=1
0x40001000  用户数据页  U/S=1, R/W=1
0x40002000  用户栈页    U/S=1, R/W=1
```

原有内核恒等映射的 PTE 继续保持 supervisor-only。没有为了进入 Ring 3 而开放全部内核内存。

### 4. 用户程序与系统调用

Shell 新增：

```text
user
```

用户程序在 CPL3 依次调用：

- `SYS_GET_TICKS`；
- `SYS_GET_FREE`；
- `SYS_GET_PID`；
- `SYS_EXIT`。

成功输出示例：

```text
Ring3 OK: ticks=97 free=32442 pid=1
```

`SYS_EXIT` 检查调用者 CS 的 RPL，只有 Ring 3 调用才能执行特权级返回路径。

### 5. 自动测试

基础启动：

```bash
make test
```

完整 Ring 3 路径：

```bash
make test-ring3
```

后者通过 QEMU 虚拟键盘输入 `user`，并检查 Ring 3 结果及返回后的 Shell 提示符。

## 当前边界

- 当前只有一个内置用户程序；
- 用户页在初始化时分配，尚未在每次退出后回收；
- 用户程序仍属于 PID 1 的一次受控执行，不是独立 PCB；
- 页面为可写可执行，尚未实现 W^X；
- 用户态页故障仍会停止整个内核。

## 下一阶段

- 用户态页故障转为终止当前用户进程；
- 将用户程序建立为独立 PCB；
- 增加进程创建、退出和资源回收；
- 扩展 `ps`、`run` 和 `kill` Shell 命令。
