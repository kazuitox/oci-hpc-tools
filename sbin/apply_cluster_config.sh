#!/bin/bash

source /etc/opt/oci-hpc/bashrc/.bashrc_common

# if given,cluster config json must be an absolute path
CLUSTER_CONFIG_JSON=$1
# dir for config file, templates and backup dir
HPC_CONFIG_DIR=/etc/opt/oci-hpc

if [ `id -u` -ne 0 ]
then
	echo $0: ERROR: must run as root
	exit 1
fi

if [ ! -d $HPC_CONFIG_DIR ]
then
	echo $0: $HPC_CONFIG_DIR directory does not exist
	exit 2
fi

if [ "$CLUSTER_CONFIG_JSON" != "" ]
then
	if [ -r $CLUSTER_CONFIG_JSON ]
	then
		echo $0: moving $CLUSTER_CONFIG_JSON to $HPC_CONFIG_DIR/cluster_configuration.json
		/bin/rm -f $HPC_CONFIG_DIR/cluster_configuration.json
		mv $CLUSTER_CONFIG_JSON $HPC_CONFIG_DIR/cluster_configuration.json
		chown root:root $HPC_CONFIG_DIR/cluster_configuration.json
		chmod 644 $HPC_CONFIG_DIR/cluster_configuration.json
	else
		echo $0: ERROR: $CLUSTER_CONFIG_JSON json configuration file does not exist
		exit 3
	fi
fi

cd $HPC_CONFIG_DIR

if [ -f ./cluster_configuration.json ]
then
	echo $0: using cluster configuration file $HPC_CONFIG_DIR/cluster_configuration.json
else
	echo $0: ERROR: cannot find $HPC_CONFIG_DIR/cluster_configuration.json
	exit 4
fi

if [ -f backup/etc.hosts ]
then
	echo $0: $HPC_CONFIG_DIR/backup/etc.hosts already exists
else
	echo $0: copying original /etc/hosts to $HPC_CONFIG_DIR/backup/etc.hosts
	/bin/cp -f /etc/hosts backup/etc.hosts
fi

