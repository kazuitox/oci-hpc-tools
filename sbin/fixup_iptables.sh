#!/bin/bash
if [ `id -u` -ne 0 ]
then
	echo $0: must run as root
	exit 1
fi

PATH=$PATH:/usr/sbin:/sbin:

ETH_INTF=eno2
RDMA_INTF=enp94s0f0
ETH_INTF_INET=`ip -br -f inet address show dev $ETH_INTF`
if [ "$ETH_INTF_INET" != "" ]
then
	ETH_INTF_SUBNET=`echo $ETH_INTF_INET | awk ' { print $3; } '`
else
	ETH_INTF_SUBNET=""
fi
RDMA_INTF_INET=`ip -br -f inet address show dev $RDMA_INTF`
if [ "$RDMA_INTF_INET" != "" ]
then
	RDMA_INTF_SUBNET=`echo $RDMA_INTF_INET | awk ' { print $3; } '`
else
	RDMA_INTF_SUBNET=""
fi

echo $0: ETH_INTF_SUBNET=$ETH_INTF_SUBNET
echo $0: RDMA_INTF_SUBNET=$RDMA_INTF_SUBNET

__fixup_rule() {
	local __chain=$1; shift
	local __iptables_params="$*"
	/usr/sbin/iptables -D $__chain $__iptables_params > /dev/null 2>&1
	/usr/sbin/iptables -I $__chain $__iptables_params
}

fixup_rule() {
	local __iptables_params="$*"
	__fixup_rule INPUT $*
	__fixup_rule OUTPUT $*
	__fixup_rule FORWARD $*
}

echo $0: `date`: ====== iptables before fixup ======
/usr/sbin/iptables --list INPUT
/usr/sbin/iptables --list OUTPUT
/usr/sbin/iptables --list FORWARD
echo $0: `date`: ====== fixing up iptables ======
if [ "$ETH_INTF_SUBNET" != "" ]
then
	fixup_rule -p all -d $ETH_INTF_SUBNET -j ACCEPT
fi
if [ "$RDMA_INTF_SUBNET" != "" ]
then
	fixup_rule -p all -d $RDMA_INTF_SUBNET -j ACCEPT
fi
echo $0: `date`: ====== iptables after fixup ======
/usr/sbin/iptables --list INPUT
/usr/sbin/iptables --list OUTPUT
/usr/sbin/iptables --list FORWARD
echo $0: `date`: ====== 'done' ======

exit 0
