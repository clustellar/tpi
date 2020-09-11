#!/bin/bash

vault_addr="https://vault:8200"
vault_data_dir="/var/lib/vault"
vault_config_dir="/etc/vault.d"
vault_agent_config_file="$vault_config_dir/vault-agent.hcl"
vault_ca_cert="/etc/ssl/vault-ca.crt"

_main() {
	_generate_vault_agent_config > $vault_agent_config_file
}

_generate_vault_agent_config() {
	cat <<EOF
pid_file = "$vault_data_dir/agent.pid"

vault {
	address = "$vault_addr"
	ca_cert = "$vault_ca_cert"
}

auto_auth {
	method "approle" {
		role_id_file_path = "$vault_config_dir/approle-role-id"
		secret_id_file_path = "$vault_config_dir/approle-secret-id"
	}

	sink "file" {
		config = {
			path = "$vault_data_dir/agent-token"
		}
	}
}

cache {
	use_auto_auth_token = true
}
EOF
}

_main
exit 0
