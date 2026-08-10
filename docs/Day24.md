# OrangeOS Day24 开发日志

## 今日目标

将 OEX1 升级为具有入口、长度和完整性校验的 OEX2 可执行格式。

## OEX2 格式

```text
OEX2:EE:LL:CC:<hex machine code>
```

- `EE`：1 字节入口偏移；
- `LL`：1 字节解码后代码长度；
- `CC`：所有代码字节相加后的 8 位校验和；
- 后续内容：严格为 `LL * 2` 个十六进制字符。

加载器拒绝以下情况：

- 魔数或分隔符错误；
- 长度为零；
- 入口偏移不小于代码长度；
- 实际代码长度与头部不一致；
- 非十六进制字符；
- 校验和不一致；
- 尾部存在多余数据。

校验失败时，动态分配的用户页会立即回收，不会创建 PID 4。

## 入口偏移

PID 4 的初始 EIP 不再固定为用户代码页起始地址，而是：

```text
0x40000000 + EE
```

## 默认程序

有效示例：

```text
demo.oex
OEX2:00:13:F6:BB2A000000B804000000CD80B803000000CD80
```

损坏示例（校验和故意错误）：

```text
bad.oex
OEX2:00:01:00:90
```

OrangeFS 槽位扩为 6 个，加入两个 OEX 文件后仍保留一个空槽。

## 验证

```text
exec demo.oex
ps
exec bad.oex
```

预期：

```text
PID4 user state=EXITED ticks=0 code=42
Invalid OEX2 executable
```

自动测试继续使用：

```bash
make test-exec
```

## 下一阶段

将 OrangeFS 升级为多扇区布局，扩大文件内容容量，为更大的 OEX2 程序提供存储空间。
