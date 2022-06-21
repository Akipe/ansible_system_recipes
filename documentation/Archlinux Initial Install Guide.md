Installation guide
========================

# Readme
I use this commands to initialize my computers with Archlinux.
For complete the installation I use later my Ansible recipes.
Normaly you can copy/past the comands show below.

ATTENTION: Always check before execute !!!

# Installation

## Prepare archlinux installer
Download Archlinux iso here : https://www.archlinux.org/download/

And next boot to it on the computer.

## Configure installer for SSH
This step are falcultative, but prefered. It will enable connection with SSH to copy paste commands. 

### Change keyboard language
```
loadkeys fr
```

### Connect to Wifi

```
iwctl # Then use tab for command helper

# For use WiFi Simple Configuration
wsc list # For listing wifi devices
wsc $DEVICE push-button # For using WIFI WPS
wsc $DEVICE scan
wsc $DEVICE get-networks # List SSID
wsc $DEVICE connect $SSID

# For classic WiFi
station list
station $DEVICE scan
station $DEVICE show
station $DEVICE connect "$SSID"

quit
```

### Enable SSH server
```
passwd root
systemctl start sshd
ip addr show # Get ip for ssh connect
```

### Connect to the computer
```
ssh root@IP_COMPUTER
```

### (not needed) Set terminal config
```
export TERM=xterm-256color
export TERM=xterm
```

## On computer

### Fetch date/time
```
timedatectl set-ntp true
```

### Edit Pacman mirror list
```
export COUNTRY=France && \
pacman --needed --noconfirm -Syy \
        reflector && \
    reflector \
        --country $COUNTRY \
        --age 12 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist
```

### Increase entropy
- Verify if entropy is bigger than 2000
```
sudo pacman --needed --noconfirm -S \
        rng-tools \
        tpm2-tools \
        tpm2-abrmd && \
    systemctl start rngd.service
```

```
cat /sys/devices/virtual/misc/hw_random/rng_available && \
    cat /proc/sys/kernel/random/entropy_avail
```

Disk preparation
========


## Get disk info
```
lsblk
```


## IMPORTANT: Define var

### Set disk var

#### Raid 0 disk
```
export PATH_DISK_1=/dev/nvme0n1 && \
    export PATH_DISK_2=/dev/nvme0n2
# Or
export PATH_DISK_1=/dev/sda && \
    export PATH_DISK_2=/dev/sdb
```

#### Simple disk
```
if [ -f /sys/block/nvme0n1/size ] ; then
    export PATH_DISK=/dev/nvme0n1
    export PATH_PARTITION_EFI="${PATH_DISK}p1"
    export PATH_PARTITION_BOOT="${PATH_DISK}p2"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}p3"
elif  [ -f /sys/block/vda/size ] ; then
    export PATH_DISK=/dev/vda
    export PATH_PARTITION_EFI="${PATH_DISK}1"
    export PATH_PARTITION_BOOT="${PATH_DISK}2"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}3"
else
    export PATH_DISK=/dev/sda
    export PATH_PARTITION_EFI="${PATH_DISK}1"
    export PATH_PARTITION_BOOT="${PATH_DISK}2"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}3"
fi

echo "PATH_DISK: ${PATH_DISK}" && \
    echo "PATH_PARTITION_EFI: ${PATH_PARTITION_EFI}" && \
    echo "PATH_PARTITION_BOOT: ${PATH_PARTITION_BOOT}" && \
    echo "PATH_PARTITION_SYSENCRYPT: ${PATH_PARTITION_SYSENCRYPT}"
```

### Set partitions var
Define auto encryption size for SSD, left 10% free space for provising, & for swap need x1.5 RAM size for suspend.

```
# To add more space for example to suspend with NVIDIA card
# Check VRAM size
nvidia-smi -q -d MEMORY
# (sum of the memory capacities of all NVIDIA GPUs) * 1.02
# Or 0
export SWAP_SIZE_ADD=_______
```

