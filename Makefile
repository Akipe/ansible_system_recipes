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
	ansible-playbook ./playbooks/$(NODE).yml

run-init:
	ansible-playbook ./playbooks/$(NODE)_init.yml -i inventory_init.ini

run-local:
	ansible-playbook ./playbooks/$(NODE).yml \
		--connection=local \
		--inventory $(NODE), \
		--extra-vars "@./group_vars/all/vars.yml" \
		--extra-vars "@./group_vars/all/vault.yml" \
		--extra-vars "@./group_vars/$(NODE)/vars.yml" \
		--extra-vars "@./group_vars/$(NODE)/vault.yml"

run-direct:
	ansible-playbook ./playbooks/$(PLAYBOOK).yml \
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
	ansible-playbook ./playbooks/$(NODE).yml -vvv

run-check:
	ansible-playbook ./playbooks/$(NODE).yml --check --diff

get-info:
	ansible $(NODE) -m setup

get-info-direct:
	ansible all \
		--connection "ssh" \
		--user "root" \
		--ask-pass \
		--inventory $(ADDRESS), \
		--module-name setup


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
