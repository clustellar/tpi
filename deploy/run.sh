#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Defaults
VAULT_PORT=8300
CONSUL_PORT=8500
NOMAD_PORT=4646
JOIN_MEMBERS=()
DISABLED_AGENTS=()
SERVER_ONLY=""
CLIENT_ONLY=""
IP_ADDRESS="${IP_ADDRESS}"
DATACENTER="${DATACENTER}"
REGION="${REGION}"

_help() {
	cat <<-EOF
		Usage: $0 <options>
		Options:
			--ip <addr>											# Static ip address to set for this node
			--join <addr>										# Another cluster member to join to (with consul)
			--datacenter <dc1>							# Set datacenter for this node
			--region <us>										# Set region for this node
			--client-only										# Set to only run agents in client mode only
			--server-only										# Set to only run agents in server mode only
			--disable <vault|consul|nomad>	# Set to name of agent to skip deployment of
			--help													# Show help menu
EOF
}

_nomad() {
	local tmpl="$DIR/templates/nomad.service"
}

_main() {
	case "$1" in
		--ip)
			IP_ADDRESS=$2
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
}

_main "${@}"
exit 0