#### Raid 0
```
export SWAP_PARTITION_SIZE_FLOAT=$(($(free|awk '/^Mem:/{print $2}')/1024/1024*1.5)) && \
    export SWAP_PARTITION_SIZE=$(expr $(echo $SWAP_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export SWAP_PARTITION_SIZE=$((SWAP_PARTITION_SIZE + SWAP_SIZE_ADD)) && \
    export DISK_SIZE_1=${$(($(blockdev --getsize64 $PATH_DISK_1)/1024/1024/1024))} && \
    export SYSTEM_PARTITION_SIZE_FLOAT=${$(($DISK_SIZE_1*0.9-$SWAP_PARTITION_SIZE))%.*} && \
    export SYSTEM_PARTITION_SIZE=$(expr $(echo $SYSTEM_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export SYSTEM_PARTITION_SIZE=$((SYSTEM_PARTITION_SIZE - SWAP_PARTITION_SIZE)) && \
    echo "$PATH_DISK_1 (disk) size: ${DISK_SIZE_1}G" && \
    echo "$PATH_DISK_2 (disk) size: ${DISK_SIZE_1}G" && \
    echo "Total size raid : $((DISK_SIZE_1*2))G" && \
    echo "SWAP file size: ${SWAP_PARTITION_SIZE}G" && \
    echo "$PATH_PARTITION_SYSENCRYPT (system) size: ${SYSTEM_PARTITION_SIZE}G"
```

#### Simple disk

```
export SWAP_PARTITION_SIZE_FLOAT=$(($(free|awk '/^Mem:/{print $2}')/1024/1024*1.5)) && \
    export SWAP_PARTITION_SIZE=$(expr $(echo $SWAP_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export SWAP_PARTITION_SIZE=$((SWAP_PARTITION_SIZE + SWAP_SIZE_ADD)) && \
    export DISK_SIZE=${$(($(blockdev --getsize64 $PATH_DISK)/1024/1024/1024))} && \
    export SYSTEM_PARTITION_SIZE_FLOAT=${$(($DISK_SIZE*0.9-$SWAP_PARTITION_SIZE))%.*} && \
    export SYSTEM_PARTITION_SIZE=$(expr $(echo $SYSTEM_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export SYSTEM_PARTITION_SIZE=$((SYSTEM_PARTITION_SIZE - SWAP_PARTITION_SIZE)) && \
    echo "$PATH_DISK (disk) size: ${DISK_SIZE}G" && \
    echo "SWAP file size: ${SWAP_PARTITION_SIZE}G" && \
    echo "$PATH_PARTITION_SYSENCRYPT (system) size: ${SYSTEM_PARTITION_SIZE}G"
```


## Format disk 

### SSD
Trim disk for better durability. it vill remove all data !

#### Raid

```
blkdiscard $PATH_DISK_1 -f
blkdiscard $PATH_DISK_2 -f
```

#### Simple disk
```
blkdiscard $PATH_DISK
```

### EFI

#### Raid 0
```
sgdisk --zap-all $PATH_DISK_1 && \
    sgdisk --clear \
        --new=1:0:+550M --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:+${SWAP_PARTITION_SIZE}G --typecode=2:8200 --change-name=2:akpsystem-swap-1-encrypt \
        --new=3:0:+${SYSTEM_PARTITION_SIZE}G --typecode=3:8300 --change-name=3:akpsystem-sys-raid0-1-encrypt \
        $PATH_DISK_1 && \
    sgdisk -p $PATH_DISK_1 && \
    sgdisk -v $PATH_DISK_1 && \
    sgdisk --zap-all $PATH_DISK_2 && \
    sgdisk --clear \
        --new=1:0:+${SWAP_PARTITION_SIZE}G --typecode=1:8200 --change-name=1:akpsystem-swap-2-encrypt \
        --new=2:0:+${SYSTEM_PARTITION_SIZE}G --typecode=2:8300 --change-name=2:akpsystem-sys-raid0-2-encrypt \
        $PATH_DISK_2 && \
    sgdisk -p $PATH_DISK_2 && \
    sgdisk -v $PATH_DISK_2 && \
    lsblk
```

#### One disk
```
sgdisk --zap-all $PATH_DISK && \
    sgdisk --clear \
        --new=1:0:+550M --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:+${SWAP_PARTITION_SIZE}G --typecode=2:8200 --change-name=2:akpsystem-swap-encrypt \
        --new=3:0:+${SYSTEM_PARTITION_SIZE}G --typecode=3:8300 --change-name=3:akpsystem-sys-encrypt \
        $PATH_DISK && \
    sgdisk -p $PATH_DISK && \
    sgdisk -v $PATH_DISK && \
    lsblk
```

### BIOS (MBR)
```
sfdisk $PATH_DISK << EOF
,1024M,L
,${SYSTEM_PARTITION_SIZE}G,L
EOF
 && lsblk
```

## Create boot partition

### EFI
```
mkfs.vfat -F32 -n "EFI" /dev/disk/by-partlabel/EFI
```

### BIOS (MBR)
```
mkfs.ext4 -L akpsystem-boot ${PATH_DISK}1
```

## Encrypt root partition

Test performance
```
cryptsetup benchmark 
```

