# OrangeOS Day23 开发日志

## 今日目标

定义 OrangeOS 用户可执行文件格式，并从 OrangeFS 加载机器码到 Ring 3 执行。

## 完成内容

### 1. OEX1 文件格式

Orange Executable v1 使用适合当前小型文件系统的文本封装：

```text
OEX1:<hex encoded x86 machine code>
```

加载器会检查：

- 文件头必须严格为 `OEX1:`；
- 机器码必须非空；
- 每个字节必须由两个十六进制字符组成；
- 只接受 `0-9`、`A-F`、`a-f`；
- 当前解码长度上限为 256 字节。

格式或内存分配失败时，已分配的用户页会自动回滚。

### 2. exec 命令

Shell 新增：

```text
exec <file>
```

执行过程：

1. 从 OrangeFS 查找文件；
2. 验证并解码 OEX1；
3. 将机器码写入动态用户代码页；
4. 创建 PID 4 初始 Ring 3 调度帧；
5. 由调度器执行；
6. 正常退出、异常或 kill 后回收用户页。

### 3. 用户程序退出结果

新增系统调用 `SYS_SET_RESULT=4`。用户程序将结果放入 EBX 后调用，`ps` 在进程
正常退出后显示：

```text
PID4 user state=EXITED ticks=0 code=42
```

### 4. 默认 demo.oex

OrangeFS 默认包含：

```text
demo.oex
OEX1:BB2A000000B804000000CD80B803000000CD80
```

该程序设置结果 42，再调用 `SYS_EXIT`。

文件槽位由 4 个扩展为 5 个，因此加入默认程序后仍保留一个可创建文件的空槽位。

### 5. 自动测试

```bash
make test-exec
```

自动执行 `ls`、`exec demo.oex` 和 `ps`，确认文件存在、进程正常退出且结果为 42。

成功输出：

```text
OrangeOS OrangeFS executable loading test passed
```

## 下一阶段

- 扩大 OrangeFS 文件内容和多扇区存储；
- 为 OEX 增加二进制头、入口偏移、代码长度和校验和；
- 支持多个用户进程槽位和不同虚拟地址空间。
