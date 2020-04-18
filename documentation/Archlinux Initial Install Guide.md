Archlinux Initial Install Guide
========================

# Readme
I use this commands to initialize my computers with Archlinux.
For complete the installation I use later my Ansible recipes.
Normaly you can copy/past the comands show below.

ATTENTION: Always check before execute !!!

This guide will need/used:
- works only with EFI compputer
- BTRFS
- systemd-boot
- root encrypt (/boot unencrypt)
- swap file with resume

# How To

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
wifi-menu
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

## Set variables
Copy paste to the shell. Don't forget to check values.

1. Variables to set.
```
export HOSTNAME=akpcomputerhostname
export USER_NAME_SHELL=an_username
export USER_NAME_SHOW=Akipe
export LANGUAGE=fr_FR
export TIMEZONE=Europe/Paris
export COUNTRY=France # for pacman mirror
export KEYMAP=fr-latin9
export LABEL_PARTITION_ENCRYPTED=akpcryptsystem
export LABEL_PARTITION_ROOT=akpsystem
```
2. Automatic set variables for use first HDD/SSD disk or NVME.
```
if [ -f /dev/nvme0n1 ] ; then
    export PATH_DISK=/dev/nvme0n1
    export PATH_PARTITION_BOOT="${PATH_DISK}p1"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}p2"
else
    export PATH_DISK=/dev/sda
    export PATH_PARTITION_BOOT="${PATH_DISK}1"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}2"
fi
    echo "Disk path to use: ${PATH_DISK}" && \
    echo "Future boot partition path: ${PATH_PARTITION_BOOT}" && \
    echo "Future system encrypt partition path: ${PATH_PARTITION_SYSENCRYPT}"
```
3. Define automatic partition size.
```
export SWAP_PARTITION_SIZE_FLOAT=$(($(free|awk '/^Mem:/{print $2}')/1024/1024*1.5)) && \
    export SWAP_PARTITION_SIZE=$(expr $(echo $SWAP_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export DISK_SIZE=${$(($(blockdev --getsize64 $PATH_DISK)/1024/1024/1024))} && \
    export SYSTEM_PARTITION_SIZE_FLOAT=${$(($DISK_SIZE*0.9-$SWAP_PARTITION_SIZE))%.*} && \
    export SYSTEM_PARTITION_SIZE=$(expr $(echo $SYSTEM_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    echo "$PATH_DISK (disk) size: ${DISK_SIZE}G" && \
    echo "Swap file size: ${SWAP_PARTITION_SIZE}G" && \
    echo "$PATH_PARTITION_SYSENCRYPT (system) size: ${SYSTEM_PARTITION_SIZE}G"
```
4. Define automatic microcode vars (Intel or AMD).
```
if (lscpu | grep -i intel);
then
    export PACMAN_PACKAGE_CPU_MICROCODE=intel-ucode
    export MICROCODE_LINE_EXPRESSION='s/#MICROCODE_LINE/initrd \/intel-ucode.img/g';
elif (lscpu | grep -i amd);
then
    export PACMAN_PACKAGE_CPU_MICROCODE=amd-ucode
    export MICROCODE_LINE_EXPRESSION='s/#MICROCODE_LINE/initrd \/amd-ucode.img/g';
fi
    echo "Microcode package to install: ${PACMAN_PACKAGE_CPU_MICROCODE}" && \
    echo "Microcode line expression: ${MICROCODE_LINE_EXPRESSION}"
```


## Installation

Copy paste to the shell.

1. Set time & entropy for encryption.
```
timedatectl set-ntp true && \
    pacman --needed --noconfirm -Syy reflector && \
    reflector \
        --country $COUNTRY \
        --age 12 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist && \
    sudo pacman --needed --noconfirm -S rng-tools && \
    systemctl start rngd.service
```

