#!/bin/sh
source ./vault-common.sh

if [ "$#" -ne 1 ]; then
	_error "Invalid args: must supply a scp destination like user@host:/home/user/path/token/to/put"
fi

SCP="$1" # i.e user@host:/path/to/token
NODE="$(echo $SCP | cut -d @ -f2 | cut -d : -f1)"
shift

_main() {
        _load_vault_token $INFILE
	vault write $INT_PKI/roles/$NODE-role allowed_domains="$NODE.$DOMAIN" allow_subdomains=true max_ttl="$INT_TTL"

	cat <<EOF > $DATADIR/$NODE-policy.hcl
path "$INT_PKI/issue/$NODE-role" {
	capabilities = ["read", "create", "update"]
}

path "auth/token/create" {
	capabilities = ["update"]
}
EOF

	vault policy write $NODE-policy $DATADIR/$NODE-policy.hcl
        vault policy list
	vault token create -format=yaml -policy="$INT_PKI/roles/$NODE-role" -policy="$NODE-policy" > $DATADIR/$NODE-token.yaml
	cat $DATADIR/$NODE-token.yaml
}

_main

