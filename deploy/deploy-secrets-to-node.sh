#!/bin/sh
source ./vault-common.sh

if [ #$ -ne 1 ]; then
	_error "Invalid args: must supply a node name (hostname)"
fi

NODE="$1" # like rpi1
shift

_main() {
	vault write $PKI/roles/$NODE-role allowed_domains="$NODE.$DOMAIN" allow_subdomains=true max_ttl="$INT_TTL"

	cat <<EOF > ./$NODE-policy.hcl
path "$PKI/issue/$NODE-role" {
	capabilities = ["read", "create", "update"]
}

path "auth/token/create" {
	capabilties = ["update"]
}
EOF

	vault policy write $NODE-policy ./$NODE-policy.hcl
	vault token create -format=yaml -policy="$NODE-role" -policy="$NODE-policy" > $NODE-token.yaml
	cat $NODE-token.yaml

#	scp $NODE-token.yaml $NODE:~/.ssh/vault-token.yaml
}

_main

