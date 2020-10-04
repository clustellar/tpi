#!/bin/bash
source `which load`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_generate_netplan() {
  cat <<EOF
network:
    ethernets:
        eth0:
            dhcp4: false
            addresses:
              - $IP_ADDRESS/$NETMASK
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
		local ip="$(hostname -I | cut -d' ' -f1)"
		if [ "$IP_ADDRESS" != "$ip" ]; then
			echo "Setting static IP_ADDRESS=$IP_ADDRESS, will exit immediately and exit"
			_set_static_ip_address
			exit 0
		fi
	fi

	if [ -n "$HOSTNAME" ]; then
		echo "setting hostname: $HOSTNAME"
		echo "$HOSTNAME" | sudo tee /etc/hostname
	fi

	deploy-vault-local.sh
	deploy-consul-template.sh
	deploy-consul.sh
	deploy-nomad.sh
}

load ${@}
if [ $? -ne 0 ]; then
	echo "[ERROR] Could not load env or missing env variables, exiting."
	exit 1
fi

if [ -z "$NODEENV" ]; then 
	echo "[ERROR] Could not find node env file '$NODEENV', exiting."
	exit 1
else
	cat $NODEENV
	source $NODEENV
fi

_main
exit 0
