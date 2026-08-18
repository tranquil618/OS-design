# OrangeOS Day38 开发日志

## ORANGE TETRIS

新增独立全屏应用 `kernel/tetris32.asm`，Shell 输入：

```text
tetris
```

即可进入文本模式俄罗斯方块。

功能包括：

- 10×18 固定棋盘；
- I、O、T、S、Z、J、L 七类 Tetromino；
- 每类方块四种旋转数据；
- 棋盘边界和已落地方块碰撞检测；
- PIT tick 控制自动下降；
- 完整行检测、下移和清除；
- 软降、硬降和消行计分；
- 顶部碰撞后的 Game Over；
- Q/Esc 安全返回 Shell。

## 键盘与并发设计

键盘 IRQ 只把操作记录到 `tetris_action`，不在中断处理程序内执行碰撞、消行或绘制。游戏主循环在下一次唤醒时处理动作，降低 IRQ 临界路径复杂度。

```text
Left/Right  移动
Up          旋转
Down        软降
Space       硬降
Q/Esc       退出
```

## 自动验证

```bash
make test-tetris
```

测试通过 QEMU monitor 输入启动命令和全部控制键，最后验证游戏就绪标志以及返回后的 Shell 提示符。完整发布门禁扩展为 16 项测试。
