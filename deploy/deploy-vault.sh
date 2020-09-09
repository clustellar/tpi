#!/bin/bash
# https://learn.hashicorp.com/tutorials/vault/deployment-guide
# /usr/local/bin/vault is built into the image using packer

vault_user="vault"
vault_bin="/usr/local/bin/vault"
vault_service_dir="/etc/systemd/system"
vault_config_dir="/etc/vault.d"
vault_service_file="$vault_service_dir/vault.service"
vault_config_file="$vault_config_dir/vault.hcl"
vault_data_dir="/var/lib/vault"
vault_ui="true"

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

if [ ! -f "$vault_sys" ]; then
	echo "[ERROR] vault systemd service file ($vault_sys) does not exist, exiting."
	exit 1
fi

if [ ! -f "$vault_cfg" ]; then
	echo "[ERROR] vault config file ($vault_cfg) does not exist, exiting."
	exit 1
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

	_generate_vault_local_config_file > $vault_config_file
	_generate_vault_service_file > $vault_service_file

	echo "starting vault"
	sudo systemctl enable vault
	sudo systemctl start vault
	sudo systemctl status vault

	_bootstrap_vault
}

_bootstrap_vault() {
	export VAULT_ADDR='http://127.0.0.1:8200'
	vault operator init -key-shares=5 -key-threshold=3 > $vault_data_dir/init-data
	cat $vault_data_dir/init-data | grep "Unseal Key 1: " | awk '{print $4}' | vault operator unseal
	cat $vault_data_dir/init-data | grep "Unseal Key 2: " | awk '{print $4}' | vault operator unseal
	cat $vault_data_dir/init-data | grep "Unseal Key 3: " | awk '{print $4}' | vault operator unseal
	export VAULT_TOKEN="$(cat $vault_data_dir/init-data | grep "Initial Root Token: " | awk '{print $4}')"
	vault login

	# https://learn.hashicorp.com/tutorials/vault/pki-engine
	vault secrets enable pki
	vault secrets tune -max-lease-ttl=87600h pki
	vault write -field=certificate pki/root/generate/internal common_name="example.com" ttl=87600h > $vault_data_dir/ca.crt
	vault write pki/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"
	vault secrets enable -path=pki_int pki
	vault secrets tune -max-lease-ttl=43800h pki_int
	vault write -format=json pki_int/intermediate/generate/internal common_name="example.com Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
	vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
	vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
	vault write pki_int/roles/example-dot-com allowed_domains="example.com" allow_subdomains=true max_ttl="720h"
	vault write pki_int/issue/example-dot-com common_name="test.example.com" format=pem_bundle ttl="24h"
}

_generate_vault_local_config_file() {
	cat <<EOF
listener "tcp" {
  address       = "0.0.0.0:8200"
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
