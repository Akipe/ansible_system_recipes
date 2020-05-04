


# ## Share theme KDE/GTK
# ```
# yay --needed -S qgnomeplatform && \
#  flatpak install flathub org.kde.KStyle.Adwaita && \
#  echo -e "[Qt]
# style=GTK+
# " > ~/.config/Trolltech.conf

# sudo -s

# pacman -S --needed gnome-themes-extra qt5-styleplugins && \
#  echo -e "QT_QPA_PLATFORMTHEME=gtk2" >> /etc/environment && \
#  less /etc/environment && \
#  echo -e "QT_QPA_PLATFORMTHEME=gtk2" >> /etc/profile && \
#  less /etc/profile && \
#  exit
# ```



# ## Prepare AkpGPG Key
# ```
# export KEYID=0x2EA09EF308096DAF && \
#     gpg --recv $KEYID && \
#     gpg --edit-key $KEYID && \
#     gpg --card-status
# ```




# python-pynvim   pkgfile screenfetch

# git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm



# ## Sophos antivirus
# > Manuel : https://www.sophos.com/fr-fr/medialibrary/PDFs/documentation/savl_9_sgeng.pdf

# > Download bin with browser : https://secure2.sophos.com/fr-fr/products/free-tools/sophos-antivirus-for-linux/download.aspx
# ```
# cd /tmp && \
#     tar xzf ~/Téléchargements/sav-linux-free-9.tgz && \
#     sudo /tmp/sophos-av/install.sh && \
#     rm ~/Téléchargements/sav-linux-free-9.tgz && \
#     sudo /opt/sophos-av/bin/savdstatus && \
#     sudo /opt/sophos-av/bin/savdctl enableOnBoot savd && \
#     sudo /opt/sophos-av/bin/savdctl enable
# ```




# yay -S linux-apfs-dkms-git apfsprogs-git apfs-fuse-git zfs-dkms zfs-utils



# ## Firefox config
# ```
# layers.acceleration.force-enabled
# gfx.webrender.all
# gfx.canvas.azure.accelerated
# extensions.pocket.enabled
# ```




    # https://wiki.archlinux.org/index.php/S.M.A.R.T

    # https://wiki.archlinux.org/index.php/Simple_stateful_firewall
    
    
    # https://wiki.archlinux.org/index.php/Blu-ray
    # https://wiki.archlinux.org/index.php/Optical_disc_drive
    # https://wiki.archlinux.org/index.php/Rip_Audio_CDs




logrotate


# conky http://conky.sourceforge.net/variables.html
# keybase
# Powerline
# fish
# neovim
# tmux
# Share theme KDE/GTK
# https://wiki.archlinux.org/index.php/Browser_plugins#MozPlugger
# https://wiki.archlinux.org/index.php/Security#Automatic_logout
# S.M.A.R.T. https://wiki.archlinux.org/index.php/S.M.A.R.T.
# firefox : how to define user config
# spotify flatpak
# qownnote flatpak
# discord flatpak
# skype flatpak

# https://www.shotcut.org/
# http://fixounet.free.fr/avidemux/
# https://www.mixxx.org/download/
# https://github.com/musescore/MuseScore
# https://www.synfig.org/

# base-dev-cli
# base-dev-gui
# dev-php
# antivirus

## Proxmox

### SMART disk
- https://pve.proxmox.com/wiki/Disk_Health_Email_Alerts
- https://jeedom-facile.fr/index.php/2018/12/05/surveillance-du-disque-dur-sous-proxmox/


> git submodules :
```
git push origin HEAD:master
```