For 4k sectors : `--align-payload=8192`  
--key-size 512 is equal to 256 for XTS


### Raid 0 with SSD

```
# Use the same password for encryption
cryptsetup \
        --type luks2 \
        --perf-no_read_workqueue \
        --perf-no_write_workqueue \
        --use-random \
        --iter-time 5000 \
        --cipher aes-xts-plain64 \
        --key-size 256 \
        --label akpsystem-sys-raid0-1-encrypt \
        luksFormat \
        /dev/disk/by-partlabel/akpsystem-sys-raid0-1-encrypt && \
    cryptsetup \
            --type luks2 \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --use-random \
            --iter-time 5000 \
            --cipher aes-xts-plain64 \
            --key-size 256 \
            --label akpsystem-sys-raid0-2-encrypt \
            luksFormat \
            /dev/disk/by-partlabel/akpsystem-sys-raid0-2-encrypt && \
    cryptsetup \
            --type luks2 \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --use-random \
            --iter-time 5000 \
            --cipher aes-xts-plain64 \
            --key-size 256 \
            --label akpsystem-swap-1-encrypt \
            luksFormat \
            /dev/disk/by-partlabel/akpsystem-swap-1-encrypt && \
    cryptsetup \
            --type luks2 \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --use-random \
            --iter-time 5000 \
            --cipher aes-xts-plain64 \
            --key-size 256 \
            --label akpsystem-swap-2-encrypt \
            luksFormat \
            /dev/disk/by-partlabel/akpsystem-swap-2-encrypt

cryptsetup luksOpen \
        --allow-discards \
        --perf-no_read_workqueue \
        --perf-no_write_workqueue \
        --allow-discards \
        --persistent \
        /dev/disk/by-partlabel/akpsystem-sys-raid0-1-encrypt \
        akpsystem-sys-raid0-1 && \
    cryptsetup luksOpen \
            --allow-discards \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --allow-discards \
            --persistent \
            /dev/disk/by-partlabel/akpsystem-sys-raid0-2-encrypt \
            akpsystem-sys-raid0-2 && \
    cryptsetup luksOpen \
            --allow-discards \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --allow-discards \
            --persistent \
            /dev/disk/by-partlabel/akpsystem-swap-1-encrypt \
            akpsystem-swap-1 && \
    cryptsetup luksOpen \
            --allow-discards \
            --perf-no_read_workqueue \
            --perf-no_write_workqueue \
            --allow-discards \
            --persistent \
            /dev/disk/by-partlabel/akpsystem-swap-2-encrypt \
            akpsystem-swap-2
```

### Simple disk
```
# SSD
cryptsetup \
    --type luks2 \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --allow-discards \
    --use-random \
    --iter-time 5000 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --label akpsystem-encrypt \
    luksFormat /dev/disk/by-partlabel/akpsystem-encrypt

# HDD with 4k bytes sectors
cryptsetup \
    --type luks2 \
    --use-random \
    --iter-time 5000 \
    --align-payload=8192 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --label akpsystem-encrypt \
    luksFormat /dev/disk/by-partlabel/akpsystem-encrypt

# HDD or devices with 512 bytes sectors
cryptsetup \
    --type luks2 \
    --use-random \
    --iter-time 5000 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --label akpsystem-encrypt \
    luksFormat /dev/disk/by-partlabel/akpsystem-encrypt

### Open encrypt system
# with SSD
cryptsetup luksOpen \
    --allow-discards \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --persistent \
    /dev/disk/by-partlabel/akpsystem-encrypt akpsystem

# with HDD
cryptsetup luksOpen \
    /dev/disk/by-partlabel/akpsystem-encrypt akpsystem
```

## swap

### Raid 0
mkswap \
        --label akpsystem-swap-1 \
        /dev/mapper/akpsystem-swap-1 && \
    mkswap \
            --label akpsystem-swap-2 \
            /dev/mapper/akpsystem-swap-2 && \
    swapon /dev/mapper/akpsystem-swap-1 && \
    swapon /dev/mapper/akpsystem-swap-2

## System file (btrfs)

