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

init: fetch_git_submodules prepare_vault_password_file

clean:
	rm -rf ~/.ansible

update-submodules: update_git_submodules
