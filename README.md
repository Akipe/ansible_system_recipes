Readme
====================

Carefull, this contains errors. Work in progress.

# Initialize
```
make init
```

# Basic commande
```
make run NODE=nameNode
make run-init NODE=nameNode
make run-local NODE=nameNode
make run-direct ADDRESS=192.168.0.1 PLAYBOOK=playbookName # For devices not in inventory
make run-debug NODE=nameNode
make run-check NODE=nameNode
make get-info-direct ADDRESS=192.168.0.1 # For devices not in inventory
```

# Generate encrypt var
```
make vault-create
make vault-create NODE=nameNode
make vault-edit
make vault-edit NODE=nameNode

ansible-vault encrypt_string --name 'variable_name'
```

# Generate password hash (for Linux)
```
python -c "from passlib.hash import sha512_crypt; import getpass; print(sha512_crypt.using(rounds=5000).hash(getpass.getpass()))"
```

License
====================

This project is licensed under the terms of the MIT license.