# OrangeOS 开发日志Day 2：BootLoader 实现阶段


## 一、今日开发目标

今天继续进行 OrangeOS 操作系统开发。
Day 1 完成了：BIOS | Boot Sector | boot.asm
实现了最基础的启动。
今天的目标是将系统升级为多阶段启动结构：
BIOS
↓
Boot Sector
↓
Boot Loader
↓
Loader程序
原因：一个完整操作系统不可能全部放入512字节的Boot Sector中。
因此需要设计BootLoader，让Boot
Sector负责启动，然后加载更大的程序，为后续加载Kernel做准备。

## 二、开发环境

操作系统环境：
-   Windows
-   WSL2
-   Ubuntu 22.04 LTS
开发工具：
-   NASM（汇编器）
-   GCC（C语言编译器）
-   Make（构建工具）
-   QEMU（x86模拟器）
-   GDB（调试工具）
-   VS Code
开发语言：-   x86 Assembly 汇编语言

## 三、今日完成内容

### 1. 创建 Loader 程序
新增目录：
loader/
其中包含：
loader.asm loader.bin
Loader功能：
1. 设置运行地址为0x9000
2. 调用BIOS显示服务INT 10h
3. 在屏幕显示字符：
L
4. 进入无限循环
目的：验证Boot Sector是否可以：
-   从磁盘读取其他程序
-   将程序加载到内存
-   跳转执行

---

### 2. 修改 Boot Sector
原来的Boot Sector只能显示字符。
今天修改后，Boot Sector具备了加载Loader的能力。
新的启动流程：
BIOS
↓
读取第1扇区
↓
执行boot.bin
↓
调用INT 13h读取磁盘
↓
加载loader.bin
↓
跳转到0x9000
↓
执行loader.asm
最终实现：Boot Sector → Loader

---

### 3. 解决磁盘扇区问题
测试过程中发现：
orange.img大小：520 bytes
原因：
boot.bin：512 bytes
loader.bin：8 bytes
但是BIOS读取磁盘时：以扇区为单位。一个磁盘扇区：512 bytes因此Loader必须扩展为：512 bytes
最终磁盘结构：第1扇区：Boot Sector  512 bytes
             第2扇区：Loader       512 bytes
整个镜像：1024 bytes

## 四、核心原理学习

### 1. BIOS启动流程
计算机启动时：
1. BIOS初始化硬件
2. BIOS寻找启动设备
3. BIOS读取磁盘第0扇区
4. 将该扇区加载到内存：0x7C00
5. CPU开始执行Boot Sector
因此：org 0x7c00
表示：告诉NASM程序运行位置。

---

### 2. Boot Sector限制
BIOS规定：
启动扇区大小：512字节
最后两个字节必须：55 AA
作用：
告诉BIOS：这是一个合法启动扇区。
结构：512 bytes
代码区域
-   
填充区域
-   
55 AA启动标志

---

### 3. BIOS磁盘读取 INT 13h
Boot Sector通过：INT 13h
调用BIOS磁盘服务。
其中：AH = 02h
表示：读取磁盘扇区。
相关寄存器：
AH：功能号
AL：读取扇区数量
CH：柱面号
CL：扇区号
DH：磁头号
DL：磁盘编号
ES:BX：目标内存地址
例如：
ES = 0000
BX = 9000
表示：
loader加载到：0000:9000

---

### 4. 程序跳转
加载完成后：
执行：jmp 0x0000:0x9000
作用：修改CPU执行位置。
CPU之后开始执行：
Loader程序。
这形成：
Boot Sector
↓
Loader
↓
Kernel
这样的多阶段启动结构。

## 五、今日使用的汇编指令总结

1. org
作用：指定程序运行地址。
例：org 0x7c00
表示：程序加载到0x7C00。

---

2. mov
作用：数据传送。
例：mov ax,0
表示：将0放入AX寄存器。
例：mov bx,0x9000
表示：设置加载地址。

---

3. int
作用：调用中断服务。
例：int 0x13
调用：BIOS磁盘服务。
例：int 0x10
调用：BIOS显示服务。

---

4. jc
作用：判断Carry Flag。
例：jc disk_error
如果磁盘读取失败：跳转错误处理。

---

5. jmp
作用：无条件跳转。
例：jmp 0x0000:0x9000
跳转执行Loader。
例：jmp $
无限循环。

---

6. times
作用：填充数据。
例：times 510-(−$) db 0
用于：将程序补齐到510字节。

---

7. dw
作用：定义一个16位数据。
例：dw 0xaa55
写入Boot Sector启动标志。

## 六、当前 OrangeOS 状态

已完成：
Day 1：
√ WSL环境配置
√ NASM/QEMU配置
√ 第一个Boot Sector
√ BIOS启动测试
Day 2：
√ 创建Loader
√ Boot Sector读取Loader
√ 成功跳转Loader
√ QEMU显示L
当前系统结构：
OrangeOS
├── boot
  ├── boot.asm
  └── boot.bin
├── loader
  ├── loader.asm
  └── loader.bin
├── kernel
├── lib
└── include

## 七、下一步开发计划

下一阶段：
Loader加载Kernel
目标结构：
BIOS
↓
Boot Sector
↓
Loader
↓
Kernel
计划完成：
1. 创建kernel.asm
2. 修改Loader读取Kernel
3. 从Loader跳转Kernel
4. 建立第一个OrangeOS Kernel入口
后续开发方向：
-   进入保护模式
-   实现GDT
-   实现IDT
-   键盘中断
-   时钟中断
-   进程调度
-   Shell系统
-   文件系统
-   系统监视器
-   图形界面

## 八、总结

今天 OrangeOS 完成了第一个重要架构升级。
系统不再只是：一个512字节的启动程序。
现在已经具备：Boot Sector-   Boot Loader
计算机已经可以：
1. 从BIOS启动
2. 从磁盘读取代码
3. 加载新的程序
4. 转移CPU执行权
这是后续Kernel开发、多任务系统、文件系统等所有功能的基础。
OrangeOS正式进入操作系统开发阶段。