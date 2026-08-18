# OrangeOS v1.0 答辩验收清单

这份清单是最终发布门禁。只有自动测试全通过、人工演示走通、工作区状态明确，才把版本标记为答辩候选版。

## 一、自动回归

在 WSL 的项目目录执行：

```bash
make test-release
```

最后必须显示：

```text
== OrangeOS release regression PASSED (16/16) ==
```

覆盖范围：启动与 Shell、Tab 补全、终端光标/换行/回看、GUI/文件 CRUD/两个游戏、Ring 3、用户进程生命周期、用户态异常隔离、页面回收、OEX2 加载，以及 OrangeFS 跨扇区、位图、双目录恢复和数据校验。

## 二、五分钟人工演示

执行 `make run`，按顺序输入：

```text
selftest
status
memmap
user
exec demo.oex
ps
ls
stat big.txt
gui
```

验收点：

- 启动动画结束后进入 Shell，硬件光标可见；
- `selftest` 显示全部 PASS，并包含 `RING3`；
- `user` 输出 `Ring3 OK` 后安全返回；
- OEX2 程序退出码为 42；
- OEX2 程序通过 `SYS_WRITE` 输出 `Hello from Ring3 OEX!`；
- GUI 可用上下键选择、Enter 打开、Q/Esc 返回；
- 文件管理器可用 `N` 新建、Enter 编辑、`F2` 保存、`Delete` 确认删除；
- 在 APPS 中进入游戏，左右键可移动角色；
- Shell 输入 `tetris`，验证移动、旋转、软降、硬降和返回；
- 长输入会跨行，`PageUp`/`PageDown` 可以查看历史输出。

## 三、异常与持久化演示（可选）

异常隔离：

```text
runfault
ps
selftest
```

PID 4 应为 `FAULTED`，地址为 `0x50000000`，Shell 和自检仍正常。

持久化（不要使用快照模式）：

```text
touch demo
write demo survives
reboot
cat demo
rm demo
```

重启后应读到 `survives`。测试完删除文件，避免改变答辩基准镜像。

## 四、发布前 Git 检查

```bash
git status --short
git log -1 --oneline
```

确认没有误提交的构建产物、截图或临时磁盘。任何已有但不属于本轮的删除或修改都要单独确认，不能顺手提交。

## 五、演示安全顺序

- `fault` 会触发内核态页故障并停机，只能最后演示；
- `shutdown` 会直接关闭 QEMU；
- `make clean` 会重建 `orange.img`，持久化演示前不要执行；
- 正式答辩前保留一份已通过 `make test-release` 的提交和镜像。