2. Prepare disk & install base system.
```
    cat /proc/sys/kernel/random/entropy_avail | less && \
    sgdisk --zap-all $PATH_DISK && \
    sgdisk --clear \
        --new=1:0:+1G --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:+${SYSTEM_PARTITION_SIZE}G --typecode=2:8300 --change-name=2:${LABEL_PARTITION_ENCRYPTED} \
        $PATH_DISK && \
    sgdisk -p $PATH_DISK && \
    sgdisk -v $PATH_DISK && \
    lsblk | less && \
    mkfs.vfat -F32 -n "EFI" /dev/disk/by-partlabel/EFI && \
    cryptsetup \
        --type luks2 \
        --use-random \
        --iter-time 5000 \
        --align-payload=8192 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        luksFormat /dev/disk/by-partlabel/${LABEL_PARTITION_ENCRYPTED} && \
    cryptsetup luksOpen /dev/disk/by-partlabel/${LABEL_PARTITION_ENCRYPTED} ${LABEL_PARTITION_ROOT} && \
    pacman --needed --noconfirm -S zstd && \
    o_btrfs=defaults,compress=zstd,ssd,noatime && \
    mkfs.btrfs --force --label ${LABEL_PARTITION_ROOT} /dev/mapper/${LABEL_PARTITION_ROOT} && \
    mount -o $o_btrfs -t btrfs LABEL=${LABEL_PARTITION_ROOT} /mnt && \
    btrfs subvolume create /mnt/@root && \
    btrfs subvolume create /mnt/@home && \
    btrfs subvolume create /mnt/@swap && \
    btrfs subvolume create /mnt/@var && \
    btrfs subvolume create /mnt/@snapshots && \
    btrfs subvolume create /mnt/@logs && \
    btrfs subvolume create /mnt/@vm && \
    umount -R /mnt && \
    mount -t btrfs -o $o_btrfs,subvol=@root      LABEL=${LABEL_PARTITION_ROOT} /mnt && \
    mkdir /mnt/{boot,home,swap,var,.snapshots} && \
    mount -t btrfs -o $o_btrfs,subvol=@home      LABEL=${LABEL_PARTITION_ROOT} /mnt/home && \
    mount -t btrfs -o $o_btrfs,subvol=@swap      LABEL=${LABEL_PARTITION_ROOT} /mnt/swap && \
    mount -t btrfs -o $o_btrfs,subvol=@var       LABEL=${LABEL_PARTITION_ROOT} /mnt/var && \
    mount -t btrfs -o $o_btrfs,subvol=@snapshots LABEL=${LABEL_PARTITION_ROOT} /mnt/.snapshots && \
    mkdir /mnt/var/log && \
    mount -t btrfs -o $o_btrfs,subvol=@logs      LABEL=${LABEL_PARTITION_ROOT} /mnt/var/log && \
    mount LABEL=EFI /mnt/boot && \
    lsblk | less && \
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
        git && \
    genfstab -pU /mnt >> /mnt/etc/fstab && \
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist && \
    arch-chroot /mnt /bin/bash
```

