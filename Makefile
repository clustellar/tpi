PWD=`pwd`

build:
	docker run --rm --privileged -v /dev:/dev -v ${HOME}/.local/aarch64:/build/bin -v ${PWD}:/build mkaczanowski/packer-builder-arm  build pi-ubuntu-arm64.json

image:
	sudo dd bs=4M if=ubuntu-20.04.img of=/dev/sdc conv=fsync

vault: ./etc/vault.d/root.hcl
	if docker ps -a | grep root-vault ; then docker rm -vf root-vault ; fi
	docker run -d -p 8200:8200 -e VAULT_ADDR=http://127.0.0.1:8200 --name root-vault --cap-add IPC_LOCK -v ${PWD}/deploy:/scripts:rw -v ${PWD}/data/certs:/data:rw -v ${PWD}/data/vault:/var/lib/vault:rw -v ${PWD}/etc/vault.d/root.hcl:/etc/vault.hcl vault:latest vault server -config /etc/vault.hcl

reset: ./data/vault
	if docker ps -a | grep root-vault ; then docker rm -vf root-vault ; fi
	sudo rm -rf ./data/vault/*
	sudo rm -rf ./data/certs/*

exec:
	docker exec -it root-vault sh

pubkey:
	cp ~/.ssh/id_rsa.pub id_rsa.pub

download:
	docker run -it \
    -v ${PWD}:/foo \
    --entrypoint=/bin/sh \
    docker.io/hashicorp/consul-template:latest@sha256:6f43808fc2db33b714fa5a20bcda02440bcfce737ee0b53c558d2965a060dfeb

clean:
