; OrangeOS ATA PIO driver (primary master, LBA28)
[BITS 32]

global ata_read_sector32
global ata_write_sector32

ATA_DATA       equ 0x1F0
ATA_SECTOR_CNT equ 0x1F2
ATA_LBA_LOW    equ 0x1F3
ATA_LBA_MID    equ 0x1F4
ATA_LBA_HIGH   equ 0x1F5
ATA_DRIVE      equ 0x1F6
ATA_STATUS     equ 0x1F7
ATA_COMMAND    equ 0x1F7

; EAX=LBA, EDI=512-byte destination.
ata_read_sector32:
    pushad
    pushfd
    cli
    mov ebx,eax
    call ata_select_lba32
    mov dx,ATA_COMMAND
    mov al,0x20
    out dx,al
    call ata_wait_drq32
    mov dx,ATA_DATA
    mov ecx,256
    cld
    rep insw
    popfd
    popad
    ret

; EAX=LBA, ESI=512-byte source.
ata_write_sector32:
    pushad
    pushfd
    cli
    mov ebx,eax
    call ata_select_lba32
    mov dx,ATA_COMMAND
    mov al,0x30
    out dx,al
    call ata_wait_drq32
    mov dx,ATA_DATA
    mov ecx,256
    cld
    rep outsw
    mov dx,ATA_COMMAND
    mov al,0xE7
    out dx,al
    call ata_wait_not_busy32
    popfd
    popad
    ret

; Program one-sector LBA28 transfer from EBX.
ata_select_lba32:
    mov dx,ATA_SECTOR_CNT
    mov al,1
    out dx,al
    mov dx,ATA_LBA_LOW
    mov eax,ebx
    out dx,al
    mov dx,ATA_LBA_MID
    shr eax,8
    out dx,al
    mov dx,ATA_LBA_HIGH
    shr eax,8
    out dx,al
    mov dx,ATA_DRIVE
    shr eax,8
    and al,0x0F
    or al,0xE0
    out dx,al
    ret

ata_wait_not_busy32:
    push ecx
    mov ecx,1000000
    mov dx,ATA_STATUS
.busy:
    in al,dx
    test al,0x80
    jz .ready
    loop .busy
.ready:
    pop ecx
    ret

ata_wait_drq32:
    push ecx
    mov ecx,1000000
    mov dx,ATA_STATUS
.wait:
    in al,dx
    test al,0x80
    jnz .again
    test al,0x08
    jnz .ready
.again:
    loop .wait
.ready:
    pop ecx
    ret
