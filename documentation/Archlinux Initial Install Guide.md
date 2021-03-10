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
pacman --needed --noconfirm -Syy reflector && \
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
sudo pacman --needed --noconfirm -S rng-tools tpm2-tools tpm2-abrmd && \
    systemctl start rngd.service && \
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
```
if [ -f /sys/block/nvme0n1/size ] ; then
    export PATH_DISK=/dev/nvme0n1
    export PATH_PARTITION_BOOT="${PATH_DISK}p1"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}p2"
else
    export PATH_DISK=/dev/sda
    export PATH_PARTITION_BOOT="${PATH_DISK}1"
    export PATH_PARTITION_SYSENCRYPT="${PATH_DISK}2"
fi

echo "PATH_DISK: ${PATH_DISK}" && \
    echo "PATH_PARTITION_BOOT: ${PATH_PARTITION_BOOT}" && \
    echo "PATH_PARTITION_SYSENCRYPT: ${PATH_PARTITION_SYSENCRYPT}"
```

### Set partitions var
Define auto encryption size for SSD, left 10% free space for provising, & for swap need x1.5 RAM size for suspend.
```
export SWAP_PARTITION_SIZE_FLOAT=$(($(free|awk '/^Mem:/{print $2}')/1024/1024*1.5)) && \
    export SWAP_PARTITION_SIZE=$(expr $(echo $SWAP_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    export DISK_SIZE=${$(($(blockdev --getsize64 $PATH_DISK)/1024/1024/1024))} && \
    export SYSTEM_PARTITION_SIZE_FLOAT=${$(($DISK_SIZE*0.9-$SWAP_PARTITION_SIZE))%.*} && \
    export SYSTEM_PARTITION_SIZE=$(expr $(echo $SYSTEM_PARTITION_SIZE_FLOAT |cut -f1 -d\.) + 1) && \
    echo "$PATH_DISK (disk) size: ${DISK_SIZE}G" && \
    echo "SWAP partition size: ${SWAP_PARTITION_SIZE}G" && \
    echo "$PATH_PARTITION_SYSENCRYPT (system) size: ${SYSTEM_PARTITION_SIZE}G"
```


## Format disk 

### EFI
```
sgdisk --zap-all $PATH_DISK && \
    sgdisk --clear \
        --new=1:0:+1G --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:+${SYSTEM_PARTITION_SIZE}G --typecode=2:8300 --change-name=2:akpcryptsystem \
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
mkfs.ext4 -L akpsysboot ${PATH_DISK}1
```

## Encrypt root partition

For SSD : `--align-payload=8192`

```
# SSD or HDD with 4k bytes sectors
cryptsetup \
    --type luks2 \
    --use-random \
    --iter-time 5000 \
    --align-payload=8192 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --label akpcryptsystem \
    luksFormat $PATH_PARTITION_SYSENCRYPT

# HDD or devices with 512 bytes sectors
cryptsetup \
    --type luks2 \
    --use-random \
    --iter-time 5000 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --label akpcryptsystem \
    luksFormat $PATH_PARTITION_SYSENCRYPT

cryptsetup luksOpen --allow-discards $PATH_PARTITION_SYSENCRYPT akpsystem
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
        lvm2 \
        fish \
        neovim \
        sudo \
        git && \
    genfstab -pU /mnt >> /mnt/etc/fstab && \
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
```



# Chroot to Arch
```
arch-chroot /mnt /bin/bash
```

## Configure decryption
```
echo -e "
akpsystem LABEL=akpcryptsystem none timeout=180,discard
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
sudo pacman --needed --noconfirm -Syy rng-tools rng-tools tpm2-tools tpm2-abrmd && \
    systemctl enable rngd.service
```

