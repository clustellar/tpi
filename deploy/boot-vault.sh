#!/bin/sh
source ./vault-common.sh

CERTS=""

_main() {
	_vault_init $INFILE
	_unseal $INFILE
	_load_vault_token $INFILE

	_setup_root_pki $ROOT_PKI $ROOT_CN $ROOT_TTL
	_setup_pki $INT_PKI $INT_CN $ROOT_PKI $INT_TTL
	_sign_pki $INT_PKI $ROOT_PKI $INT_TTL
	_set_signed_pki $INT_PKI
	_setup_pki_roles $INT_PKI $INT_ROLE $INT_DOMAINS $INT_TTL

	for cert in $(echo $CERTS | tr "," "\n"); do
		echo "Certificate: $cert"
		_issue_pki_certificate $INT_PKI $cert $INT_ROLE $CERT_TTL
	done
}

for i in "$@"; do
	key="$(echo $i | cut -d '=' -f1)"
	val="$(echo $i | cut -d '=' -f2-)"
	case $key in
		--root-pki)
			ROOT_PKI="$val"
			;;
		--root-cn)
			ROOT_CN="$val"
			;;
		--root-ttl)
			ROOT_TTL="$val"
			;;
		--init-data-file)
			INFILE="$val"
			;;
		--int-pki)
			INT_PKI="$val"
			;;
		--int-cn)
			INT_CN="$val"
			;;
		--int-ttl)
			INT_TTL="$val"
			;;
		--int-role)
			INT_ROLE="$val"
			;;
		--allowed-domains)
			INT_DOMAINS="$val"
			;;
		--domain)
			DOMAIN="$val"
			;;
		--cert)
			CERTS="$val"
			;;
		--data-dir)
			DATADIR="$val"
			;;
		*)
			_warn "Unknown argument: $i, skipping"
			;;
	esac
done

_main
