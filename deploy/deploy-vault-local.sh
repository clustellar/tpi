#!/bin/bash
# https://learn.hashicorp.com/tutorials/vault/deployment-guide
# /usr/local/bin/vault is built into the image using packer
source `which vault-common.sh`
source `which hostenv`

vault_user="vault"
vault_bin="/usr/local/bin/vault"
vault_service_dir="/etc/systemd/system"
vault_config_dir="/etc/vault.d"
vault_service_file="$vault_service_dir/vault.service"
vault_config_file="$vault_config_dir/vault.hcl"
vault_data_dir="/var/lib/vault"
vault_ui="false"
#cert_dir="/opt/vault/certs"

if [ ! -z "$VAULT_DISABLE" ]; then
	echo "[WARN] vault has been disabled, exiting."
	exit 0
fi

if [ ! -f "$vault_bin" ]; then
	echo "[ERROR] vault binary not found, exiting."
	exit 1
fi

if [ ! -x "$vault_bin" ]; then
	chmod +x $vault_bin
fi

_main() {
	vault --version
	vault -autocomplete-install
	complete -C $vault_bin vault
	sudo setcap cap_ipc_lock=+ep $vault_bin
	sudo useradd --system --home $vault_config_dir --shell /bin/false $vault_user

	echo "configuring vault..."
	sudo mkdir --parents $vault_config_dir
	sudo mkdir --parents $vault_data_dir
	sudo touch $vault_config_file
	sudo chown --recursive $vault_user:$vault_user $vault_config_dir
	sudo chown --recursive $vault_user:$vault_user $vault_data_dir
	sudo chmod 640 $vault_config_file

	_generate_vault_local_config_file | sudo tee $vault_config_file
	_generate_vault_service_file | sudo tee $vault_service_file

	echo "starting vault"
	sudo systemctl enable vault
	sudo systemctl start vault
	sudo systemctl status vault

	_vault_init $INFILE
	_unseal $INFILE
	_load_vault_token $INFILE

	_setup_root_pki $ROOT_PKI $ROOT_CN $ROOT_TTL
	_setup_pki $INT_PKI $INT_CN $ROOT_PKI $INT_TTL

	VAULT_ADDR=$VAULT_ROOT_ADDR VAULT_TOKEN="$(cat $VAULT_ROOT_TOKEN_FILE)" _sign_pki $INT_PKI $VAULT_ROOT_PKI $INT_TTL

	_set_signed_pki $INT_PKI
	_setup_pki_roles $INT_PKI $INT_ROLE $INT_DOMAINS $INT_TTL
}

_generate_vault_local_config_file() {
	cat <<EOF
listener "tcp" {
  address       = "127.0.0.1:8200"
#	tls_cert_file = "$cert_dir/server.crt"
#	tls_key_file  = "$cert_dir/server.key"

#  tls_require_and_verify_client_cert = "true"
#	tls_client_ca_file = "$cert_dir/ca.crt"
}
storage "file" {
	path = "$vault_data_dir"
}
ui = $vault_ui
EOF
}

_generate_vault_service_file() {
	cat <<EOF
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$vault_config_file
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=$vault_bin server -config=$vault_config_file
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
}

_main "${@}"
exit 0
