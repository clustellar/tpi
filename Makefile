PWD=`pwd`

build:
	docker run --rm --privileged -v /dev:/dev -v ${HOME}/.local/aarch64:/build/bin -v ${PWD}:/build packer-builder-arm build pi-ubuntu-arm64.json

image:
	sudo dd bs=4M if=ubuntu-20.04.img of=/dev/sdc conv=fsync

vault: ./etc/vault.d/root.hcl
	if docker ps -a | grep root-vault ; then docker rm -vf root-vault ; fi
	docker run -d -p 8200:8200 -e VAULT_ADDR=http://127.0.0.1:8200 --name root-vault --cap-add IPC_LOCK -v ${PWD}/deploy/boot-vault.sh:/boot-vault.sh -v ${PWD}/data/vault:/var/lib/vault:rw -v ${PWD}/etc/vault.d/root.hcl:/etc/vault.hcl vault:latest vault server -config /etc/vault.hcl

reset: ./data/vault
	if docker ps -a | grep root-vault ; then docker rm -vf root-vault ; fi
	sudo rm -rf ./data/vault/*

pubkey:
	cp ~/.ssh/id_rsa.pub id_rsa.pub

clean:
