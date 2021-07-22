#!/bin/bash

#
# FIXME: need to do error checking.
#

trap "" SIGINT
trap "" SIGQUIT
trap "" SIGHUP

source /etc/opt/oci-hpc/bashrc/.bashrc
source /etc/opt/oci-hpc/bashrc/.bashrc_config
source /etc/opt/oci-hpc/bashrc/.bashrc_common

PATH=$PATH:/usr/sbin:/usr/local/sbin:/sbin

if [ `id -u` -eq 0 ]
then
	echo $0: must run as regular user.
	exit 1
fi

uninstall_nfsserver() {
	local __nfs_role=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $1; }'`
	local __nfs_server=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $2; }'`
	local __nfs_export=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $3; }'`
	local __nfs_mount=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $4; }'`
	if [ $__nfs_role == "server" ]
	then
		echo $0: `hostname`: uninstall_nfs_server: uninstalling NFS server share $__nfs_export
		remove_line_from_file /etc/sysconfig/nfs root 644 "RPCNFSDCOUNT"
		echo $0: `hostname`: uninstall_nfs_server: sudo /bin/rm -f /etc/exports.d/hpc_nfs_share.exports
		sudo /bin/rm -f /etc/exports.d/hpc_nfs_share.exports
		echo $0: `hostname`: uninstall_nfsclient: stopping NFS services
		sudo systemctl stop rpcbind
		sudo systemctl stop nfs-server
		sudo systemctl stop nfs-lock
		sudo systemctl stop nfs-idmap
		echo $0: `hostname`: uninstall_nfsclient: disabling NFS services
		sudo systemctl disable rpcbind
		sudo systemctl disable nfs-server
		sudo systemctl disable nfs-lock
		sudo systemctl disable nfs-idmap
		echo $0: `hostname`: uninstall_nfs_server: "done" uninstalling NFS server
		#
		# if export is different from the mount, remove rebind
		#
		if [ $__nfs_export != $__nfs_mount ]
		then
			echo $0: `hostname`: "removing $__nfs_export rebind"
			local __nfs_rebind_mounted
			__nfs_rebind_mounted=`mount | grep $__nfs_mount`
			if [ "$__nfs_rebind_mounted" != "" ]
			then
				sudo umount $__nfs_mount
			fi
			remove_line_from_file /etc/fstab root 644 $__nfs_export
			sudo rmdir $__nfs_mount > /dev/null 2>&1
		fi
	fi
}

uninstall_nfsclient() {
	local __nfs_role=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $1; }'`
	local __nfs_server=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $2; }'`
	local __nfs_export=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $3; }'`
	local __nfs_mount=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $4; }'`
	local __nfsclient=`grep $__nfs_mount /etc/fstab`
	if [ $__nfs_role == "client" ]
	then
		echo $0: `hostname`: uninstall_nfsclient: unmounting $__nfs_mount
		local __nfs_mounted
		__nfs_mounted=`mount | grep $__nfs_mount`
		if [ "$__nfs_mounted" != "" ]
		then
			sudo umount $__nfs_mount
			if [ $? -ne 0 ]
			then
				echo $0: `hostname`: ERROR: uninstall_nfsclient: umount $__nfs_mount failed.
				exit 1
			fi
		else
			echo $0: `hostname`: uninstall_nfsclient: $__nfs_mount already unmounted.
		fi
		echo $0: `hostname`: uninstall_nfsclient: "done" unmounting NFS share $__nfs_mount
		remove_line_from_file /etc/fstab root 644 $__nfs_mount
		echo $0: `hostname`: uninstall_nfsclient: stopping NFS services
		sudo systemctl stop rpcbind
		sudo systemctl stop nfs-server
		sudo systemctl stop nfs-lock
		sudo systemctl stop nfs-idmap
		echo $0: `hostname`: uninstall_nfsclient: disabling NFS services
		sudo systemctl disable rpcbind
		sudo systemctl disable nfs-server
		sudo systemctl disable nfs-lock
		sudo systemctl disable nfs-idmap
		echo $0: `hostname`: uninstall_nfsclient: "done" uninstalling NFS client
		sync
	fi
}

main() {
	local __command="$1"
	local __force="no"
	if [ "$__command" == "-f" ]
	then
		__force="yes"
		shift
		__command="$1"
	fi

	case "$__command" in
	"")
		if [ $__force == "no" ]
		then
			echo -n "$0: are you sure you want to uninstall NFS? (yes/no) "
			read answ
			if [ "$answ" != "yes" ]
			then
				echo $0: good bye.
				exit 17
			fi
		fi
		echo $0: uninstalling NFS clients.
		run_on_cluster_nodes.sh /opt/oci-hpc/sbin/hpc_uninstall_nfs.sh uninstall-client
		echo $0: uninstalling NFS server.
		run_on_cluster_nodes.sh /opt/oci-hpc/sbin/hpc_uninstall_nfs.sh uninstall-server
		echo $0: uninstalling NFS complete.
		exit 0
		;;

	"uninstall-client")
		uninstall_nfsclient
		exit 0
		;;

	"uninstall-server")
		uninstall_nfsserver
		exit 0
		;;

	*)
		echo $0: unknown command "$__command"
		exit 1
		;;
	
	esac
}

#
# call main entry point
#
main "$1"