### Raid 0
```
mkfs.btrfs \
        --data raid0 \
        --label akpsystem \
        --force \
        /dev/mapper/akpsystem-sys-raid0-1 \
        /dev/mapper/akpsystem-sys-raid0-2 && \
    export btrfs_options=defaults,noatime,compress=zstd,ssd,discard=async && \
    mount \
        -t btrfs \
        -o $btrfs_options \
        LABEL=akpsystem \
        /mnt && \
    btrfs subvolume create /mnt/@root && \
    btrfs subvolume create /mnt/@home && \
    btrfs subvolume create /mnt/@snapshots && \
    umount -R /mnt && \
    mount \
        -t btrfs \
        -o subvol=@root,$btrfs_options \
        LABEL=akpsystem \
        /mnt && \
    mkdir -p /mnt/{boot,home,swap,.snapshots} && \
    mount \
        -t btrfs \
        -o subvol=@home,$btrfs_options \
        LABEL=akpsystem \
        /mnt/home && \
    mount \
        -t btrfs \
        -o subvol=@snapshots,$btrfs_options \
        LABEL=akpsystem \
        /mnt/.snapshots && \
    mount /dev/disk/by-partlabel/EFI /mnt/boot && \
    lsblk
```

Set up Archlinux
========

# Install base system
```
pacstrap /mnt \
        base \
        base-devel \
        linux-zen \
        linux-zen-headers \
        linux-lts \
        linux-lts-headers \
        linux-firmware \
        btrfs-progs \
        zstd \
        fish \
        neovim \
        sudo \
        btrfs-progs \
        git && \
    genfstab -pU /mnt >> /mnt/etc/fstab && \
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
```

# Chroot to Arch
```
arch-chroot /mnt /bin/bash
```

## Configure decryption

### Raid 0
```
echo -e "
akpsystem-sys-raid0-1 LABEL=akpsystem-sys-raid0-1-encrypt none timeout=180,discard,no-read-workqueue,no-write-workqueue
akpsystem-sys-raid0-2 LABEL=akpsystem-sys-raid0-2-encrypt none timeout=180,discard,no-read-workqueue,no-write-workqueue
akpsystem-swap-1 LABEL=akpsystem-swap-1-encrypt none timeout=180,discard,no-read-workqueue,no-write-workqueue
akpsystem-swap-2 LABEL=akpsystem-swap-2-encrypt none timeout=180,discard,no-read-workqueue,no-write-workqueue
" > /etc/crypttab.initramfs && \
    less /etc/crypttab.initramfs && \
    mkinitcpio -P
```

### Simple disk
```
echo -e "
akpsystem LABEL=akpsystem-encrypt none timeout=180,discard,no-read-workqueue,no-write-workqueue
" > /etc/crypttab.initramfs && \
    less /etc/crypttab.initramfs && \
    mkinitcpio -P
```

## Configure date/time
```
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime && \
    hwclock --systohc --utc && \
    timedatectl set-ntp true
```

## Increase entropy
```
sudo pacman --needed --noconfirm -Syy \
        rng-tools \
        rng-tools \
        tpm2-tools \
        tpm2-abrmd && \
    systemctl enable rngd.service
```

## Configure language
```
sed -i 's/#fr_FR.U/fr_FR.U/g' /etc/locale.gen && \
    sed -i 's/#en_US.U/en_US.U/g' /etc/locale.gen && \
    locale-gen
```
```
echo LANG="en_US.UTF-8" > /etc/locale.conf && \
    echo LC_COLLATE="C" >> /etc/locale.conf && \
    export LANG=en_US.UTF-8
```

## Set hostname

**IMPORTANT** define the var:
```
export HOSTNAME=_____

export HOSTNAME=
```

```
hostnamectl set-hostname $HOSTNAME && \
    echo $HOSTNAME > /etc/hostname && \
    echo -e "127.0.0.1        localhost
::1              localhost ip6-localhost ip6-loopback
127.0.1.1        ${HOSTNAME}.localdomain ${HOSTNAME}
ff02::1          ip6-allnodes
ff02::2          ip6-allrouters
" > /etc/hosts && \
    pacman --needed --noconfirm -S inetutils && \
    hostname $HOSTNAME && \
    less /etc/hosts
```

## Configure keyboard
```
loadkeys fr-latin9 && \
    echo "KEYMAP=fr-latin9" > /etc/vconsole.conf
```

# Configure root and user

## Root
```
passwd root
```

## User (akp)
```
groupadd akp && \
    useradd -m -g akp -G users,wheel,storage,power,network -c "Akipe" akp && \
    passwd akp && \
    pacman -S --needed --noconfirm \
        xdg-user-dirs && \
    sudo -u akp xdg-user-dirs-update
```

## Enable sudo for wheel group
```
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/10-grant-group-wheel-sudo
```

# mkinitcpio

```
sed -i 's/BINARIES=()/BINARIES=("btrfs")/' /etc/mkinitcpio.conf && \
sed -i 's/MODULES=()/MODULES=(dm_mod dm_crypt vfat btrfs sha256 sha512)/g' /etc/mkinitcpio.conf && \
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt btrfs filesystems fsck)/g' /etc/mkinitcpio.conf && \
sed -i 's/#COMPRESSION="zstd"/COMPRESSION="zstd"/g' /etc/mkinitcpio.conf && \
less /etc/mkinitcpio.conf && \
mkinitcpio -P
```

