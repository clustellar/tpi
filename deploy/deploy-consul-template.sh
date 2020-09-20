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

	echo "configuring consul template..."
	sudo mkdir --parents $consul_config_dir
	sudo touch $consul_config_file
	sudo chown --recursive $consul_user:$consul_user $consul_config_dir
	sudo chown --recursive $consul_user:$consul_user $consul_data_dir
	sudo chmod 640 $consul_config_file

	_generate_consul_config_file > $consul_config_file
	_generate_consul_service_file > $consul_service_file

	echo "starting consul"
	consul validate $consul_config_file
	sudo systemctl enable consul-template
	sudo systemctl start consul-template
	sudo systemctl status consul-template
}

_generate_consul_config_file() {
	cat <<EOF
# This denotes the start of the configuration section for Vault. All values
# contained in this section pertain to Vault.
vault {
  # This is the address of the Vault leader. The protocol (http(s)) portion
  # of the address is required.
  address      = "http://active.vault.service.consul:8200"

  # This value can also be specified via the environment variable VAULT_TOKEN.
  token        = "s.m069Vpul3c4lfGnJ6unpxgxD"

  # This should also be less than or around 1/3 of your TTL for a predictable
  # behaviour. Consult https://github.com/hashicorp/vault/issues/3414
  grace        = "1s"

  # This tells consul-template that the provided token is actually a wrapped
  # token that should be unwrapped using Vault's cubbyhole response wrapping
  # before being used. Consult Vault's cubbyhole response wrapping documentation
  # for more information.
  unwrap_token = false

  # This option tells consul-template to automatically renew the Vault token
  # given. If you are unfamiliar with Vault's architecture, Vault requires
  # tokens be renewed at some regular interval or they will be revoked. Consul
  # Template will automatically renew the token at half the lease duration of
  # the token. The default value is true, but this option can be disabled if
  # you want to renew the Vault token using an out-of-band process.
  renew_token  = true
}

# This block defines the configuration for connecting to a syslog server for
# logging.
syslog {
  enabled  = true

  # This is the name of the syslog facility to log to.
  facility = "LOCAL5"
}

# This block defines the configuration for a template. Unlike other blocks,
# this block may be specified multiple times to configure multiple templates.
template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  source      = "/opt/nomad/templates/agent.crt.tpl"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "/opt/nomad/agent-certs/agent.crt"

  # This is the permission to render the file. If this option is left
  # unspecified, consul-template will attempt to match the permissions of the
  # file that already exists at the destination path. If no file exists at that
  # path, the permissions are 0644.
  perms       = 0700

  # This is the optional command to run when the template is rendered. The
  # command will only run if the resulting template changes.
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/agent.key.tpl"
  destination = "/opt/nomad/agent-certs/agent.key"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/ca.crt.tpl"
  destination = "/opt/nomad/agent-certs/ca.crt"
  command     = "systemctl reload nomad"
}

# The following template stanzas are for the CLI certs

template {
  source      = "/opt/nomad/templates/cli.crt.tpl"
  destination = "/opt/nomad/cli-certs/cli.crt"
}

template {
  source      = "/opt/nomad/templates/cli.key.tpl"
  destination = "/opt/nomad/cli-certs/cli.key"
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
