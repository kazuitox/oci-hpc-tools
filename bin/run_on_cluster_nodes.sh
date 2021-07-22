#!/bin/bash
if [ "$1" == "-nl" ]
then
	NO_LOCAL="true"
	shift
else
	NO_LOCAL="false"
fi

if [ ! -f /etc/opt/oci-hpc/hostfile.tcp ]
then
	echo $0: /etc/opt/oci-hpc/hostfile.tcp needs to be setup in order to run this tool.
	exit 1
fi

__exit_status=0
#
# hostname in /etc/opt/oci-hpc/hostfile.* can be different from actual hostname
#
for h in `cat /etc/opt/oci-hpc/hostfile.tcp`
do
	hostid_h=`ssh -n $h hostid`
	if [ "$hostid_h" == `hostid` ]
	then
		is_local_host="yes"
	else
		is_local_host="no"
	fi
	if [ \( $NO_LOCAL == "true" \) -a \( $is_local_host == "yes" \) ]
	then
		echo $0 ========= nolocal set, skipping localhost $h =========
	else
		echo $0 ========= running $* on $h: =========
		ssh -n $h $*
		__status=$?
		if [ $__status -ne 0 ]
		then
			__exit_status=$__status
			echo $0 ========= WARNING: exit status from $h: $__status =========
		fi
	fi
	echo ''
done

exit $__exit_status
