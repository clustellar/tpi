#!/bin/bash
# https://learn.hashicorp.com/tutorials/consul/deployment-guide
# /usr/local/bin/consul is built into the image using packer
source $NODEENV

consul_user="consul"
consul_bin="/usr/local/bin/consul-template"
consul_service_dir="/etc/systemd/system"
consul_config_dir="/etc/consul-template.d"
consul_service_file="$consul_service_dir/consul-template.service"
consul_config_file="$consul_config_dir/consul-template.hcl"

if [ ! -z "$CONSUL_TEMPLATE_DISABLE" ]; then
	echo "[WARN] consul template has been disabled, exiting."
	exit 0
fi

if [ ! -f "$consul_bin" ]; then
	echo "[ERROR] consul binary not found, exiting."
	exit 1
fi

if [ ! -x "$consul_bin" ]; then
	chmod +x $consul_bin
fi

_main() {
	consul-template --version
	sudo useradd --system --home $consul_config_dir --shell /bin/false $consul_user

	echo "configuring consul template..."
	sudo mkdir --parents $consul_config_dir
	sudo touch $consul_config_file
	sudo chown --recursive $consul_user:$consul_user $consul_config_dir
	sudo chown --recursive $consul_user:$consul_user $consul_data_dir
	sudo chmod 640 $consul_config_file

	sudo mkdir -p /opt/nomad/templates
	sudo mkdir -p /opt/consul/templates
	sudo mkdir -p /opt/vault/templates

	_generate_consul_config_file | sudo tee $consul_config_file
	_generate_consul_service_file | sudo tee $consul_service_file
	_generate_templates_for_component nomad
	_generate_templates_for_component consul
	_generate_templates_for_component vault

	sudo chown -R nomad:nomad /opt/nomad	
	sudo chown -R consul:consul /opt/consul
	sudo chown -R vault:vault /opt/vault
	sudo chmod 644 /opt/*/templates/*

	echo "starting consul"
	consul validate $consul_config_file
	sudo systemctl enable consul-template
	sudo systemctl start consul-template
	sudo systemctl status consul-template
}

_generate_template_stanza_for_file() {
	local comp="$1"
	local file="$2"
	cat <<EOF
template {
  source      = "/opt/$comp/templates/$file.tpl"
  destination = "/opt/$comp/certs/$file"
  perms       = 0700
  command     = "systemctl reload $comp"
}
EOF
}

# comp=nomad|consul|vault, file=server|client, field=certificate|private_key
_generate_template_file() {
	local comp="$1"
	local file="$2"
	local field="$3"
	cat <<EOF
{{ with secret "$INT_PKI/issue/$INT_ROLE" "common_name=$comp-$file.$DOMAIN" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1" }}
{{ .Data.$field }}
{{ end }}
EOF
}

_generate_template_stanza_for_component() {
	local comp="$1"
	echo "# $comp certs"
	_generate_template_stanza_for_file $comp server-ca.crt
	_generate_template_stanza_for_file $comp server.crt
	_generate_template_stanza_for_file $comp server.key
	_generate_template_stanza_for_file $comp client-ca.crt
	_generate_template_stanza_for_file $comp client.crt
	_generate_template_stanza_for_file $comp client.key
}

_generate_templates_for_component() {
	local comp="$1"
	local roles=(server client)
	for role in "${roles[@]}"; do
		_generate_template_file $comp $role certificate | sudo tee /opt/$comp/templates/$role.crt.tpl
		_generate_template_file $comp $role private_key | sudo tee /opt/$comp/templates/$role.key.tpl
		_generate_template_file $comp $role issuing_ca | sudo tee /opt/$comp/templates/$role-ca.crt.tpl
	done
}

_generate_consul_config_file() {
	cat <<EOF
vault {
  address      = "http://127.0.0.1:8200"
	vault_agent_token_file = "/var/lib/vault/token"
  unwrap_token = false
  renew_token  = true
}
EOF

	_generate_template_stanza_for_component nomad
	_generate_template_stanza_for_component consul
	_generate_template_stanza_for_component vault
}

_generate_consul_service_file() {
	cat <<EOF
[Unit]
Description="HashiCorp Consul Template - rendering dynamic config files"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul-template.d/consul-template.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul-template -config=/etc/consul-template.d
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

_main "${@}"
exit 0
