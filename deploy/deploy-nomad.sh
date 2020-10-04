#!/bin/bash
# https://learn.hashicorp.com/tutorials/nomad/deployment-guide
# /usr/local/bin/nomad is built into the image using packer
source $NODEENV

nomad_user="nomad"
nomad_bin="/usr/local/bin/nomad"
nomad_service_dir="/etc/systemd/system"
nomad_config_dir="/etc/nomad.d"
nomad_service_file="$nomad_service_dir/nomad.service"
nomad_config_file="$nomad_config_dir/nomad.hcl"
nomad_data_dir="/var/lib/nomad"
nomad_ui="true"
cert_dir="/opt/nomad/certs"

if [ ! -z "$NOMAD_DISABLE" ]; then
	echo "[WARN] nomad has been disabled, exiting."
	exit 0
fi

if [ ! -f "$nomad_bin" ]; then
	echo "[ERROR] nomad binary not found, exiting."
	exit 1
fi

if [ ! -x "$nomad_bin" ]; then
	chmod +x $nomad_bin
fi

_main() {
	nomad --version
	nomad -autocomplete-install
	complete -C $nomad_bin nomad
	sudo setcap cap_ipc_lock=+ep $nomad_bin
	sudo useradd --system --home $nomad_config_dir --shell /bin/false $nomad_user

	echo "configuring nomad..."
	sudo mkdir --parents $nomad_config_dir
	sudo mkdir --parents $nomad_data_dir
	sudo touch $nomad_config_file
	sudo chown --recursive $nomad_user:$nomad_user $nomad_config_dir
	sudo chown --recursive $nomad_user:$nomad_user $nomad_data_dir
	sudo chmod 640 $nomad_config_file

	_generate_nomad_config_file | sudo tee $nomad_config_file
	_generate_nomad_service_file | sudo tee $nomad_service_file

	echo "starting nomad"
	sudo systemctl enable nomad
	sudo systemctl start nomad
	sudo systemctl status nomad
}

_generate_nomad_config_file() {
	cat <<EOF
datacenter = "${DATACENTER}"
data_dir = "$nomad_data_dir"
raft_protocol = 3
ui = $nomad_ui
server {
  enabled = true
  bootstrap_expect = 3
}
tls {
  http = true
	rpc = true
	ca_file = "$cert_dir/server-ca.crt"
	cert_file = "$cert_dir/server.crt"
	key_file = "$cert_dir/server.key"
  verify_https_client = true
}
client {
  enabled = true
}
autopilot {
  cleanup_dead_servers      = true
  last_contact_threshold    = "200ms"
  max_trailing_logs         = 250
  server_stabilization_time = "10s"
  enable_redundancy_zones   = false
  disable_upgrade_migration = false
  enable_custom_upgrades    = false
}
EOF
}

_generate_nomad_service_file() {
	cat <<EOF
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=$nomad_bin agent -config $nomad_config_dir
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
}

_main "${@}"
exit 0