# Optimization btrfs
1. Preventing snapshot slowdowns btrfs
2. Enable Scrub for Raid
```
echo 'PRUNENAMES = ".snapshots"' >> /etc/updatedb.conf && \
    systemctl enable btrfs-scrub@-.timer && \
    systemctl enable btrfs-scrub@home.timer && \
    systemctl enable btrfs-scrub@snapshots.timer
```

## CPU microcode
```
if (lscpu | grep -i intel);
then
    pacman --needed --noconfirm -S \
        intel-ucode && \
    export MICROCODE_LOAD_BOOTLOADER='intel-ucode.img';
elif (lscpu | grep -i amd);
then
    pacman --needed --noconfirm -S \
        amd-ucode && \
    export MICROCODE_LOAD_BOOTLOADER='amd-ucode.img';
fi
```

# Bootloader

## refind (EFI)

### Installation
```
pacman -S --needed --noconfirm \
        refind \
        gptfdisk \
        imagemagick \
        python
```

### Configure UEFI

#### For normal UEFI
```
refind-install && \
    sed -i 's/#extra_kernel_version_strings linux-lts,linux/extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux/g' /boot/EFI/refind/refind.conf && \
    less /boot/EFI/refind/refind.conf && \
    echo -e "[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install
" > /etc/pacman.d/hooks/refind.hook  && \
    less /etc/pacman.d/hooks/refind.hook
```

#### For buggie UEFI
```
# /dev/sdXY is the EFI block device
refind-install --alldrivers --usedefault /dev/sdXY && \
    sed -i 's/#extra_kernel_version_strings linux-lts,linux/extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux/g' /boot/EFI/BOOT/refind.conf && \
    less /boot/EFI/BOOT/refind.conf
```

### Configure refind

#### Raid 0
```
echo -e '"Boot with standard options"  "initrd=MICROCODE_LOAD_BOOTLOADER initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root resume=/dev/mapper/akpsystem-swap-1 quiet rw"
"Boot to console"    "initrd=MICROCODE_LOAD_BOOTLOADER initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root resume=/dev/mapper/akpsystem-swap-1 quiet rw systemd.unit=multi-user.target"
"Boot using fallback initramfs"  "initrd=initramfs-%v-fallback.imgs root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root resume=/dev/mapper/akpsystem-swap-1 quiet rw systemd.unit=multi-user.target"
"Boot with minimal options"   "initrd=MICROCODE_LOAD_BOOTLOADER initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root ro"
' > /boot/refind_linux.conf && \
    sed -i 's@MICROCODE_LOAD_BOOTLOADER@'"$MICROCODE_LOAD_BOOTLOADER"'@' /boot/refind_linux.conf && \
    less /boot/refind_linux.conf
```

#### Simple disk (config to recreate)
```
pacman --needed --noconfirm -S refind gptfdisk imagemagick python sbsigntools fd && \
    sudo -u akp yay -S \
        shim-signed && \
    refind-install --shim /usr/share/shim-signed/shimx64.efi --localkeys && \
    sbsign \
        --key /etc/refind.d/keys/refind_local.key \
        --cert /etc/refind.d/keys/refind_local.crt \
        --output /boot/vmlinuz-linux-zen /boot/vmlinuz-linux-zen && \
    sbsign \
        --key /etc/refind.d/keys/refind_local.key \
        --cert /etc/refind.d/keys/refind_local.crt \
        --output /boot/vmlinuz-linux-lts /boot/vmlinuz-linux-lts && \
    echo -e '"Boot with standard options"  "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap-1 quiet rw"
"Boot to console"    "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap-1 quiet rw systemd.unit=multi-user.target"
"Boot using fallback initramfs"  "initrd=initramfs-%v-fallback.imgs root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap-1 quiet rw systemd.unit=multi-user.target"
"Boot with minimal options"   "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-sys-raid0-1 rootflags=subvol=@root ro"
' > /boot/refind_linux.conf && \
    less /boot/refind_linux.conf && \
    sed -i 's/#extra_kernel_version_strings linux-lts,linux/extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux/g' /efi/EFI/refind/refind.conf && \
    less /efi/EFI/refind/refind.conf && \
    echo -e "[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts
Target = linux-hardened
Target = linux-zen

[Action]
Description = Signing kernel with Machine Owner Key for Secure Boot
When = PostTransaction
Exec = /usr/bin/fd vmlinuz /boot -d 1 -x /usr/bin/sbsign --key /etc/refind.d/keys/refind_local.key --cert /etc/refind.d/keys/refind_local.crt --output {} {}
Depends = sbsigntools
Depends = fd
" > /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook && \
    less /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook && \
    echo -e "[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install --shim /usr/share/shim-signed/shimx64.efi --localkeys
" > /etc/pacman.d/hooks/refind.hook  && \
    less /etc/pacman.d/hooks/refind.hook
```

