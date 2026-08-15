# OrangeOS Day36 开发日志

## Ring 3 SYS_WRITE

系统调用表新增 `SYS_WRITE`（调用号 5）：

```text
EAX = 5
ESI = 用户缓冲区虚拟地址
ECX = 输出字节数（1..127）
返回 EAX = 输出长度，错误返回 0xFFFFFFFF
```

中断处理程序检查保存的 CS，拒绝 Ring 0 伪调用；同时验证地址加法不溢出，且整个缓冲区必须位于当前映射的用户代码页、数据页或栈页内部，不能跨页进入未授权区域。验证后先复制到内核缓冲区，再调用内核终端输出。

## OEX2 示例升级

默认 `demo.oex` 现在包含机器码和内嵌字符串。执行时依次：

1. 将用户代码页内的字符串地址放入 ESI；
2. 通过 `int 0x80` 调用 `SYS_WRITE`；
3. 通过 `SYS_SET_RESULT` 设置结果 42；
4. 通过 `SYS_EXIT` 正常退出。

运行：

```text
exec demo.oex
ps
```

预期看到 `Hello from Ring3 OEX!` 和 `state=EXITED ... code=42`。

## 自动验证

`make test-exec` 同时检查用户态输出、正常退出、结果码和损坏 OEX2 拒绝路径。该功能形成 OrangeFS 读取、OEX2 校验装载、Ring 3 执行、系统调用和进程退出的完整闭环。
