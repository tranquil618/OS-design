# OrangeOS Day28 开发日志

## 今日目标

为 OrangeFS 目录元数据增加完整性校验，形成 ORF6。

## 目录校验

目录仍位于 LBA 42，最后 4 字节现在保存 XOR 校验值：

```text
offset 0       ORF6 magic
offset 4       32-bit allocation bitmap
offset 8       7 directory entries
offset 176     reserved bytes
offset 508     checksum
```

保存目录时，内核对前 127 个双字执行 XOR，并把结果写到最后一个双字。读取时
对完整 128 个双字执行 XOR，结果必须为零。

## 启动恢复策略

启动时依次检查：

1. 魔数必须为 `ORF6`；
2. 目录扇区校验必须通过；
3. 任一检查失败时重新建立默认目录和默认文件。

这能阻止损坏的位图或目录项继续驱动磁盘分配。当前恢复方式会丢弃原目录，后续
版本可以通过目录双副本实现保留数据的恢复。

## 故障注入测试

```bash
make test-fs-checksum
```

测试流程：

1. 复制并启动一份磁盘镜像，使 ORF6 落盘；
2. 从宿主机修改 LBA 42 中的位图字节，但不更新校验值；
3. 再次启动镜像并执行 `disk`；
4. 验证系统恢复为 `OrangeFS free=25/32 sectors`。

## 下一阶段

- 保存主目录和备份目录两个副本；
- 增加版本号，在启动时选择校验有效且版本较新的副本；
- 模拟目录写入中断，验证备份副本恢复。
