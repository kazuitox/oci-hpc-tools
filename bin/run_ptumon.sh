#!/bin/bash
if [ `id -u` -ne 0 ]
then
	echo $0: you must be root
	exit 1
fi

cd

if [ ! -f .accepted_intel_ptu_license ]
then
	echo $0: 'you need to accept ptumon terms of use before being able to run this script.'
	echo $0: 'once you have accepted the license, restart this script.'
	echo $0: hit '<CR> to continue and accept ptumon license.'
	read __answ
	/opt/oci-hpc/bin/ptumon -t 1
	exit 0
fi

echo $0: killing existing ptumon, if any
killall -9 ptumon > /dev/null 2>&1

echo $0: starting ptumon
date > /var/log/ptumon.log
nohup /opt/oci-hpc/bin/ptumon >> /var/log/ptumon.log 2>&1 &
