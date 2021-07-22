#!/bin/bash

if [ `id -u` -ne 0 ]
then
	echo $0: ERROR: must run as root.
	exit 1
fi

check_status() {
	local __status=$1; shift
	local __msg=$*
	if [ $__status -ne 0 ]
	then
		echo $0: ERROR: $__msg: failed with status $__status
		exit $__status
	fi
}

source /etc/opt/oci-hpc/bashrc/.bashrc
source /etc/opt/oci-hpc/bashrc/.bashrc_config
source /etc/opt/oci-hpc/bashrc/.bashrc_common

if [ "$LOCAL_VOLUME_PATH" == "" ]
then
	echo $0: LOCAL_VOLUME_PATH is not set, quitting
	exit 0
fi

echo $0: LOCAL_VOLUME_PATH=$LOCAL_VOLUME_PATH

hpc_install_setup_localdisk() {
	#
	# check if it's mounted
	#
	local __mounted=`mount | grep $LOCAL_DRIVE_P1`
	if [ "$__mounted" != "" ]
	then
		echo $0: local disk $LOCAL_DRIVE_P1 is already setup: $__mounted -- not doing anything
		return
	else
		echo $0: local disk is not mounted
	fi
	if [ -d $LOCAL_VOLUME_PATH ]
	then
		echo $0: local volume $LOCAL_VOLUME_PATH already exists -- not doing anything
		return
	fi
	/bin/rm -rf $LOCAL_VOLUME_PATH
	__status=$?
	check_status $__status 10 "cannot remove $LOCAL_VOLUME_PATH"
	echo $0: $LOCAL_VOLUME_PATH removed.
	remove_line_from_file /etc/fstab root 644 $LOCAL_DRIVE_P1
	echo "$0: setting up local disk. $LOCAL_DRIVE"
	__partitioned=`parted $LOCAL_DRIVE print | grep "Partition Table"`
	__partition_unknown=`echo $__partitioned | grep unknown`
	if [ ! -z "$__partition_unknown" ]
	then
		echo "$0: partitioning $LOCAL_DRIVE as GPT"
		parted $LOCAL_DRIVE mklabel gpt
		__status=$?
		check_status $__status 11 "cannot create GPT partition label on $LOCAL_DRIVE"
	else
		echo "$0: $LOCAL_DRIVE already has a partition type: $__partitioned"
	fi
	sync
	sync
	sync
	#
	# create partition if needed
	#
	__partition_1=`parted $LOCAL_DRIVE print | grep "^ 1 "`
	if [ -z "$__partition_1" ]
	then
		__disk_size=`parted $LOCAL_DRIVE print | grep "^Disk " | awk ' { print $3 }; '`
		#echo __disk_size=$__disk_size
		# convert to MB (assume the disk is several GBs)
		__disk_size=`echo $__disk_size | sed -e 's/GB//'`
		__disk_size=$(($__disk_size * 1000))
		# remove 10 GB just to make sure it fits
		__disk_size=$(($__disk_size - 10000))
		#echo __disk_size=$__disk_size
		echo "$0: creating an xfs partition of $__disk_size MB on $LOCAL_DRIVE"
		parted $LOCAL_DRIVE mkpart primary xfs 16 $__disk_size
		__status=$?
		check_status $__status 12 "cannot create XFS partition on $LOCAL_DRIVE"
		sleep 2
		#
		#
		#
		echo "$0: creating XFS file system on $LOCAL_DRIVE_P1"
		echo mkfs.xfs -f $LOCAL_DRIVE_P1
		mkfs.xfs -f $LOCAL_DRIVE_P1
		__status=$?
		check_status $__status 13 "cannot create XFS file system on $LOCAL_DRIVE_P1"
		sleep 2
	else
		echo "$0: $LOCAL_DRIVE already has an xfs partition: $__partition_1"
	fi
	sleep 2
	echo "$0: creating /etc/fstab entry for $LOCAL_VOLUME_PATH on $LOCAL_DRIVE_P1"
	local __line="$LOCAL_DRIVE_P1  $LOCAL_VOLUME_PATH  xfs  defaults,noatime  0  2"
	echo "$0: $__line"
	append_line_to_file /etc/fstab root 644 $__line
	sleep 2
	#
	# create $LOCAL_VOLUME_PATH and mount
	#
	mkdir -p $LOCAL_VOLUME_PATH
	chown root:root $LOCAL_VOLUME_PATH
	chmod 755 $LOCAL_VOLUME_PATH
	sync
	sync
	sync
	echo "$0: mounting $LOCAL_DRIVE_P1 on $LOCAL_VOLUME_PATH"
	mount $LOCAL_VOLUME_PATH
	__status=$?
	check_status $__status 14 "cannot mount $LOCAL_DRIVE_P1 on $LOCAL_VOLUME_PATH"
	echo "$0: mounted $LOCAL_DRIVE_P1 on $LOCAL_VOLUME_PATH"
	sleep 2
	df $LOCAL_VOLUME_PATH
	chown $INSTALL_USER:$INSTALL_USER $LOCAL_VOLUME_PATH
	__status=$?
	check_status $__status 15 "cannot chown $LOCAL_VOLUME_PATH on $LOCAL_DRIVE_P1"
	#
	# all done
	#
}

__localvolume_mounted=`mount | grep $LOCAL_VOLUME_PATH`
__localvolume_fstab=`grep $LOCAL_VOLUME_PATH /etc/fstab`
__setup_localdisk="no"
if [ "$__localvolume_mounted" == "" ]
then
	echo $0: $LOCAL_VOLUME_PATH not mounted, need to setup localdisk.
	__setup_localdisk="yes"
fi
if [ "$__localvolume_fstab" == "" ]
then
	echo $0: $LOCAL_VOLUME_PATH not in /etc/fstab, need to setup localdisk.
	__setup_localdisk="yes"
fi
if [ "$__setup_localdisk" == "yes" ]
then
	echo $0: need to setup localdisk for $LOCAL_VOLUME_PATH mount.
	hpc_install_setup_localdisk
	echo $0: done setup localdisk for $LOCAL_VOLUME_PATH mount.
else
	echo $0: no need to setup localdisk for $LOCAL_VOLUME_PATH mount.
fi

exit 0