PROVISIONED=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-local-node-provisioned cluster_configuration.json`
__status=$?
if [ $__status -ne 0 ]
then
	echo $0: ERROR: /opt/oci-hpc/sbin/hpc_cluster_provision.py provisioned cluster_configuration.json: failed with status $__status
	exit $__status
fi
echo $0: PROVISIONED=$PROVISIONED

__current_ip=`/usr/sbin/ifconfig enp94s0f1 | grep "inet " | awk '{ print $2; }'`
if [ "$__current_up" != "" ]
then
        echo $0: removing current RDMA local address $__current_ip from enp94s0f0
        sudo /usr/sbin/ifconfig enp94s0f0 inet del $__current_ip
else
        echo $0: no RDMA local address $__current_ip from enp94s0f0, nothing to remove
fi

if [ "$PROVISIONED" == "deleted" ]
then
	echo $0: local node has been deleted from the cluster
	echo $0: restoring /etc/hosts
	# restore /etc/hosts
	/bin/cp -f backup/etc.hosts /etc/hosts
	# remove hostfile files
	echo $0: removing /etc/opt/oci-hpc/hostfile.tcp
	/bin/rm -f /etc/opt/oci-hpc/hostfile.tcp
	echo $0: removing /etc/opt/oci-hpc/hostfile.rdma
	/bin/rm -f /etc/opt/oci-hpc/hostfile.rdma
	echo $0: removing /etc/opt/oci-hpc/hostfile.hosts
	/bin/rm -f /etc/opt/oci-hpc/hostfile.hosts
	echo $0: removing /etc/opt/oci-hpc/hostfile
	/bin/rm -f /etc/opt/oci-hpc/hostfile
	#
	echo $0: setting up RDMA network with default template for interface enp94s0f0
	# just overwrite the icfg file with the template which has the default unusable address
	# /bin/cp -f templates/ifcfg-enp94s0f0 /etc/sysconfig/network-scripts/ifcfg-enp94s0f0
	/bin/rm -f /etc/sysconfig/network-scripts/ifcfg-enp94s0f0
	# bring down and back up the interface
	echo $0: ifdown enp94s0f0
	/usr/sbin/ifdown enp94s0f0
	sleep 2
	echo $0: ifup enp94s0f0
	/usr/sbin/ifup enp94s0f0
	sleep 2
	echo $0: all changes for local node deletion have been applied
	sync
	exit 0
fi

RDMA_IP_SUBNET_MASK=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-local-rdma-ip-subnet-mask cluster_configuration.json`
RDMA_IP_ADDRESS=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-local-rdma-ip-address cluster_configuration.json`
echo $0: RDMA_IP_ADDRESS=$RDMA_IP_ADDRESS, RDMA_IP_SUBNET_MASK=$RDMA_IP_SUBNET_MASK

echo $0: applying IP configuration to interface enp94s0f0
# just overwrite the icfg file and edit it in place
/bin/cp -f templates/ifcfg-enp94s0f0 /etc/sysconfig/network-scripts/ifcfg-enp94s0f0
UUID=`cat /proc/sys/kernel/random/uuid`
sed \
	-e "s/IPADDR=.*/IPADDR=$RDMA_IP_ADDRESS/" \
	-e "s/NETMASK=.*/NETMASK=$RDMA_IP_SUBNET_MASK/" \
	-e "s/UUID=.*/UUID=\"$UUID\"/" \
	-i /etc/sysconfig/network-scripts/ifcfg-enp94s0f0
cat /etc/sysconfig/network-scripts/ifcfg-enp94s0f0
# bring down and back up the interface
echo $0: ifdown enp94s0f0
/usr/sbin/ifdown enp94s0f0
sleep 2
echo $0: ifup enp94s0f0
/usr/sbin/ifup enp94s0f0
sleep 2
sync
echo $0: all changes for local node RDMA IP have been applied
echo ''

echo $0: generating /etc/hosts
tmp_etc_hosts=/tmp/etc.hosts.$$
rm -f $tmp_etc_hosts
cat backup/etc.hosts >> $tmp_etc_hosts
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-etchosts-nfs cluster_configuration.json >> $tmp_etc_hosts
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-etchosts cluster_configuration.json >> $tmp_etc_hosts
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-etchosts-rdma cluster_configuration.json >> $tmp_etc_hosts
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-etchosts-vcn cluster_configuration.json >> $tmp_etc_hosts
chown root:root $tmp_etc_hosts
chmod 644 $tmp_etc_hosts
cat $tmp_etc_hosts
mv $tmp_etc_hosts /etc/hosts
echo ''
sync

generate_hostfile() {
	local __hostfile=$1
	local __cmd=$2
	echo $0: generating $__hostfile
	rm -f $__hostfile
	/opt/oci-hpc/sbin/hpc_cluster_provision.py $__cmd cluster_configuration.json | grep -v '#' | awk '{ print $2; }' >> $__hostfile
	chown root:root $__hostfile
	chmod 444 $__hostfile
	cat $__hostfile
	echo ''
	sync
}


# when we support tcp only, this will be a conditional
generate_hostfile /etc/opt/oci-hpc/hostfile.rdma get-etchosts-rdma

generate_hostfile /etc/opt/oci-hpc/hostfile.tcp get-etchosts-vcn

# when we support tcp only, this will be a conditional
ln -s /etc/opt/oci-hpc/hostfile.rdma /etc/opt/oci-hpc/hostfile

generate_hostfile /etc/opt/oci-hpc/hostfile.hosts get-etchosts

echo $0: installing SSH private key into /home/opc/.ssh/id_rsa
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-ssh-private-key cluster_configuration.json > /home/opc/.ssh/id_rsa
chown opc:opc /home/opc/.ssh/id_rsa
chmod 600 /home/opc/.ssh/id_rsa
echo ''
sync

echo $0: installing SSH public key into /home/opc/.ssh/id_rsa.pub
/opt/oci-hpc/sbin/hpc_cluster_provision.py get-ssh-public-key cluster_configuration.json > /home/opc/.ssh/id_rsa.pub
chown opc:opc /home/opc/.ssh/id_rsa.pub
chmod 600 /home/opc/.ssh/id_rsa.pub
echo ''
sync

echo $0: installing SSH public key into /home/opc/.ssh/authorized_keys
remove_line_from_file /home/opc/.ssh/authorized_keys opc 644 'opc@intra-cluster-key'
cat /home/opc/.ssh/id_rsa.pub >> /home/opc/.ssh/authorized_keys

echo $0: setting up .bashrc_config environment
LOCAL_VOLUME_PATH=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-localvolume /etc/opt/oci-hpc/cluster_configuration.json`
remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 LOCAL_VOLUME_PATH
append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export LOCAL_VOLUME_PATH=\"$LOCAL_VOLUME_PATH\""
# none|client|server none|nfs_server export|/dev/null mount|/dev/null
__nfs_configured=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $1; }'`
if [ "$__nfs_configured" != "none" ]
then
	__nfs_export=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $3; }'`
	__nfs_mount=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-nfs-server-config /etc/opt/oci-hpc/cluster_configuration.json | awk '{ print $4; }'`
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_CONFIGURED
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_EXPORT_PATH
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_MOUNT_PATH
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_CONFIGURED=\"yes\""
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_EXPORT_PATH=\"$__nfs_export\""
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_MOUNT_PATH=\"$__nfs_mount\""
else
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_CONFIGURED
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_EXPORT_PATH
	remove_line_from_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 NFS_MOUNT_PATH
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_CONFIGURED=\"no\""
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_EXPORT_PATH=\"\""
	append_line_to_file /etc/opt/oci-hpc/bashrc/.bashrc_config root 444 "export NFS_MOUNT_PATH=\"\""
fi

exit 0
