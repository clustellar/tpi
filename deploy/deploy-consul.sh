#!/bin/bash
# https://learn.hashicorp.com/tutorials/consul/deployment-guide
# /usr/local/bin/consul is built into the image using packer
source $NODEENV

DATACENTER="${DATACENTER}"
consul_user="consul"
consul_bin="/usr/local/bin/consul"
consul_service_dir="/etc/systemd/system"
consul_config_dir="/etc/consul.d"
consul_service_file="$consul_service_dir/consul.service"
consul_config_file="$consul_config_dir/consul.hcl"
consul_data_dir="/var/lib/consul"
consul_encrypt_key=""
consul_ui="true"
cert_dir="/opt/consul/certs"

if [ ! -z "$CONSUL_DISABLE" ]; then
	echo "[WARN] consul has been disabled, exiting."
	exit 0
fi

if [ -z "${DATACENTER}" ]; then
	echo "[ERROR] consul datacenter not set, exiting."
	exit 1
fi

if [ ! -f "$consul_bin" ]; then
	echo "[ERROR] consul binary not found, exiting."
	exit 1
fi

if [ ! -x "$consul_bin" ]; then
	chmod +x $consul_bin
fi

_main() {
	consul --version
	consul -autocomplete-install
	complete -C $consul_bin consul
	sudo useradd --system --home $consul_config_dir --shell /bin/false $consul_user

	echo "configuring consul..."
	sudo mkdir --parents $consul_config_dir
	sudo mkdir --parents $consul_data_dir
	sudo touch $consul_config_file
	sudo chown --recursive $consul_user:$consul_user $consul_config_dir
	sudo chown --recursive $consul_user:$consul_user $consul_data_dir
	sudo chmod 640 $consul_config_file

	_generate_consul_config_file | sudo tee $consul_config_file
	_generate_consul_service_file | sudo tee $consul_service_file

	echo "starting consul"
	consul validate $consul_config_file
	sudo systemctl enable consul
	sudo systemctl start consul
	sudo systemctl status consul

	echo "setting env vars for consul clients"
	export CONSUL_CACERT=$cert_dir/client-ca.crt
	export CONSUL_CLIENT_CERT=$cert_dir/client.crt
	export CONSUL_CLIENT_KEY=$cert_dir/client.key
}

_generate_consul_config_file() {
	cat <<EOF
server = true
bootstrap_expect = 3
ui = $consul_ui
client_addr = "0.0.0.0"
datacenter = "$DATACENTER"
data_dir = "$consul_data_dir"
encrypt = "$consul_encrypt_key"
ca_file = "$cert_dir/server-ca.crt"
cert_file = "$cert_dir/server.crt"
key_file = "$cert_dir/server.key"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
EOF
}

_generate_consul_service_file() {
	cat <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$consul_config_file

[Service]
Type=notify
User=$consul_user
Group=$consul_user
ExecStart=$consul_bin agent -config-dir=$consul_config_dir
ExecReload=$consul_bin reload
ExecStop=$consul_bin leave
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

_main "${@}"
exit 0
