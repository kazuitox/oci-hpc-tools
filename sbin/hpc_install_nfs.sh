#!/bin/bash

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

# [opc@hpc-rackf2-01-ol75 ~]$ ssh hpc-cluster-node-01 /opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json 
# server nfs-server.local.vcn
# [opc@hpc-rackf2-01-ol75 ~]$ ssh hpc-cluster-node-02 /opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json 
# client nfs-server.local.vcn
# [opc@hpc-rackf2-01-ol75 ~]$ ifconfig eno2 | grep "inet "
#         inet 10.0.1.77  netmask 255.255.255.0  broadcast 10.0.1.255
# [opc@hpc-rackf2-01-ol75 ~]$ ifconfig eno2 | grep "inet " | awk '{print $2;}'
# 10.0.1.77
# [opc@hpc-rackf2-01-ol75 ~]$ ifconfig eno2 | grep "inet " | awk '{print $4;}'
# 255.255.255.0

install_nfsserver() {
	local __nfs_role=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $1; }'`
	local __nfs_server=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $2; }'`
	local __nfs_export=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $3; }'`
	local __nfs_mount=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $4; }'`
	echo $0: `hostname`: nfs_role=$__nfs_role, nfs_server=$__nfs_server
	if [ $__nfs_role == "server" ]
	then
		#
		# FIXME: need to add it only if it does not exist yet
		#
		local __export_options="rw,sync,no_root_squash,no_all_squash,no_subtree_check,insecure_locks"
		sudo mkdir -p $__nfs_export
		sudo chmod 775 $__nfs_export
		sudo chown opc:opc $__nfs_export
		if [ $__nfs_export != $__nfs_mount ]
		then
			echo $0: `hostname`: "$__nfs_export is different from $__nfs_mount, creating $__nfs_mount"
			sudo mkdir -p $__nfs_mount
			sudo chmod 775 $__nfs_mount
			sudo chown opc:opc $__nfs_mount
		fi
		local __subnet_ip=`ifconfig eno2 | grep "inet " | awk '{print $2;}'`
		local __subnet_mask=`ifconfig eno2 | grep "inet " | awk '{print $4;}'`
		echo $0: `hostname`: install_nfsserver: exporting $__nfs_server:$__nfs_export to $__subnet_ip/$__subnet_mask
		#
		# create nfs export share
		#
		# FIXME: could not get exportfs to work ......
		#
		#echo sudo exportfs -av -o $__export_options $SERVER_SUBNET:$__nfs_export
		#sudo exportfs -av -o $__export_options $SERVER_SUBNET:$__nfs_export
		local __exports_file=/etc/exports.d/hpc_nfs_share.exports
		sudo /bin/rm -f $__exports_file
		sudo touch $__exports_file
		local __exports_line="$__nfs_export   $__subnet_ip/$__subnet_mask($__export_options)"
		append_line_to_file $__exports_file root 644 $__exports_line
		#
		# set nfsd threads to 64
		#
		echo $0: `hostname`: install_nfsserver: setting up NFS threads to 64
		remove_line_from_file /etc/sysconfig/nfs root 644 "RPCNFSDCOUNT"
		append_line_to_file /etc/sysconfig/nfs root 644 "RPCNFSDCOUNT=64"
		#
		# enable services
		#
		echo $0: `hostname`: install_nfsserver: enable NFS services
		sudo systemctl enable rpcbind
		sudo systemctl enable nfs-server
		sudo systemctl enable nfs-lock
		sudo systemctl enable nfs-idmap
		sleep 1
		#
		# (re)start services
		#
		echo $0: `hostname`: install_nfsserver: re-starting NFS services
		sudo systemctl restart rpcbind
		sudo systemctl restart nfs-server
		sudo systemctl restart nfs-lock
		sudo systemctl restart nfs-idmap
		echo -n $0: `hostname`: install_nfsserver: waiting for services
		sleep 1; echo -n '.'
		sleep 1; echo -n '.'
		sleep 1; echo -n '.'
		echo ''
		#
		# if export is different from the mount, create a rebind
		#
		if [ $__nfs_export != $__nfs_mount ]
		then
			echo $0: `hostname`: "$__nfs_export is different from $__nfs_mount, creating re-bind mount"
			local __rebind_fstab="$__nfs_export $__nfs_mount none bind"
			append_line_to_file /etc/fstab root 644 $__rebind_fstab
			echo $0: `hostname`: "$__nfs_export is different from $__nfs_mount, mounting re-bind mount"
			sudo mount $__nfs_mount
		fi
		echo $0: `hostname`: install_nfsserver: "done" installing NFS server
	fi
}

