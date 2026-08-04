#=================================
# OrangeOS Makefile
#=================================
.PHONY: all run clean

NASMFLAGS=-I include/ -f elf32

NASM=nasm
LD=ld
QEMU=qemu-system-i386

KERNEL_OBJS=\
kernel/kernel32.o \
kernel/screen32.o \
kernel/print32.o \
kernel/idt32.o \
kernel/pic32.o \
kernel/timer32.o \
kernel/keyboard32.o \
kernel/input32.o \
kernel/memory32.o \
kernel/paging32.o \
kernel/process32.o \
kernel/filesystem32.o \
kernel/shell32.o

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

kernel/kernel32.o: kernel/kernel32.asm include/kernel32.inc
	$(NASM) $(NASMFLAGS) kernel/kernel32.asm -o kernel/kernel32.o

kernel/screen32.o: kernel/screen32.asm
	$(NASM) $(NASMFLAGS) kernel/screen32.asm -o kernel/screen32.o

kernel/print32.o: kernel/print32.asm
	$(NASM) $(NASMFLAGS) kernel/print32.asm -o kernel/print32.o

kernel/idt32.o: kernel/idt32.asm
	$(NASM) $(NASMFLAGS) kernel/idt32.asm -o kernel/idt32.o

kernel/pic32.o: kernel/pic32.asm
	$(NASM) $(NASMFLAGS) kernel/pic32.asm -o kernel/pic32.o

kernel/timer32.o: kernel/timer32.asm
	$(NASM) $(NASMFLAGS) kernel/timer32.asm -o kernel/timer32.o

kernel/keyboard32.o: kernel/keyboard32.asm include/input32.inc
	$(NASM) $(NASMFLAGS) kernel/keyboard32.asm -o kernel/keyboard32.o
	
kernel/input32.o: kernel/input32.asm include/shell32.inc
	$(NASM) $(NASMFLAGS) kernel/input32.asm -o kernel/input32.o

kernel/memory32.o: kernel/memory32.asm
	$(NASM) $(NASMFLAGS) kernel/memory32.asm -o kernel/memory32.o

kernel/paging32.o: kernel/paging32.asm include/memory32.inc
	$(NASM) $(NASMFLAGS) kernel/paging32.asm -o kernel/paging32.o

kernel/process32.o: kernel/process32.asm
	$(NASM) $(NASMFLAGS) kernel/process32.asm -o kernel/process32.o

kernel/filesystem32.o: kernel/filesystem32.asm
	$(NASM) $(NASMFLAGS) kernel/filesystem32.asm -o kernel/filesystem32.o

kernel/shell32.o: kernel/shell32.asm include/keyboard32.inc include/filesystem32.inc include/memory32.inc include/process32.inc
	$(NASM) $(NASMFLAGS) kernel/shell32.asm -o kernel/shell32.o

kernel/kernel.bin: $(KERNEL_OBJS)
	$(LD) -m elf_i386 \
	-Ttext 0x10000 \
	$(KERNEL_OBJS) \
	-o kernel/kernel.bin \
	--oformat binary
	truncate -s 8192 kernel/kernel.bin

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