...

## GRUB (BIOS, MBR)
```
pacman --needed --noconfirm -S grub && \
    grub-install --target=i386-pc --recheck ${PATH_DISK} && \
    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="root=\/dev\/mapper\/akpsystem-root rd.luks.options=discard resume=\/dev\/mapper\/akpsystem-swap quiet rw"/g' /etc/default/grub && \
    less /etc/default/grub && \
    grub-mkconfig -o /boot/grub/grub.cfg
```

# Installer

## Pacman
```
pacman --needed --noconfirm -S \
        pacman-contrib \
        pacman-mirrorlist \
        perl-locale-gettext \
        reflector && \
    sed -i 's/#TotalDownload/TotalDownload/g' /etc/pacman.conf && \
    sed -i 's/#Color/Color/g' /etc/pacman.conf && \
    sed -i 's/#\[multilib\]/[multilib]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf && \
    pacman -Syy && \
    mkdir /etc/pacman.d/hooks -p
```

## yay (AUR)
```
cd /tmp && \
    sudo -u akp git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    sudo -u akp makepkg -si && \
    cd ~
```

## Enable OpenSSH server
```
pacman --needed --noconfirm -S \
        openssh && \
    systemctl enable sshd.service && \
    sed -i 's/UsePAM yes/UsePAM yes\nAllowUsers akp/g' /etc/ssh/sshd_config && \
    less /etc/ssh/sshd_config
```

## Set NTP options
```
echo -e "[Time]
NTP=0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org
FallbackNTP=0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
" > /etc/systemd/timesyncd.conf && \
    timedatectl set-ntp true && \
    less /etc/systemd/timesyncd.conf
```

## Network
```
pacman --needed --noconfirm -S \
        networkmanager && \
    systemctl enable NetworkManager.service
```

## Avahi
```
pacman --needed --noconfirm -S \
        avahi \
        nss-mdns && \
    systemctl enable avahi-daemon.service && \
    echo -e "# Name Service Switch configuration file.
# See nsswitch.conf(5) for details.

passwd: files mymachines systemd
group: files mymachines systemd
shadow: files

publickey: files

hosts: files mymachines myhostname mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

netgroup: files" > /etc/nsswitch.conf && \
    less /etc/nsswitch.conf
```

## Install KDE
```
sudo pacman -S --needed \
        plasma-meta \
        kde-system-meta \
        kde-utilities-meta \
        kde-network-meta \
        kde-graphics-meta \
        phonon-qt5-gstreamer \
        plasma-workspace\
        pipewire-jack \
        wireplumber \
        noto-fonts \
        cronie && \
    sudo systemctl enable sddm.service && \
    localectl set-x11-keymap fr
```

#kde-multimedia-meta \
#kde-sdk-meta \
#kde-accessibility-meta \
#kde-pim-meta \


## Install Gnome
```
sudo pacman -S --needed \
        gnome \
        gnome-usage \
        gnome-multi-writer \
        gnome-nettool \
        gnome-sound-recorder \
        gnome-todo \
        gnome-tweaks && \
    sudo systemctl enable gdm.service
```

## Prepare GNUPG, SSH and Yubikey
```
pacman -S --needed \
        git \
        gnupg \
        pcsclite \
        ccid \
        hopenpgp-tools \
        yubikey-personalization \
        libusb-compat && \
    systemctl enable pcscd.service
```

```
su akp

export KEYID=
export KEYID=0x2EA09EF308096DAF
```
```
gpg --recv $KEYID && \
    gpg --edit-key $KEYID
```
```
> trust
> 5
> y
> quit
```

