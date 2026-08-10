#=================================
# OrangeOS Makefile
#=================================
.PHONY: all run test test-ring3 test-process test-userfault test-resources test-exec test-fs-large test-fs-bitmap test-fs-checksum test-fs-data-checksum clean

NASMFLAGS=-I include/ -f elf32

NASM=nasm
LD=ld
QEMU=qemu-system-i386

KERNEL_OBJS=\
kernel/kernel32.o \
kernel/gdt32.o \
kernel/screen32.o \
kernel/print32.o \
kernel/idt32.o \
kernel/pic32.o \
kernel/timer32.o \
kernel/keyboard32.o \
kernel/input32.o \
kernel/memory32.o \
kernel/paging32.o \
kernel/usermode32.o \
kernel/heap32.o \
kernel/monitor32.o \
kernel/power32.o \
kernel/syscall32.o \
kernel/rtc32.o \
kernel/selftest32.o \
kernel/process32.o \
kernel/ata32.o \
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

kernel/gdt32.o: kernel/gdt32.asm
	$(NASM) $(NASMFLAGS) kernel/gdt32.asm -o kernel/gdt32.o

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

kernel/keyboard32.o: kernel/keyboard32.asm include/input32.inc include/monitor32.inc
	$(NASM) $(NASMFLAGS) kernel/keyboard32.asm -o kernel/keyboard32.o
	
kernel/input32.o: kernel/input32.asm include/shell32.inc
	$(NASM) $(NASMFLAGS) kernel/input32.asm -o kernel/input32.o

kernel/memory32.o: kernel/memory32.asm
	$(NASM) $(NASMFLAGS) kernel/memory32.asm -o kernel/memory32.o

kernel/paging32.o: kernel/paging32.asm include/memory32.inc
	$(NASM) $(NASMFLAGS) kernel/paging32.asm -o kernel/paging32.o

kernel/usermode32.o: kernel/usermode32.asm include/memory32.inc include/paging32.inc
	$(NASM) $(NASMFLAGS) kernel/usermode32.asm -o kernel/usermode32.o

kernel/heap32.o: kernel/heap32.asm include/memory32.inc
	$(NASM) $(NASMFLAGS) kernel/heap32.asm -o kernel/heap32.o

kernel/monitor32.o: kernel/monitor32.asm include/memory32.inc include/process32.inc
	$(NASM) $(NASMFLAGS) kernel/monitor32.asm -o kernel/monitor32.o

kernel/power32.o: kernel/power32.asm
	$(NASM) $(NASMFLAGS) kernel/power32.asm -o kernel/power32.o

kernel/syscall32.o: kernel/syscall32.asm
	$(NASM) $(NASMFLAGS) kernel/syscall32.asm -o kernel/syscall32.o

kernel/rtc32.o: kernel/rtc32.asm
	$(NASM) $(NASMFLAGS) kernel/rtc32.asm -o kernel/rtc32.o

kernel/selftest32.o: kernel/selftest32.asm include/memory32.inc include/gdt32.inc include/usermode32.inc
	$(NASM) $(NASMFLAGS) kernel/selftest32.asm -o kernel/selftest32.o

kernel/process32.o: kernel/process32.asm
	$(NASM) $(NASMFLAGS) kernel/process32.asm -o kernel/process32.o

kernel/ata32.o: kernel/ata32.asm
	$(NASM) $(NASMFLAGS) kernel/ata32.asm -o kernel/ata32.o

kernel/filesystem32.o: kernel/filesystem32.asm include/ata32.inc
	$(NASM) $(NASMFLAGS) kernel/filesystem32.asm -o kernel/filesystem32.o

kernel/shell32.o: kernel/shell32.asm include/keyboard32.inc include/filesystem32.inc include/memory32.inc include/process32.inc include/heap32.inc include/monitor32.inc include/power32.inc include/syscall32.inc include/rtc32.inc include/selftest32.inc include/usermode32.inc
	$(NASM) $(NASMFLAGS) kernel/shell32.asm -o kernel/shell32.o

