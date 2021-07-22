#!/bin/bash

verify_connectivity() {
	__transport=$1
	__hostfile=$2
	for host in `cat $__hostfile`
	do
		echo -n $__transport: $host: ' '
		ping -c 2 $host 2>&1 > /dev/null
		if [ $? -eq 0 ]
		then
			echo ok
		else
			echo bad
		fi
	done
}

echo $0: verifying connectivity over VCN network....
verify_connectivity "VCN/ICMP" /etc/opt/oci-hpc/hostfile.tcp
echo ''
echo ''

echo $0: verifying connectivity over RDMA network....
verify_connectivity "RDMA/ICMP" /etc/opt/oci-hpc/hostfile.rdma
echo ''
echo ''

echo $0: verifying connectivity over VCN network using original hostnames....
verify_connectivity "RDMA/ICMP" /etc/opt/oci-hpc/hostfile.hosts
echo ''
echo ''
