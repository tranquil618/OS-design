# OrangeOS Day25 开发日志

## 今日目标

将 OrangeFS 从单扇区固定小文件升级为 ORF3 多扇区文件系统。

## ORF3 磁盘布局

```text
LBA 42       ORF3 directory
LBA 43-56    7 fixed extents, each 2 sectors
```

目录项包含：

- 16 字节文件名；
- 16 位文件长度；
- 起始 LBA；
- 扇区数量；
- 使用标志。

## 容量

- 文件槽：7 个；
- 每个文件：2 个连续扇区；
- 单文件有效文本容量：1023 字节；
- 目录和文件内容完全分离。

现有 `ls`、`cat`、`write`、`touch`、`rm` 和 `exec` 接口保持兼容。

## stat 命令

```text
stat <file>
```

示例：

```text
stat big.txt
size=700 bytes start=53 sectors=2
```

## 跨扇区验证

格式化时生成一个 700 字节的 `big.txt`。自检会读取并验证偏移：

```text
0, 511, 512, 699, 700
```

因此测试覆盖了第一个扇区尾部和第二个扇区开头，而不仅是目录元数据。

自动测试：

```bash
make test-fs-large
```

成功结果：

```text
OrangeOS multi-sector filesystem test passed
```

## 兼容性

ORF3 使用新魔数。检测到旧 ORF2 或空白磁盘时会格式化为 ORF3，因此旧测试文件不会自动迁移。

## 下一阶段

- 从固定 extent 升级为空闲扇区位图；
- 文件按实际大小动态分配和回收扇区；
- 扩大 Shell 输入与文件编辑能力；
- 允许 OEX2 使用更大的代码长度字段。
