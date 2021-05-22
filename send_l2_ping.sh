#!/bin/bash

if [ "$#" -lt 1 ]; then
	echo "Usage: ./send_l2_ping.sh <dst_mac>"
	exit 1
fi

# The `arping` utility needs the correct IP, so let's fetch it manually.
# Usually, you would do this the other way via the ARP protocol, but this
# homework is only about Layer-2!
if [[ ! "${1}" =~ ^([0-9a-fA-F]{2}:){5}[a-fA-F0-9]{2}$ ]]; then
    echo "Error: ${1} is not a valid MAC address"
    exit 1
fi

if [[ "${1}" == "00:00:00:00:01:01" ]]; then
    IPADDRESS=10.0.1.1
elif [[ "${1}" == "00:00:00:00:02:02" ]]; then
    IPADDRESS=10.0.2.2
elif [[ "${1}" == "00:00:00:00:03:03" ]]; then
    IPADDRESS=10.0.3.3
else
    echo "Warning: Unrecognized MAC address."
    IPADDRESS=0.0.0.0
fi

INTERFACE=`ifconfig | grep eth0 | sed 's/ .*//'`
arping -i ${INTERFACE} -t ${1} ${IPADDRESS}