## Configure language
```
sed -i 's/#fr_FR.U/fr_FR.U/g' /etc/locale.gen && \
    sed -i 's/#en_US.U/en_US.U/g' /etc/locale.gen && \
    locale-gen
```
```
echo LANG="fr_FR.UTF-8" > /etc/locale.conf && \
    echo LC_COLLATE="C" >> /etc/locale.conf && \
    export LANG=fr_FR.UTF-8
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
sed -i 's/MODULES=()/MODULES=(dm_mod dm_crypt ext4 vfat sha256 sha512 crc32c-intel)/g' /etc/mkinitcpio.conf && \
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt lvm2 filesystems fsck)/g' /etc/mkinitcpio.conf && \
sed -i 's/#COMPRESSION="lz4"/COMPRESSION="lz4"/g' /etc/mkinitcpio.conf && \
less /etc/mkinitcpio.conf && \
mkinitcpio -P
```



# Bootloader


## refind (EFI)
```
pacman --needed --noconfirm -S refind gptfdisk imagemagick python && \
    refind-install && \
    echo -e '"Boot with standard options"  "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap quiet rw"
"Boot to console"    "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap quiet rw systemd.unit=multi-user.target"
"Boot using fallback initramfs"  "initrd=initramfs-%v-fallback.imgs root=/dev/mapper/akpsystem-root rd.luks.options=discard resume=/dev/mapper/akpsystem-swap quiet rw systemd.unit=multi-user.target"
"Boot with minimal options"   "initrd=initramfs-%v.img root=/dev/mapper/akpsystem-root ro"
' > /boot/refind_linux.conf && \
    less /boot/refind_linux.conf && \
    sed -i 's/#extra_kernel_version_strings linux-lts,linux/extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux/g' /boot/EFI/refind/refind.conf && \
    less /boot/EFI/refind/refind.conf
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
    pacman -Syy
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
pacman --needed --noconfirm -S openssh && \
    systemctl enable sshd.service && \
    sed -i 's/UsePAM yes/UsePAM yes\nAllowUsers akp/g' /etc/ssh/sshd_config && \
    less /etc/ssh/sshd_config
```

## Set NTP options
```
echo -e "[Time]
NTP=npt.akpnet.lan
FallbackNTP=0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
" > /etc/systemd/timesyncd.conf && \
    timedatectl set-ntp true && \
    less /etc/systemd/timesyncd.conf
```

## CPU microcode
```
if (lscpu | grep -i intel);
then
    pacman --needed --noconfirm -S intel-ucode && \
    export MICROCODE_LINE_EXPRESSION='s/#MICROCODE_LINE/initrd \/intel-ucode.img/g';
elif (lscpu | grep -i amd);
then
    pacman --needed --noconfirm -S amd-ucode && \
    export MICROCODE_LINE_EXPRESSION='s/#MICROCODE_LINE/initrd \/amd-ucode.img/g';
fi && \
    sed -i "${MICROCODE_LINE_EXPRESSION}" /boot/loader/entries/akpos-zen.conf && \
    sed -i "${MICROCODE_LINE_EXPRESSION}" /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/entries/akpos-lts.conf && \
    less /boot/loader/entries/akpos-lts.conf
```

## Network
```
pacman --needed --noconfirm -S networkmanager && \
    systemctl enable NetworkManager.service
```

## Avahi
```
pacman --needed --noconfirm -S avahi nss-mdns && \
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


**End of installation ! :)**

# Reboot
```
exit

swapoff /dev/mapper/akpsystem-swap && \
    umount -R /mnt && \
    reboot
```

## Connect to wifi
```
nmcli --ask dev(ice) wifi connect WIFI_SSID_NAME
```


# Post-Install

## Install KDE
```
sudo pacman -S --needed \
        plasma-meta \
        kde-system-meta \
        kde-pim-meta \
        kde-accessibility-meta \
        kde-utilities-meta \
        kde-network-meta \
        kde-graphics-meta \
        kde-multimedia-meta \
        kde-sdk-meta \
        phonon-qt5-gstreamer \
        plasma-workspace && \
    sudo systemctl enable sddm.service
```


# Emergency with Arch Live-CD

### Mount the system (to /mnt)
```
cryptsetup luksOpen /dev/disk/by-label/akpcryptsystem akpcryptsystem

mount /dev/mapper/akpsystem-root /mnt

mount -L EFI /mnt/boot

arch-chroot /mnt /usr/bin/fish
```

### Reboot
```
exit
umount -R /mnt && \
    reboot
```