```
echo -e "enable-ssh-support
default-cache-ttl 60
max-cache-ttl 120
pinentry-program /usr/bin/pinentry-qt
" > ~/.gnupg/gpg-agent.conf && \
    echo -e '

export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
' >> ~/.bashrc && \
    mkdir ~/.config/fish && \
    echo -e '

set -x GPG_TTY (tty)
set -x SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
' >> ~/.config/fish/config.fish && \
    less ~/.gnupg/gpg-agent.conf && \
    less ~/.config/fish/config.fish
```
```
export GIT_USER_NAME=
export GIT_USER_EMAIL=

export GIT_USER_NAME="Julien Milletre Akipe" && \
export GIT_USER_EMAIL=code.julien@milletre.fr
```
```
git config --global user.name "$GIT_USER_NAME" && \
    git config --global user.email $GIT_USER_EMAIL
```

**End of installation ! :)**

# Reboot

## Raid 0
```
swapoff /dev/mapper/akpsystem-swap-1 && \
    swapoff /dev/mapper/akpsystem-swap-2 && \
    exit

umount -R /mnt && \
    cryptsetup luksClose /dev/mapper/akpsystem-swap-1 && \
    cryptsetup luksClose /dev/mapper/akpsystem-swap-2 && \
    cryptsetup luksClose /dev/mapper/akpsystem-sys-raid0-1 && \
    cryptsetup luksClose /dev/mapper/akpsystem-sys-raid0-2 && \
    reboot
```

## Simple disk
```
swapoff /swap/swapfile && \
exit

umount -R /mnt && \
    cryptsetup luksClose /dev/mapper/akpsystem && \
    reboot
```

# Post-Install

```
localectl set-x11-keymap fr
```


# Emergency with Arch Live-CD




### Mount the system (to /mnt)
```
cryptsetup luksOpen \
        /dev/disk/by-partlabel/akpsystem-sys-raid0-1-encrypt \
        akpsystem-sys-raid0-1 && \
    cryptsetup luksOpen \
        /dev/disk/by-partlabel/akpsystem-sys-raid0-2-encrypt \
        akpsystem-sys-raid0-2 && \
    export btrfs_options=defaults,noatime,compress=zstd,ssd,discard=async && \
    mount \
        -t btrfs \
        -o subvol=@root,$btrfs_options \
        LABEL=akpsystem \
        /mnt && \
    mount -L EFI /mnt/boot && \
    arch-chroot /mnt /usr/bin/fish
```

### EFI not show
```
efibootmgr \
    --create \
    --disk /dev/sda \
    --part 1 \
    --loader /boot/EFI/refind/refind_x64.efi i \
    --label "rEFInd manual" \
    --verbose

refind-install --usedefault /dev/sdXY 
```

### Connect to wifi
```
nmcli --ask dev(ice) wifi connect WIFI_SSID_NAME
```

### Reboot
```
exit
umount -R /mnt && \
    cryptsetup luksClose /dev/mapper/akpsystem-swap-1 && \
    cryptsetup luksClose /dev/mapper/akpsystem-swap-2 && \
    cryptsetup luksClose /dev/mapper/akpsystem-sys-raid0-1 && \
    cryptsetup luksClose /dev/mapper/akpsystem-sys-raid0-2 && \
    reboot
```







# Old configs

## System file btrfs
```

mkfs.btrfs --label akpsystem --force /dev/mapper/akpsystem && \
    mount /dev/mapper/akpsystem /mnt && \
    btrfs sub create /mnt/@root && \
    btrfs sub create /mnt/@home && \
    #btrfs sub create /mnt/@abs && \
    #btrfs sub create /mnt/@tmp && \
    #btrfs sub create /mnt/@srv && \
    #btrfs sub create /mnt/@log && \
    #btrfs sub create /mnt/@cache && \
    btrfs sub create /mnt/@snapshots && \
    btrfs sub create /mnt/@swap && \
    umount /mnt && \
    mount \
        -o noatime,compress=zstd:1,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@root \
        /dev/mapper/akpsystem /mnt && \
    mkdir -p /mnt/{boot,efi,home,var/cache,var/log,swap,.snapshots,var/tmp,var/abs,srv} && \
    mount \
        -o noatime,compress-force=zstd,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@home \
        /dev/mapper/akpsystem /mnt/home && \
    mount \
        -o nodev,nosuid,noexec,noatime,compress-force=zstd,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@abs \
        /dev/mapper/akpsystem /mnt/var/abs && \
    mount \
        -o noatime,compress=zstd:1,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@tmp \
        /dev/mapper/akpsystem /mnt/var/tmp && \
    mount \
        -o noatime,compress=zstd:1,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@srv \
        /dev/mapper/akpsystem /mnt/srv && \
    mount \
        -o nodev,nosuid,noexec,noatime,compress-force=zstd,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@log \
        /dev/mapper/akpsystem /mnt/var/log && \
    mount \
        -o nodev,nosuid,noexec,noatime,compress-force=zstd,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@cache \
        /dev/mapper/akpsystem /mnt/var/cache && \
    mount \
        -o noatime,compress-force=zstd,commit=120,space_cache=v2,ssd,discard=async,autodefrag,subvol=@snapshots \
        /dev/mapper/akpsystem /mnt/.snapshots && \
    mount \
        -o compress=no,space_cache,ssd,discard=async,subvol=@swap \
        /dev/mapper/akpsystem /mnt/swap && \
    mkdir -p /mnt/var/lib/{docker,machines,mysql,postgres} && \
    chattr +C /mnt/var/lib/{docker,machines,mysql,postgres}

# Create Swapfile
truncate -s 0 /mnt/swap/swapfile && \
    chattr +C /mnt/swap/swapfile && \
    fallocate -l ${SWAP_PARTITION_SIZE}G /mnt/swap/swapfile && \
    chmod 0600 /mnt/swap/swapfile && \
    mkswap --label akpsystem-swap /mnt/swap/swapfile && \
    swapon /mnt/swap/swapfile

dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=${SWAP_PARTITION_SIZE}192


mount /dev/disk/by-partlabel/EFI /mnt/efi && \
    mount /dev/disk/by-partlabel/akpsystem-boot /mnt/boot && \
    lsblk
```