kernel/kernel.bin: $(KERNEL_OBJS)
	$(LD) -m elf_i386 \
	-Ttext 0x10000 \
	$(KERNEL_OBJS) \
	-o kernel/kernel.bin \
	--oformat binary
	test $$(stat -c%s kernel/kernel.bin) -le 20480
	truncate -s 20480 kernel/kernel.bin

orange.img: \
boot/boot.bin \
loader/loader.bin \
kernel/kernel.bin
	cat boot/boot.bin \
	loader/loader.bin \
	kernel/kernel.bin \
	> orange.img
	truncate -s 1048576 orange.img


run: orange.img
	$(QEMU) \
	-drive format=raw,file=orange.img

test: orange.img
	mkdir -p build
	rm -f build/debugcon.log
	timeout 3s $(QEMU) \
	-drive format=raw,file=orange.img \
	-snapshot \
	-display none \
	-monitor none \
	-serial none \
	-no-reboot \
	-debugcon file:build/debugcon.log \
	-global isa-debugcon.iobase=0xe9 \
	|| [ $$? -eq 124 ]
	grep -q "OrangeOS 32-bit Kernel Started!" build/debugcon.log
	grep -q "OrangeOS> " build/debugcon.log
	@echo "OrangeOS boot smoke test passed"

test-ring3: orange.img
	mkdir -p build
	rm -f build/ring3.log
	( sleep 1; \
	echo 'sendkey u'; echo 'sendkey s'; echo 'sendkey e'; echo 'sendkey r'; \
	echo 'sendkey ret'; sleep 7; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/ring3.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q "Ring3 OK:" build/ring3.log
	grep -q "Ring3 OK:.*pid=1OrangeOS> " build/ring3.log
	@echo "OrangeOS Ring3 transition test passed"

test-process: orange.img
	mkdir -p build
	rm -f build/process.log
	( sleep 1; \
	echo 'sendkey r'; echo 'sendkey u'; echo 'sendkey n'; echo 'sendkey ret'; \
	sleep 1; echo 'sendkey p'; echo 'sendkey s'; echo 'sendkey ret'; \
	sleep 6; echo 'sendkey p'; echo 'sendkey s'; echo 'sendkey ret'; \
	sleep 1; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/process.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q "PID4 user READY" build/process.log
	grep -q "PID4 user state=READY" build/process.log
	grep -q "PID4 user state=EXITED" build/process.log
	@echo "OrangeOS user process lifecycle test passed"

test-userfault: orange.img
	mkdir -p build
	rm -f build/userfault.log
	( sleep 1; \
	echo 'sendkey r'; echo 'sendkey u'; echo 'sendkey n'; echo 'sendkey f'; \
	echo 'sendkey a'; echo 'sendkey u'; echo 'sendkey l'; echo 'sendkey t'; \
	echo 'sendkey ret'; sleep 2; \
	echo 'sendkey p'; echo 'sendkey s'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey s'; echo 'sendkey e'; echo 'sendkey l'; echo 'sendkey f'; \
	echo 'sendkey t'; echo 'sendkey e'; echo 'sendkey s'; echo 'sendkey t'; \
	echo 'sendkey ret'; sleep 2; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/userfault.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q "state=FAULTED" build/userfault.log
	grep -q "fault=0x50000000" build/userfault.log
	grep -q "SELFTEST PASS:" build/userfault.log
	@echo "OrangeOS user page-fault isolation test passed"

test-resources: orange.img
	mkdir -p build
	rm -f build/resources.log
	( sleep 1; \
	echo 'sendkey m'; echo 'sendkey e'; echo 'sendkey m'; echo 'sendkey m'; \
	echo 'sendkey a'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey r'; echo 'sendkey u'; echo 'sendkey n'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey m'; echo 'sendkey e'; echo 'sendkey m'; echo 'sendkey m'; \
	echo 'sendkey a'; echo 'sendkey p'; echo 'sendkey ret'; sleep 6; \
	echo 'sendkey m'; echo 'sendkey e'; echo 'sendkey m'; echo 'sendkey m'; \
	echo 'sendkey a'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/resources.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	set -- $$(grep -o 'used=[0-9]*' build/resources.log | cut -d= -f2); \
	test "$$1" = "$$3"; test "$$2" -eq $$(( $$1 + 3 ))
	@echo "OrangeOS user page resource reclamation test passed"

test-exec: orange.img
	mkdir -p build
	rm -f build/exec.log
	( sleep 1; echo 'sendkey l'; echo 'sendkey s'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey e'; echo 'sendkey x'; echo 'sendkey e'; echo 'sendkey c'; \
	echo 'sendkey spc'; echo 'sendkey d'; echo 'sendkey e'; echo 'sendkey m'; \
	echo 'sendkey o'; echo 'sendkey dot'; echo 'sendkey o'; echo 'sendkey e'; \
	echo 'sendkey x'; echo 'sendkey ret'; sleep 2; \
	echo 'sendkey p'; echo 'sendkey s'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey e'; echo 'sendkey x'; echo 'sendkey e'; echo 'sendkey c'; \
	echo 'sendkey spc'; echo 'sendkey b'; echo 'sendkey a'; echo 'sendkey d'; \
	echo 'sendkey dot'; echo 'sendkey o'; echo 'sendkey e'; echo 'sendkey x'; \
	echo 'sendkey ret'; sleep 1; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/exec.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q "demo.oex" build/exec.log
	grep -q "PID4 user state=EXITED" build/exec.log
	grep -q "code=42" build/exec.log
	grep -q "Invalid OEX2 executable" build/exec.log
	@echo "OrangeOS OrangeFS executable loading test passed"

test-fs-large: orange.img
	mkdir -p build
	rm -f build/fs-large.log
	( sleep 1; \
	echo 'sendkey s'; echo 'sendkey t'; echo 'sendkey a'; echo 'sendkey t'; \
	echo 'sendkey spc'; echo 'sendkey b'; echo 'sendkey i'; echo 'sendkey g'; \
	echo 'sendkey dot'; echo 'sendkey t'; echo 'sendkey x'; echo 'sendkey t'; \
	echo 'sendkey ret'; sleep 1; \
	echo 'sendkey s'; echo 'sendkey e'; echo 'sendkey l'; echo 'sendkey f'; \
	echo 'sendkey t'; echo 'sendkey e'; echo 'sendkey s'; echo 'sendkey t'; \
	echo 'sendkey ret'; sleep 2; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none \
	-serial none -no-reboot -debugcon file:build/fs-large.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q "size=700 bytes start=48 sectors=2" build/fs-large.log
	grep -q "SELFTEST PASS:" build/fs-large.log
	@echo "OrangeOS multi-sector filesystem test passed"

test-fs-bitmap: orange.img
	mkdir -p build
	rm -f build/fs-bitmap.log
	( sleep 1; echo 'sendkey d'; echo 'sendkey i'; echo 'sendkey s'; echo 'sendkey k'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey t'; echo 'sendkey o'; echo 'sendkey u'; echo 'sendkey c'; echo 'sendkey h'; echo 'sendkey spc'; echo 'sendkey t'; echo 'sendkey m'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey d'; echo 'sendkey i'; echo 'sendkey s'; echo 'sendkey k'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey w'; echo 'sendkey r'; echo 'sendkey i'; echo 'sendkey t'; echo 'sendkey e'; echo 'sendkey spc'; echo 'sendkey t'; echo 'sendkey m'; echo 'sendkey p'; echo 'sendkey spc'; echo 'sendkey h'; echo 'sendkey i'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey d'; echo 'sendkey i'; echo 'sendkey s'; echo 'sendkey k'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey r'; echo 'sendkey m'; echo 'sendkey spc'; echo 'sendkey t'; echo 'sendkey m'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey d'; echo 'sendkey i'; echo 'sendkey s'; echo 'sendkey k'; echo 'sendkey ret'; sleep 1; echo quit ) | \
	$(QEMU) -drive format=raw,file=orange.img -snapshot -display none -serial none -no-reboot \
	-debugcon file:build/fs-bitmap.log -global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	test $$(grep -o 'free=25/32' build/fs-bitmap.log | wc -l) -eq 3
	grep -q 'free=24/32' build/fs-bitmap.log
	@echo "OrangeOS filesystem bitmap allocation test passed"

test-fs-checksum: orange.img
	mkdir -p build
	rm -f build/fs-checksum.img build/fs-checksum.log
	cp orange.img build/fs-checksum.img
	( sleep 1; echo 'sendkey t'; echo 'sendkey o'; echo 'sendkey u'; echo 'sendkey c'; echo 'sendkey h'; \
	echo 'sendkey spc'; echo 'sendkey k'; echo 'sendkey e'; echo 'sendkey e'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey w'; echo 'sendkey r'; echo 'sendkey i'; echo 'sendkey t'; echo 'sendkey e'; echo 'sendkey spc'; \
	echo 'sendkey k'; echo 'sendkey e'; echo 'sendkey e'; echo 'sendkey p'; echo 'sendkey spc'; \
	echo 'sendkey s'; echo 'sendkey u'; echo 'sendkey r'; echo 'sendkey v'; echo 'sendkey i'; echo 'sendkey v'; \
	echo 'sendkey e'; echo 'sendkey s'; echo 'sendkey ret'; sleep 2; echo quit ) | \
	$(QEMU) -drive format=raw,file=build/fs-checksum.img -display none -serial none -no-reboot \
	-debugcon file:build/fs-checksum-format.log -global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	printf '\377' | dd of=build/fs-checksum.img bs=1 seek=$$((42*512+4)) conv=notrunc status=none
	( sleep 1; echo 'sendkey c'; echo 'sendkey a'; echo 'sendkey t'; echo 'sendkey spc'; \
	echo 'sendkey k'; echo 'sendkey e'; echo 'sendkey e'; echo 'sendkey p'; echo 'sendkey ret'; sleep 1; \
	echo 'sendkey d'; echo 'sendkey i'; echo 'sendkey s'; echo 'sendkey k'; echo 'sendkey ret'; sleep 2; echo quit ) | \
	$(QEMU) -drive format=raw,file=build/fs-checksum.img -snapshot -display none -serial none -no-reboot \
	-debugcon file:build/fs-checksum.log -global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q 'survives' build/fs-checksum.log
	grep -q 'OrangeFS free=24/32 sectors' build/fs-checksum.log
	@echo "OrangeOS backup directory recovery test passed"

test-fs-data-checksum: orange.img
	mkdir -p build
	rm -f build/fs-data.img build/fs-data.log
	cp orange.img build/fs-data.img
	timeout 3s $(QEMU) -drive format=raw,file=build/fs-data.img -display none -monitor none \
	-serial none -no-reboot -debugcon file:build/fs-data-format.log \
	-global isa-debugcon.iobase=0xe9 || [ $$? -eq 124 ]
	printf 'X' | dd of=build/fs-data.img bs=1 seek=$$((43*512)) conv=notrunc status=none
	( sleep 1; echo 'sendkey c'; echo 'sendkey a'; echo 'sendkey t'; echo 'sendkey spc'; \
	echo 'sendkey h'; echo 'sendkey e'; echo 'sendkey l'; echo 'sendkey l'; echo 'sendkey o'; \
	echo 'sendkey dot'; echo 'sendkey t'; echo 'sendkey x'; echo 'sendkey t'; echo 'sendkey ret'; \
	sleep 2; echo quit ) | $(QEMU) -drive format=raw,file=build/fs-data.img -snapshot \
	-display none -serial none -no-reboot -debugcon file:build/fs-data.log \
	-global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
	grep -q 'File data corrupt' build/fs-data.log
	@echo "OrangeOS file data checksum test passed"


clean:
	rm -f \
	boot/*.bin \
	loader/*.bin \
	kernel/*.o \
	kernel/kernel.bin \
	orange.img \
	build/debugcon.log \
	build/ring3.log \
	build/process.log \
	build/userfault.log \
	build/resources.log \
	build/exec.log \
	build/fs-large.log \
	build/fs-bitmap.log \
	build/fs-checksum.img \
	build/fs-checksum.log \
	build/fs-checksum-format.log \
	build/fs-data.img \
	build/fs-data.log \
	build/fs-data-format.log