install_nfsclient() {
	local __nfs_role=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $1; }'`
	local __nfs_server=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $2; }'`
	local __nfs_export=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $3; }'`
	local __nfs_mount=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $4; }'`
	echo $0: `hostname`: nfs_role=$__nfs_role, nfs_server=$__nfs_server
	if [ $__nfs_role == "client" ]
	then
		#
		# FIXME: need to add it only if it does not exist yet
		#
		echo $0: `hostname`: mounting NFS share $__nfs_server:$__nfs_mount
		sleep 1
		sudo mkdir -p $__nfs_mount
		sudo chmod 775 $__nfs_mount
		sudo chown opc:opc $__nfs_mount
		#
		echo $0: `hostname`: enabling NFS services
		sudo systemctl enable rpcbind
		sudo systemctl enable nfs-server
		sudo systemctl enable nfs-lock
		sudo systemctl enable nfs-idmap
		echo $0: `hostname`: re-starting NFS services
		sudo systemctl restart rpcbind
		sudo systemctl restart nfs-server
		sudo systemctl restart nfs-lock
		sudo systemctl restart nfs-idmap
		echo -n $0: `hostname`: waiting for services
		sleep 1; echo -n '.'
		sleep 1; echo -n '.'
		sleep 1; echo -n '.'
		echo ''
		#
		# FIXME: need to add it only if it does not exist yet
		#
		__rsize=$((1024 * 1024))
		__wsize=$((1024 * 1024))
		local __nfs_mount_opts="defaults,noatime"
		__nfs_mount_opts="$__nfs_mount_opts,bg"
		# downsize of a long attribute cache timeout is eventual consistency, but files are mostly read-only anyway,
		# and writes by HPC applications are done to very large files by specific nodes, so should be ok.
		__nfs_mount_opts="$__nfs_mount_opts,timeo=100,ac,actimeo=120,nocto"
		__nfs_mount_opts="$__nfs_mount_opts,rsize=$__rsize,wsize=$__wsize"
		__nfs_mount_opts="$__nfs_mount_opts,nolock,local_lock=none,mountproto=tcp,sec=sys"
		local __fstab_line="$__nfs_server:$__nfs_export     $__nfs_mount      nfs $__nfs_mount_opts 0 0"
		append_line_to_file /etc/fstab root 644 $__fstab_line
		#
		# FIXME: need to have subrooutines to insert/remove lines from files
		#
		echo "$0: `hostname`: bg mounting NFS share $__nfs_mount"
		sudo mount -a
		sleep 1
		echo $0: `hostname`: "done" bg mounting NFS share $__nfs_server:$__nfs_mount
		mount | grep nfs
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
			echo -n "$0: are you sure you want to install NFS? (yes/no) "
			read answ
			if [ "$answ" != "yes" ]
			then
				echo $0: good bye.
				exit 17
			fi
		fi
		#
		echo $0: installing NFS server.
		run_on_cluster_nodes.sh /opt/oci-hpc/sbin/hpc_install_nfs.sh install-server
		echo $0: installing NFS clients.
		run_on_cluster_nodes.sh /opt/oci-hpc/sbin/hpc_install_nfs.sh install-client
		echo $0: installing NFS complete.
		exit 0
		;;

	"install-client")
		install_nfsclient
		exit 0
		;;

	"install-server")
		install_nfsserver
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
