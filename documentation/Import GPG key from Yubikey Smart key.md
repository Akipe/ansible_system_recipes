Import GPG key from Yubikey/smart key
===========

You need to have a working Yubikey or Smart key, with gpg key already create and configure.

```
# Plug the key and check it
gpg --card-status

# Create keyid var, you can find it at the end, after "sec#"
export KEYID=0x2EA09EF308096DAF

# Now import the public key
# from internet
gpg --recv $KEYID
# or from a file
gpg --import /path/to/public_key_file

# Set the key as utlimate trust
gpg --edit-key $KEYID
> trust
> 5
> quit

# Replug the key and check
gpg --card-status
```
