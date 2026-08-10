# OrangeOS Day27 开发日志

## 今日目标

将 ORF4 的固定双扇区分配升级为 ORF5 可变 extent。

## 空间分配规则

- `touch <file>` 只创建目录项，初始 `start=0 sectors=0`；
- `write` 内容为 0–512 字节时使用 1 个扇区；
- 内容为 513–1023 字节时使用 2 个连续扇区；
- 文件跨越 512 字节边界时释放旧 extent，再按新长度重新分配；
- `rm` 根据目录项记录的实际扇区数清除位图。

默认文件压缩到 LBA 43–49，共占 7/32 个数据扇区，所以：

```text
OrangeFS free=25/32 sectors
```

## 手工验证

```text
disk
touch temp
disk
write temp hi
stat temp
disk
rm temp
disk
```

预期空闲量为 `25 -> 25 -> 24 -> 25`，`temp` 写入后显示
`size=2 bytes` 和 `sectors=1`。

多扇区默认文件仍可验证：

```text
stat big.txt
```

预期为：

```text
size=700 bytes start=48 sectors=2
```

## 自动测试

```bash
make test-fs-large
make test-fs-bitmap
```

## 下一阶段

- 为目录元数据增加校验；
- 设计目录双副本或提交标志，降低写入中断造成的损坏风险；
- 增加磁盘满和无连续双扇区时的失败路径测试。
