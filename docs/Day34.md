# OrangeOS Day34 开发日志

## 今日目标

修复终端和 GUI 的四个交互缺口：输入光标、输出回看、长命令换行、桌面可操作性。

## 终端光标与长命令

键盘模块通过 VGA CRTC 端口 `0x3D4/0x3D5` 更新硬件光标。命令缓冲区从 64 字节
扩展到 128 字节，历史槽位步长同步调整。输入触及底部时会滚动一行，并继续在
最后一行输入，退格仍能跨行返回。

## PageUp/PageDown 回看

屏幕模块保存最近 16 个被滚走的文本行。按 `PageUp` 时保存当前 23 行实时画面，
显示历史内容和右侧滚动条；按 `PageDown` 原样恢复实时画面。

## 可操作 GUI

桌面维护焦点索引：

```text
Up/Down       move selection
Enter SYSTEM  open live monitor
Enter FILES   show OrangeFS file list
Enter APPS    start ORANGE CATCH
Q / Esc       return to Shell
```

Monitor 或游戏退出后重新启用中断并恢复桌面，避免在 `hlt` 上停住。

## 验证

```bash
make test-terminal
make test-ui
```

终端测试输入 90 个字符验证跨行，生成多屏帮助输出后发送 PageUp，并保存自动换行和
回看截图。GUI 测试从桌面内部打开 Monitor 与游戏，再依次返回桌面和 Shell。
