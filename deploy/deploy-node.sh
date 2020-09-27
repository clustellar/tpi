#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Defaults
JOIN_MEMBERS=()
DISABLED_AGENTS=()
SERVER_ONLY=""
CLIENT_ONLY=""
IP_ADDRESS="${IP_ADDRESS}"
IP_GATEWAY="${IP_GATEWAY}"
IP_DNS="${IP_DNS}"
DATACENTER="${DATACENTER}"
REGION="${REGION}"
HOSTNAME=""
VAULT_ROOT_ADDR=""
VAULT_ROOT_PKI=pki
VAULT_ROOT_TOKEN_FILE=""
DOMAIN=local
DATADIR=/data
INFILE=/var/lib/vault/init-data
ROOT_PKI=root
ROOT_CN=root.vault
ROOT_TTL=87600h
INT_PKI=local-pki
INT_CN=vault.$DOMAIN
INT_TTL=43800h
INT_DOMAINS="*.local"
INT_ROLE=local-issuer
CERT_TTL=21900h

_help() {
	cat <<-EOF
		Usage: $0 <options>
		Options:
			--ip <addr>											# Static ip address to set for this node
      --hostname <hostname>           # Set the hostname for this node
			--join <addr>										# Another cluster member to join to (with consul)
			--datacenter <dc1>							# Set datacenter for this node
			--region <us>										# Set region for this node
			--domain <local>								# Set the domain for this node
			--vault-root-addr <url>         # Set the vault address of the remote vault to sign the local vault with
			--vault-root-pki <pki>					# Set the vault pki of the remote root vault
			--vault-root-token-file <file>	# Set the path of the token file for the remote vault
			--client-only										# Set to only run agents in client mode only
			--server-only										# Set to only run agents in server mode only
			--disable <vault|consul|nomad>	# Set to name of agent to skip deployment of
			--help													# Show help menu
EOF
}

_generate_hostenv_file() {
	echo "HOSTNAME=$HOSTNAME"
	if [ -n "$IP_ADDRESS" ]; then
		echo "IP_ADDRESS=$IP_ADDRESS"
		echo "IP_GATEWAY=$IP_GATEWAY"
		echo "IP_DNS=$IP_DNS"
	fi
	echo "DATACENTER=$DATACENTER"
	echo "REGION=$REGION"
	echo "SERVER_ONLY=$SERVER_ONLY"
	echo "CLIENT_ONLY=$CLIENT_ONLY"
	echo "JOIN=$JOIN"
	echo "DOMAIN=$DOMAIN"
	echo "VAULT_ROOT_ADDR=$VAULT_ROOT_ADDR"
	echo "VAULT_ROOT_PKI=$VAULT_ROOT_PKI"
	echo "VAULT_ROOT_TOKEN_FILE=$VAULT_ROOT_TOKEN_FILE"
}

_generate_netplan() {
  cat <<EOF
network:
    ethernets:
        eth0:
            dhcp4: false
            addresses:
              - $IP_ADDRESS
            gateway4: $IP_GATEWAY
            nameservers:
              addresses: [$IP_DNS]
    version: 2
EOF
}

_set_static_ip_address() {
	if [ -z "$IP_GATEWAY" ]; then
		IP_GATEWAY="$(echo $IP_ADDRESS | cut -d. -f1-3).1" # default gateway assume to be same netblock but .1
		echo "No gateway ip set, using $IP_GATEWAY"
	fi

	if [ -z "$IP_DNS" ]; then
		echo "No DNS IP set, using $IP_GATEWAY"
		IP_DNS="${IP_GATEWAY}"
	fi

	echo "setting ip address: $IP_ADDRESS"
  _generate_netplan | sudo tee /etc/netplan/50-cloud-init.yaml
	sudo netplan apply
}

_main() {
	if [ -n "$IP_ADDRESS" ]; then
		_set_static_ip_address
	fi

	if [ -n "$HOSTNAME" ]; then
		echo "setting hostname: $HOSTNAME"
		echo "$HOSTNAME" | sudo tee /etc/hostname
	fi

	_generate_hostenv_file | sudo tee /usr/local/bin/hostenv
	deploy-vault-local.sh
	deploy-consul-template.sh
	deploy-consul.sh
	deploy-nomad.sh
}

args=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--ip)
			IP_ADDRESS=$2
			shift
			shift
			;;
		--ip-gateway)
			IP_GATEWAY=$2
			shift
			shift
			;;
    --hostname)
			HOSTNAME="$2"
			shift
			shift
			;;
		--join)
			JOIN_MEMBERS+=$2
			shift
			shift
			;;
		--datacenter)
			DATACENTER=$2
			shift
			shift
			;;
		--region)
			REGION=$2
			shift
			shift
			;;
		--domain)
			DOMAIN="$2"
			shift
			shift
			;;
    --vault-root-addr)
			VAULT_ROOT_ADDR="$2"
			shift
			shift
			;;
		--vault-root-pki)
			VAULT_ROOT_PKI="$2"
			shift
			shift
			;;
		--vault-root-token-file)
			VAULT_ROOT_TOKEN_FILE="$2"
			shift
			shift
			;;
		--server-only)
			SERVER_ONLY=1
			shift
			;;
		--client-only)
			CLIENT_ONLY=1
			shift
			;;
		--disable)
			DISABLED_AGENTS+=("$2")
			shift
			shift
			;;
		*)
			shift
			_help;;
	esac
done

_main "${args[@]}"
exit 0
