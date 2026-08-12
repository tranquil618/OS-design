#!/bin/sh
(
    sleep 12
    i=0
    while [ "$i" -lt 90 ]; do
        echo 'sendkey a'
        i=$((i + 1))
    done
    sleep 2
    echo 'screendump /mnt/d/Oranges/build/wrap.ppm'
    echo 'sendkey ret'
    sleep 1
    i=0
    while [ "$i" -lt 6 ]; do
        echo 'sendkey h'
        echo 'sendkey e'
        echo 'sendkey l'
        echo 'sendkey p'
        echo 'sendkey ret'
        sleep 1
        i=$((i + 1))
    done
    echo 'sendkey pgup'
    sleep 2
    echo 'screendump /mnt/d/Oranges/build/scrollback.ppm'
    sleep 1
    echo quit
) | qemu-system-i386 -drive format=raw,file=orange.img -display none \
    -serial none -no-reboot -debugcon file:build/terminal.log \
    -global isa-debugcon.iobase=0xe9 -monitor stdio >/dev/null
