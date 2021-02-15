FreeBSD Jail for Syncthing
=============


## How to chroot from host

```
jexec JAIL_ID sh
```

## Configure users

```
adduser
#    name        syncthing
#    uid         2000
#    other group wheel

passwd root
```

## Enable ssh server

```
echo 'sshd_enable="YES"' >> /etc/rc.conf
service sshd start
```

## Prepare jail for Ansible
```
pkg install python37
```
