#!/bin/bash
case "$1" in
tcp)
	HOSTFILE=/etc/opt/oci-hpc/hostfile.tcp
	echo $0: setting up ssh for TCP network
	;;
rdma)
	HOSTFILE=/etc/opt/oci-hpc/hostfile.rdma
	echo $0: setting up ssh for RDMA network
	;;
hosts)
	HOSTFILE=/etc/opt/oci-hpc/hostfile.hosts
	echo $0: setting up ssh for VCN network
	;;
*)
	echo $0: usage: $0: 'tcp|rdma'
	exit 1
esac
RETRIES=5
HOSTS="`cat $HOSTFILE`"
HOSTS="$HOSTS `cat $HOSTFILE  |  sed -e 's/\..*//'`"
for h in $HOSTS
do
	for retry in `seq 1 $RETRIES`
	do
		echo $0: `date` `hostname`: $1: $h: '#'$retry
		ssh -n -o HashKnownHosts=no -o StrictHostKeyChecking=no $h uname -a
		__status=$?
		if [ $__status -ne 0 ]
		then
			echo $0: `date` `hostname`: $1: $h: try '#'$retry: FAILED, retrying.....
			sudo arp -d $h
			sleep 2
		else
			break
		fi
	done
	if [ $__status -ne 0 ]
	then
		echo $0: `date` `hostname`: $1: $h: try '#'$retry: ALL ATTEMPTS FAILED, quitting.....
		exit 13
	fi
done
exit 0
