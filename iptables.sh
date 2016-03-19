#!/bin/sh
# iptables config script
# usage: $0 [-h/-?] [-s <ssh_port>] [-p <port_1>,<port_2>,...,<port_n>]
# ~tc_noah, 3/18/16

OPTIND=1
HTTP=0
SSH_PORT=22
PORTS=""
IFS=","
PATH=/usr/sbin:/sbin:/bin:/usr/bin

# Check arguments
while getopts "?hs:p:" opt; do
    case "$opt" in
        h|\?)
            echo "usage: $0 [-h/-?] [-s <ssh_port>] [-p <port_1>,<port_2>,...,<port_n>]"
            echo "  -s <port>: specify ssh port (default 22)"
            echo "  -p <port1>,<port2>,...: allow incoming/outgoing traffic on specified ports"
            exit
            ;;
        s)  SSH_PORT=$OPTARG
            ;;
        p)  PORTS=$OPTARG
            echo $PORTS
            ;;
    esac
done

# Delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Always accept loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow ping from inside to outside
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Allow loopback access
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow outbound DNS
iptables -A OUTPUT -p udp -o eth0 --dport 53 -j ACCEPT
iptables -A INPUT -p udp -i eth0 --sport 53 -j ACCEPT

# Allow all SSH connections
iptables -A INPUT -i eth0 -p tcp --dport $SSH_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $SSH_PORT -m state --state ESTABLISHED -j ACCEPT

# Block DoS
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

for port in $PORTS; do
    iptables -A INPUT -i eth0 -p tcp --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp --sport $port -m state --state ESTABLISHED -j ACCEPT
done

# Flip defaults
iptables -A INPUT -P DROP
iptables -A OUTPUT -P DROP

# Print table
iptables -L

# Log dropped packets
iptables -N LOGGING
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables Packet Dropped: " --log-level 7
iptables -A LOGGING -j DROP

iptables -A INPUT -j LOGGING
iptables -A OUTPUT -j LOGGING
