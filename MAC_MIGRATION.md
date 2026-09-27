# Mac 迁移说明

这是 x86 教学操作系统项目，不能作为普通 macOS 应用直接启动。构建使用 NASM、GNU Make、支持 ELF i386 的链接器，以及 qemu-system-i386。当前 Makefile 默认调用 `ld`，不要直接假定 macOS 自带链接器兼容；建议在兼容 Linux 环境中构建，或正确配置交叉工具链。

Python 文档生成脚本还依赖各脚本的导入库与字体。源码、docs 和 output 文档已保留；临时渲染目录 tmp、Python 缓存、构建目录及 orange.img 未纳入迁移提交。
