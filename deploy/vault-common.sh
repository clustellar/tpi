#!/bin/sh

DOMAIN=local
DATADIR=/data
INFILE=/var/lib/vault/init-data
ROOT_PKI=root
ROOT_CN=root.vault
ROOT_TTL=87600h
INT_PKI=pki
INT_CN=vault.$DOMAIN
INT_TTL=43800h
INT_DOMAINS="*.local"
INT_ROLE=local-issuer
CERT_TTL=21900h

_log() {
	echo "[INFO] ${@}"
}

_warn() {
	echo "[WARN] ${@}"
}

_error() {
	>&2 echo "[ERROR] ${@}"
}

_vault_sealed() {
	if [ $(vault status | grep Sealed | awk '{print $2}') == "true" ]; then
		return 0
	else
		return 1
	fi
}

_vault_init() {
	local infile="$1"
	if [ -f "$infile" ]; then
		_log "vault is already initialized."
	else
		_log "initializing vault"
		vault operator init > $infile
	fi
}

_unseal() {
	local infile="$1"
	local sealed="1"
	local count="0"
	if [ ! -f "$infile" ]; then
		_error "init-data file not found '$infile'."
		return 1
	fi

	if _vault_sealed ; then
		sealed="1"
	else
		_log "vault is not sealed."
		return 0
	fi

	_log "unsealing vault"
	while [ -n "$sealed" ]; do
		count=$((count+1)) # increment
		vault operator unseal $(cat $infile | grep "Unseal Key $count:" | awk '{print $4}')
		if _vault_sealed ; then sealed="1" ; else sealed=""; fi
		if [ "$count" -gt 10 ]; then
			_error "could not unseal vault!"
			return 1
		fi
	done

	_log "vault has been unsealed."
	return 0
}

_load_vault_token() {
	local infile="$1"
	export VAULT_TOKEN=$(cat $infile | grep "Initial Root Token: " | awk '{print $4}')
}

_setup_root_pki() {
	if [ $# -ne 3 ]; then _error "not enough args to setup root pki, expect <pki> <cn> <ttl (optional)>" && return 1 ; fi
	local pki="$1"
	local cn="$2"
	local maxttl="$3"

	_log "Setting up root pki '$pki' (common_name: $cn, signed_by: self, ttl: $maxttl)"

	vault secrets enable -path=$pki pki
	vault secrets tune -max-lease-ttl=$maxttl $pki
	vault write -field=certificate $pki/root/generate/internal common_name="$cn" ttl=$maxttl > $DATADIR/$pki-ca.crt
	vault write $pki/config/urls issuing_certificates="$VAULT_ADDR/v1/$pki/ca" crl_distribution_points="$VAULT_ADDR/v1/$pki/crl"
}

_setup_pki() {
	if [ $# -ne 4 ]; then _error "not enough args to setup root pki, expect <pki> <cn> <ttl (optional)>" && return 1 ; fi
	local pki="$1"
	local cn="$2"
	local rootpki="$3"
	local maxttl="$4"
	local csryaml="$pki-csr.yaml"
	local csrpem="$pki-csr.pem"
	local signedyaml="$pki-signed.yaml"
	local signedpem="$pki-signed.pem"

	_log "Setting up intermediate pki '$pki' (common_name: $cn, signed_by: $rootpki, ttl: $maxttl)"

	vault secrets enable -path=$pki pki
	vault secrets tune -max-lease-ttl=$maxttl $pki

	vault write -format=yaml $pki/intermediate/generate/internal common_name="$cn Intermediate Authority" > $DATADIR/$csryaml
	cat $DATADIR/$csryaml | sed -n '/-----BEGIN/,/-----END/p' | awk '{$1=$1;print}' > $DATADIR/$csrpem

	vault write -format=yaml $rootpki/root/sign-intermediate csr=@$DATADIR/$csrpem format=pem_bundle ttl="$maxttl" > $DATADIR/$signedyaml
	cat $DATADIR/$signedyaml | sed -n '/-----BEGIN/,/-----END/p' | awk '{$1=$1;print}' > $DATADIR/$signedpem

	vault write $pki/intermediate/set-signed certificate=@$DATADIR/$signedpem
}

_setup_pki_roles() {
	if [ $# -ne 4 ]; then _error "not enough args to setup root pki roles, expect pki, role name, allowed domains, and ttl" && return 1 ; fi
	local pki="$1"
	local role="$2"
	local allowed="$3"
	local maxttl="$4"

	vault write $pki/roles/$role allowed_domains=$allowed allow_bare_domains=true allow_glob_domains=true allow_subdomains=true max_ttl=$maxttl
}

_issue_pki_certificate() {
	if [ $# -ne 4 ]; then _error "not enough args to issue pki certificate: expect pki, common_name, role, and ttl" && return 1 ; fi
	local pki="$1"
	local cn="$2"
	local role="$3"
	local maxttl="$4"

	vault write -format=yaml $pki/issue/$role common_name="$cn" ttl="$maxttl" > $DATADIR/$pki-$cn.yaml
}

