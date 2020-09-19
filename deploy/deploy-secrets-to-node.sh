#!/bin/sh
source ./vault-common.sh

if [ #$ -ne 1 ]; then
	_error "Invalid args: must supply a scp destination like user@host:/home/user/path/token/to/put"
fi

SCP="$1" # i.e user@host:/path/to/token
NODE="$(echo $SCP | cut -d @ -f2 | cut -d : -f1)"
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

	scp $NODE-token.yaml $SCP
}

_main

