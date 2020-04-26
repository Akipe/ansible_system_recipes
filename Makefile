.PHONY: init run run-password run-debug run-check clean get-info update-submodules 

fetch_git_submodules:
	git submodule update --init --recursive

update_git_submodules:
	git submodule update --remote --merge

prepare_vault_password_file:
	cp .vault_password.dist .vault_password

run:
	ansible-playbook $(NODE).yml

run-init:
	ansible-playbook $(NODE)_init.yml -i inventory_init.ini

run-debug:
	ansible-playbook $(NODE).yml -vvv

run-check:
	ansible-playbook $(NODE).yml --check --diff

get-info:
	ansible $(NODE) -m setup

init: fetch_git_submodules prepare_vault_password_file prepare_log_directory

vault-create:
ifdef NODE
	mkdir -p ./_external/secrets/group_vars/$(NODE)
	ansible-vault create ./_external/secrets/group_vars/$(NODE)/vault.yml
else
	mkdir -p ./_external/secrets/group_vars/all
	ansible-vault create ./_external/secrets/group_vars/all/vault.yml
endif

vault-edit:
ifdef NODE
	ansible-vault edit ./_external/secrets/group_vars/$(NODE)/vault.yml 
else
	ansible-vault edit ./_external/secrets/group_vars/all/vault.yml
endif

clean:
	rm -rf ~/.ansible

update-submodules: update_git_submodules
