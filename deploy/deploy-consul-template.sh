#!/bin/bash
# https://learn.hashicorp.com/tutorials/consul/deployment-guide
# /usr/local/bin/consul is built into the image using packer

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

	_generate_consul_config_file | sudo tee $consul_config_file
	_generate_consul_service_file | sudo tee $consul_service_file

	echo "starting consul"
	consul validate $consul_config_file
	sudo systemctl enable consul-template
	sudo systemctl start consul-template
	sudo systemctl status consul-template
}

_generate_consul_config_file() {
	cat <<EOF
vault {
  address      = "$VAULT_SCHEME://$VAULD_ADDR:$VAULT_PORT"
  token        = "$VAULT_TOKEN"
  grace        = "1s"
  unwrap_token = false
  renew_token  = true
}

# NOMAD Certs
template {
  source      = "/opt/nomad/templates/server.crt.tpl"
  destination = "/opt/nomad/certs/server.crt"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/server.key.tpl"
  destination = "/opt/nomad/certs/server.key"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/client.crt.tpl"
  destination = "/opt/nomad/certs/client.crt"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/client.key.tpl"
  destination = "/opt/nomad/certs/client.key"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/ca.crt.tpl"
  destination = "/opt/nomad/certs/ca.crt"
  command     = "systemctl reload nomad"
}

# CONSUL Certs
template {
  source      = "/opt/consul/templates/server.crt.tpl"
  destination = "/opt/consul/certs/server.crt"
  perms       = 0700
  command     = "systemctl reload consul"
}

template {
  source      = "/opt/consul/templates/server.key.tpl"
  destination = "/opt/consul/certs/server.key"
  perms       = 0700
  command     = "systemctl reload consul"
}

template {
  source      = "/opt/consul/templates/client.crt.tpl"
  destination = "/opt/consul/certs/client.crt"
  perms       = 0700
  command     = "systemctl reload consul"
}

template {
  source      = "/opt/consul/templates/client.key.tpl"
  destination = "/opt/consul/certs/client.key"
  perms       = 0700
  command     = "systemctl reload consul"
}

template {
  source      = "/opt/consul/templates/ca.crt.tpl"
  destination = "/opt/consul/certs/ca.crt"
  command     = "systemctl reload consul"
}

# Vault Certs
template {
  source      = "/opt/vault/templates/server.crt.tpl"
  destination = "/opt/vault/certs/server.crt"
  perms       = 0700
  command     = "systemctl reload vault"
}

template {
  source      = "/opt/vault/templates/server.key.tpl"
  destination = "/opt/vault/certs/server.key"
  perms       = 0700
  command     = "systemctl reload vault"
}

template {
  source      = "/opt/vault/templates/client.crt.tpl"
  destination = "/opt/vault/certs/client.crt"
  perms       = 0700
  command     = "systemctl reload vault"
}

template {
  source      = "/opt/vault/templates/client.key.tpl"
  destination = "/opt/vault/certs/client.key"
  perms       = 0700
  command     = "systemctl reload vault"
}

template {
  source      = "/opt/vault/templates/ca.crt.tpl"
  destination = "/opt/vault/certs/ca.crt"
  command     = "systemctl reload vault"
}
EOF
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
