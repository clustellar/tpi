listener "tcp" {
	address = "0.0.0.0:8200"
	tls_cert_file = ""
	tls_key_file = ""
}

storage "consul" {
	address = "127.0.0.1"
	path = "vault/"
	token = "${VAULT_TOKEN}"
}

ui = true
