# OrangeOS Day32 开发日志

## 今日目标

将用户提供视频的前 4 秒制作成 OrangeOS 个性化启动动画。

## 转换规格

源视频为 H.264、1280×576、30 FPS。为适配实模式 Loader 和 VGA 文本硬件，转换为：

```text
duration     4 seconds
frame rate   10 FPS
frames       40
resolution   320 x 200 pixels
palette      VGA 16 colours
asset size   2,560,000 bytes
```

每个像素保存一个 VGA 调色板编号。播放时 Loader 切换到 BIOS Mode 13h，并把帧
写入 `0xA0000` 图形显存。原始宽屏画面缩放为 320×144，上下各保留 28 像素黑边。

## 磁盘与内存布局

```text
image LBA 128+      boot video asset
memory 0x20000      one 64,000-byte streaming frame
```

Loader 每帧通过 INT 13h Extensions 读取 125 个扇区，正好得到 64,000 字节且不
跨越 64 KiB DMA 边界。每帧显示后使用 BIOS INT 15h 等待约 100 ms，40 帧播放约 4 秒。

## 构建流程

预生成帧资源已纳入仓库：

```text
assets/boot-video.bin
```

转换工具：

```bash
tools/video_to_vga.py input.mp4 assets/boot-video.bin --seconds 4 --fps 10
```

Makefile 在生成 1 MiB 镜像后把资源写入 LBA 128。自动测试的首次按键延迟和启动
超时也已调整，避免按键落在视频播放阶段。

## 已知限制

- VGA 16 色会呈现复古像素风格；
- 当前不播放 AAC 音轨；
- 启动画面固定播放 4 秒，后续可增加按键跳过。
