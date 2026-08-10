# OrangeOS Day26 开发日志

## 今日目标

将 ORF3 固定 extent 升级为 ORF4 空闲扇区位图分配与回收。

## ORF4 布局

```text
LBA 42       ORF4 目录与 32 位空闲位图
LBA 43-74    32 个数据扇区
```

位图中每一位对应一个数据扇区：1 表示已分配，0 表示空闲。

## 动态 extent

- `touch` 从位图查找两个连续空闲扇区；
- 目录项记录实际分配的起始 LBA 和扇区数；
- `rm` 清除对应位图位并归还 extent；
- 后续文件可以复用已释放的相同 LBA；
- 默认六个文件占用 12 个扇区，启动后剩余 20/32。

## disk 命令

```text
disk
```

示例：

```text
OrangeFS free=20/32 sectors
```

## 生命周期验证

```text
disk
touch temp
disk
stat temp
rm temp
disk
touch again
stat again
```

实测：

```text
free=20/32
free=18/32
temp  start=55 sectors=2
free=20/32
again start=55 sectors=2
```

这证明位图占用、删除回收和 extent 复用均正常。

## 自动测试

```bash
make test-fs-bitmap
```

成功输出：

```text
OrangeOS filesystem bitmap allocation test passed
```

## 下一阶段

- 根据实际文件长度分配 1 或 2 个扇区；
- 文件增长时扩展或搬迁 extent；
- 增加目录校验和与崩溃一致性更新顺序。
