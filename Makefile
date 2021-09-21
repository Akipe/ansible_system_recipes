.PHONY: init run run-password run-debug run-check vault-create vault-edit clean get-info update-submodules 

fetch_git_submodules:
	git submodule update --init --recursive

update_git_submodules:
	git submodule update --remote --merge

prepare_vault_password_file:
	cp .vault_password.env.dist .vault_password.env
	chmod 600 .vault_password.env

prepare_log_directory:
	mkdir ./log

run:
	ansible-playbook $(NODE).yml \
		--inventory inventory.ini

run-init:
	ansible-playbook $(NODE)_init.yml \
		--inventory inventory_init.ini

run-local:
	ansible-playbook $(NODE).yml \
		--inventory inventory_local.ini

run-direct:
	ansible-playbook $(PLAYBOOK).yml \
		--connection "ssh" \
		--user "root" \
		--ask-pass \
		--extra-vars "{target: $(ADDRESS)}" \
		--inventory $(ADDRESS), \
		--extra-vars "@./group_vars/all/vars.yml" \
		--extra-vars "@./group_vars/all/vault.yml" \
		--extra-vars "@./group_vars/$(PLAYBOOK)/vars.yml" \
		--extra-vars "@./group_vars/$(PLAYBOOK)/vault.yml"

run-debug:
	ansible-playbook $(NODE).yml -vvv

run-check:
	ansible-playbook $(NODE).yml --check --diff

get-info:
	ansible $(NODE) -m setup

get-info-direct:
	ansible all \
		--connection "ssh" \
		--user "root" \
		--ask-pass \
		--inventory $(ADDRESS), \
		--module-name setup

init: fetch_git_submodules \
		ansible-collection-install \
		prepare_vault_password_file \
		prepare_log_directory

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

ansible-collection-install:
	ansible-galaxy collection install -r ./requirements.yml

clean:
	rm -rf ~/.ansible

update-submodules: update_git_submodules
