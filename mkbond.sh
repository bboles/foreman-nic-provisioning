#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
    echo "Must have root privileges to execute."
    exit 1
fi

# all of our boxes should only have 2 active physical devices but this logic
# should still work if we have more than that
NICS=$(ls -d /sys/class/net/*/device | awk -F/ '{print $5}')
FirstNIC=$(echo $NICS | awk '{print $1}')
SecondNIC=$(echo $NICS | awk '{print $2}')
# need this because UCS blades require additional bond options
Platform=$(dmidecode -s system-manufacturer)
if [[ $Platform =~ 'Cisco' ]]; then
    BondOpts='mode=active-backup miimon=10'
else
    BondOpts='mode=active-backup'
fi

if [[ -z "$FirstNIC" || -z "$SecondNIC" ]]; then
    echo "Unable to detect 2 active physical NICs.  Exiting."
    exit 1
fi

FirstNICMAC=$(cat /sys/class/net/$FirstNIC/address)
SecondNICMAC=$(cat /sys/class/net/$SecondNIC/address)

Ipaddr=''
Gateway=''
Netmask=''
Vlan=''

usage () {
    echo "Usage: $(basename $0) -I [IP address] -G [gateway IP] -N [netmask] -V [vlan #]"
    echo "All flags are required."
    echo
    echo "This script makes several assumptions:"
    echo "1. There are 2 active network cards."
    echo "2. You put in the correct IP, gateway, netmask and Vlan."
    echo "3. The existing config will be replaced."
}

# show usage and exit if no options are provided
if ( ! getopts "I:G:N:V:" OPT ); then
    usage
    exit 1
fi

while getopts "I:G:N:V:" OPT; do
    case $OPT in
	I)
	   Ipaddr=$OPTARG
	   ;;
	G)
	   Gateway=$OPTARG
	   ;;
	N)
	   Netmask=$OPTARG
	   ;;
        V)
	   Vlan=$OPTARG
	   ;;
	\?)
	   echo ""
	   ;;
    esac
done

# all options with args are required.  exit otherwise.
if [[ -z "$Ipaddr" || -z "$Gateway" || -z "$Netmask" || -z "$Vlan" ]]; then
    usage
    exit 1
fi

cd /etc/sysconfig/network-scripts

mv ifcfg-$FirstNIC /tmp 2>&1 >/dev/null
mv ifcfg-$SecondNIC /tmp 2>&1 >/dev/null
mv ifcfg-bond0 /tmp 2>&1 >/dev/null
mv ifcfg-bond0.$Vlan /tmp 2>&1 >/dev/null

echo "Writing out ifcfg-$FirstNIC..."
cat << EOF > ifcfg-$FirstNIC
BOOTPROTO="none"
DEVICE="$FirstNIC"
HWADDR="$FirstNICMAC"
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
NM_CONTROLLED=no
MASTER=bond0
SLAVE=yes
EOF

echo "Writing out ifcfg-$SecondNIC..."
cat << EOF > ifcfg-$SecondNIC
BOOTPROTO="none"
DEVICE="$SecondNIC"
HWADDR="$SecondNICMAC"
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
NM_CONTROLLED=no
MASTER=bond0
SLAVE=yes
EOF

echo "Writing out ifcfg-bond0..."
cat << EOF > ifcfg-bond0
BOOTPROTO="none"
DEVICE="bond0"
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
DEFROUTE=no
TYPE=Bond
BONDING_OPTS="$BondOpts"
BONDING_MASTER=yes
NM_CONTROLLED=no
EOF

echo "Writing out ifcfg.bond0.$Vlan..."
cat << EOF > ifcfg-bond0.$Vlan
BOOTPROTO="none"
IPADDR="$Ipaddr"
NETMASK="$Netmask"
GATEWAY="$Gateway"
DEVICE="bond0.$Vlan"
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
VLAN=yes
NM_CONTROLLED=no
EOF

echo "Please make sure to restart network services for the new config to take place."
echo "Original files (if there were any) should be in /tmp."
