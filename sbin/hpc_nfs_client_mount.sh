#!/bin/bash

#
# There is a bug in the nfs bg mount option, in that it just does not work.
# This script is a workaround for it, it runs at boot time and keep trying mount until it succeeds.
#

if [ `id -u` -ne 0 ]
then
	echo $0: must run as root
	exit 0
fi

#
#
#
__fstab_has_nfs_mount=`grep nfs /etc/fstab`
if [ "$__fstab_has_nfs_mount" != "" ]
then
	echo $0: has NFS mount, doing mount -a
	mount -a
else
	echo $0: no NFS mount, not doing anything
fi

exit 0
