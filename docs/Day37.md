# OrangeOS Day37 开发日志

## GUI 文件 CRUD

文件管理器补齐创建和删除操作，与已有的读取、编辑和保存组成完整 CRUD：

- `N` 打开文件名输入界面；
- 文件名接受小写字母、数字、点和连字符，最长 15 字节；
- Enter 创建后自动打开空白编辑器；
- `F2` 通过 OrangeFS 保存内容；
- `Delete` 打开确认页；
- Enter 确认删除，Esc 取消；
- 删除后修正选择位置，并显示成功或失败状态。

创建和删除分别复用 `fs_create32`、`fs_delete32`，因此目录版本、校验和、双目录同步与 extent 回收机制保持一致。

## 内核镜像布局升级

CRUD 界面使内核原始大小达到 33,223 字节，超过原 32 KiB 门禁。装载区正式扩展为 40 KiB：

```text
LBA 0        Boot Sector
LBA 1        Loader
LBA 2-81     Kernel（80 sectors / 40 KiB）
LBA 82       OrangeFS 主目录
LBA 83-114   OrangeFS 数据池（32 sectors）
LBA 115      OrangeFS 备份目录
LBA 128+     启动视频资源
```

Loader 的 INT 13h 扩展读取数量、内核大小门禁、OrangeFS 常量和故障注入测试偏移均已同步更新。内核、文件系统和视频资源之间保留明确间隔，不发生覆盖。

## 自动验证

```bash
make test-ui-crud
```

测试在快照磁盘中执行“新建 `new.txt` → 写入 `hi` → F2 保存 → 删除确认 → Shell `ls` 验证文件消失”。完整发布门禁扩展为 15 项测试。