## Set up LVM2
```
# SSD or HDD with 4k bytes sectors
pvcreate --dataalignment 4M /dev/mapper/akpsystem

# HDD or devices with 512 bytes sectors
pvcreate /dev/mapper/akpsystem


vgcreate akpsystem /dev/mapper/akpsystem && \
    lvcreate --size ${SWAP_PARTITION_SIZE}G akpsystem --name swap && \
    lvcreate -l +100%FREE akpsystem --name root && \
    lvdisplay
```

## Set up partions (ext4 and swap)
```
mkfs.ext4 -L akpsysroot /dev/mapper/akpsystem-root && \
    mkswap -L akpsysswap /dev/mapper/akpsystem-swap
```

## Mount system
```
mount /dev/mapper/akpsystem-root /mnt && \
    mkdir /mnt/boot && \
    mount ${PATH_DISK}1 /mnt/boot && \
    swapon /dev/mapper/akpsystem-swap && \
    lsblk
```

## Setup Archlinux

```
pacstrap /mnt \
        base \
        base-devel \
        linux-zen \
        linux-zen-headers \
        linux-lts \
        linux-lts-headers \
        linux-firmware \
        lvm2 \
        fish \
        neovim \
        sudo \
        git && \
    genfstab -pU /mnt >> /mnt/etc/fstab && \
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
```


### Configure hibernate to swap file
https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file_on_Btrfs

```
cd /tmp/ && \
    curl -LJO https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c && \
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c && \
    rm btrfs_map_physical.c && \
    mv btrfs_map_physical /usr/local/bin && \
    export RESUME_OFFSET=$(("$(btrfs_map_physical /swap/swapfile | head -n2 | tail -n1 | awk '{print $6}') / $(getconf PAGESIZE) "))
```

## systemd-boot (EFI)

```
bootctl --path=/boot install && \
echo -e "default akpos-zen.conf
timeout 5
console-mode max
editor 1
auto-firmware 1
auto-entries 1
" > /boot/loader/loader.conf && \
echo -e "title AkpOS (zen-kernel)
linux /vmlinuz-linux-zen
#MICROCODE_LINE
initrd /initramfs-linux-zen.img
options root=/dev/mapper/akpsystem-root rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/akpsystem resume_offset=$SWAP_FILE_OFFSET quiet rw
" > /boot/loader/entries/akpos-zen.conf && \
echo -e "title AkpOS (linux-lts)
linux /vmlinuz-linux-lts
#MICROCODE_LINE
initrd /initramfs-linux-lts.img
options root=/dev/mapper/akpsystem rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/akpsystem resume_offset=$SWAP_FILE_OFFSET quiet rw
" > /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/loader.conf && \
    less /boot/loader/entries/akpos-zen.conf && \
    less /boot/loader/entries/akpos-lts.conf
```


## ZRAM
```
pacman --needed --noconfirm -S \
        zram-generator && \
    echo -e "[zram0]
host-memory-limit = none
max-zram-size = none
zram-fraction = 0.5
" > /etc/systemd/zram-generator.conf
```

## Emergency Mount the system (to /mnt)
```
cryptsetup luksOpen /dev/disk/by-label/akpsystem-encrypt akpsystem

mount /dev/mapper/akpsystem-root /mnt

mount -L EFI /mnt/boot

arch-chroot /mnt /usr/bin/fish
```
