#=================================
# OrangeOS Makefile
#=================================
.PHONY: all run clean

NASMFLAGS=-I include/ -f elf32

NASM=nasm
LD=ld
QEMU=qemu-system-i386

KERNEL_OBJS=\
kernel/kernel.o \
kernel/screen.o \
kernel/print.o \
kernel/keyboard.o \
kernel/input.o

all: orange.img

boot/boot.bin: boot/boot.asm
	$(NASM) boot/boot.asm -o boot/boot.bin

loader/loader.bin: loader/loader.asm
	$(NASM) loader/loader.asm -o loader/loader.bin

kernel/kernel.o: kernel/kernel.asm
	$(NASM) $(NASMFLAGS) kernel/kernel.asm -o kernel/kernel.o

kernel/screen.o: kernel/screen.asm
	$(NASM) $(NASMFLAGS) kernel/screen.asm -o kernel/screen.o

kernel/print.o: kernel/print.asm
	$(NASM) $(NASMFLAGS) kernel/print.asm -o kernel/print.o

kernel/keyboard.o:kernel/keyboard.asm
	$(NASM) $(NASMFLAGS) kernel/keyboard.asm -o kernel/keyboard.o

kernel/input.o:kernel/input.asm
	$(NASM) $(NASMFLAGS) kernel/input.asm -o kernel/input.o

kernel/kernel.bin: $(KERNEL_OBJS)
	$(LD) -m elf_i386 \
	-Ttext 0 \
	$(KERNEL_OBJS) \
	-o kernel/kernel.bin \
	--oformat binary
	truncate -s 4096 kernel/kernel.bin

orange.img: \
boot/boot.bin \
loader/loader.bin \
kernel/kernel.bin
	cat boot/boot.bin \
	loader/loader.bin \
	kernel/kernel.bin \
	> orange.img


run: orange.img
	$(QEMU) \
	-drive format=raw,file=orange.img


clean:
	rm -f \
	boot/*.bin \
	loader/*.bin \
	kernel/*.o \
	kernel/kernel.bin \
	orange.img