3. Chroot inside system, install latest apps and configure system before restart.
```
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    hwclock --systohc --utc && \
    timedatectl set-ntp true && \
    sudo pacman --needed --noconfirm -Syy \
        rng-tools && \
    systemctl enable rngd.service && \
    sed -i 's/#${LANGUAGE}.U/${LANGUAGE}.U/g' /etc/locale.gen && \
    sed -i 's/#en_US.U/en_US.U/g' /etc/locale.gen && \
    locale-gen && \
    echo LANG="${LANGUAGE}.UTF-8" > /etc/locale.conf && \
    echo LC_COLLATE="C" >> /etc/locale.conf && \
    export LANG=${LANGUAGE}.UTF-8 && \
    hostnamectl set-hostname $HOSTNAME && \
    echo $HOSTNAME > /etc/hostname && \
    echo -e "127.0.0.1        localhost
::1              localhost ip6-localhost ip6-loopback
127.0.1.1        ${HOSTNAME}.localdomain ${HOSTNAME}
ff02::1          ip6-allnodes
ff02::2          ip6-allrouters
" > /etc/hosts && \
    pacman --needed --noconfirm -S \
        inetutils && \
    hostname $HOSTNAME && \
    less /etc/hosts && \
    loadkeys $KEYMAP && \
    echo "KEYMAP=${KEYMAP}" \
        > /etc/vconsole.conf && \
    truncate -s 0 /swap/file && \
    chattr +C /swap/file && \
    btrfs property set /swap/file compression none && \
    fallocate -l ${SWAP_PARTITION_SIZE}G /swap/file && \
    chmod 600 /swap/file && \
    mkswap /swap/file && \
    swapon /swap/file && \
    echo -e "/swap/file none swap defaults 0 0

" >> /etc/fstab && \
    less /etc/fstab && \
    pacman --needed --noconfirm -S \
        wget \
        curl && \
    mkdir /tmp/swapfile && \
    cd /tmp/swapfile && \
    wget \
        -O btrfs_map_physical.c \
        https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c && \
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c && \
    export SWAP_FILE_OFFSET=$(($(./btrfs_map_physical /swap/file | awk '{print $9}' | sed -n 2p)/$(getconf PAGESIZE))) && \
    echo "Swap file offset: $SWAP_FILE_OFFSET" && \
    cd ~ && \
    passwd root && \
    chsh -s /bin/fish && \
    groupadd $USER_NAME_SHELL && \
    useradd \
        -m \
        -g $USER_NAME_SHELL \
        -G users,wheel,storage,power,network \
        -s /usr/bin/fish \
        -c $USER_NAME_SHOW \
        $USER_NAME_SHELL && \
    passwd $USER_NAME_SHELL && \
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/10-grant-group-wheel-sudo && \
    sed -i 's/MODULES=()/MODULES=(dm_mod dm_crypt btrfs ext4 sha256 sha512 crc32c-intel vfat)/g' /etc/mkinitcpio.conf && \
    sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/g' /etc/mkinitcpio.conf && \
    sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block keyboard keymap encrypt filesystems resume fsck)/g' /etc/mkinitcpio.conf && \
    sed -i 's/#COMPRESSION="lz4"/COMPRESSION="lz4"/g' /etc/mkinitcpio.conf && \
    mkinitcpio -P && \
    less /etc/mkinitcpio.conf && \
    pacman --needed --noconfirm -S \
        efibootmgr && \
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
options cryptdevice=PARTLABEL=${LABEL_PARTITION_ENCRYPTED}:${LABEL_PARTITION_ROOT}:allow-discards root=/dev/mapper/${LABEL_PARTITION_ROOT} rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/${LABEL_PARTITION_ROOT} resume_offset=$SWAP_FILE_OFFSET quiet rw
" > /boot/loader/entries/akpos-zen.conf && \
    echo -e "title AkpOS (linux-lts)
linux /vmlinuz-linux-lts
#MICROCODE_LINE
initrd /initramfs-linux-lts.img
options cryptdevice=PARTLABEL=${LABEL_PARTITION_ENCRYPTED}:${LABEL_PARTITION_ROOT}:allow-discards root=/dev/mapper/${LABEL_PARTITION_ROOT} rootflags=subvol=@root rd.luks.options=discard resume=/dev/mapper/${LABEL_PARTITION_ROOT} resume_offset=$SWAP_FILE_OFFSET quiet rw
" > /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/loader.conf && \
    less /boot/loader/entries/akpos-zen.conf && \
    less /boot/loader/entries/akpos-lts.conf && \
    pacman --needed --noconfirm -S \
        pacman-contrib \
        pacman-mirrorlist \
        perl-locale-gettext \
        reflector \
        xdelta3  && \
    sed -i 's/#TotalDownload/TotalDownload/g' /etc/pacman.conf && \
    sed -i 's/#Color/Color/g' /etc/pacman.conf && \
    sed -i 's/#\[multilib\]/[multilib]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf && \
    pacman -Syy && \
    cd /tmp && \
    sudo -u $USER_NAME_SHELL git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    sudo -u $USER_NAME_SHELL makepkg -si && \
    cd ~ && \
    pacman --needed --noconfirm -S \
        openssh && \
    systemctl enable sshd.service && \
    sed -i 's/UsePAM yes/UsePAM yes\nAllowGroups wheel/g' /etc/ssh/sshd_config && \
    less /etc/ssh/sshd_config && \
    echo -e "[Time]
NTP=192.168.100.1
FallbackNTP=0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
" > /etc/systemd/timesyncd.conf && \
    timedatectl set-ntp true && \
    less /etc/systemd/timesyncd.conf && \
    pacman --needed --noconfirm -S \
        $PACMAN_PACKAGE_CPU_MICROCODE && \
    sed -i "${MICROCODE_LINE_EXPRESSION}" /boot/loader/entries/akpos-zen.conf && \
    sed -i "${MICROCODE_LINE_EXPRESSION}" /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/entries/akpos-lts.conf && \
    pacman --needed --noconfirm -S \
        networkmanager && \
    systemctl enable NetworkManager.service && \
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
    less /etc/nsswitch.conf && \
    exit
```

## Restart the computer 
```
swapoff /mnt/swap/file && \
    umount -R /mnt && \
    reboot
```

## Connect to internet with wifi on the new system
```
nmcli --ask dev wifi connect my_personal_wifi_SSID
```

## End of basic installation (and next)
Et voilà ! Your arch system is install.
Now you have to use Ansible playbook for complete you system.

## Todo
- Need check & review
- Add comments to the copy past commands
- Create script for automatic install
