#!/bin/bash
# /bin/echo -e "# baseimage\tbaseimage_version\tprovisioned\tprovision_version\tconfig_api_version"
if [ -r /etc/opt/oci-hpc/oracle-hpc-baseimage-version ]
then
	HPC_BASE_IMAGE="yes"
	HPC_BASE_IMAGE_VERSION=`cat /etc/opt/oci-hpc/oracle-hpc-baseimage-version`
else
	HPC_BASE_IMAGE="no"
	HPC_BASE_IMAGE_VERSION="unknown"
fi
if [ -r /etc/opt/oci-hpc/oracle-hpc-provision-version ]
then
	HPC_PROVISION="yes"
	HPC_PROVISION_VERSION=`cat /etc/opt/oci-hpc/oracle-hpc-provision-version`
else
	HPC_PROVISION="no"
	HPC_PROVISION_VERSION="unknown"
fi
if [ -x /opt/oci-hpc/sbin/hpc_cluster_provision.py ]
then
	CONFIG_API_VERSION=`/opt/oci-hpc/sbin/hpc_cluster_provision.py get-api-version`
else
	CONFIG_API_VERSION="unknown"
fi
/bin/echo -e "$HPC_BASE_IMAGE\t$HPC_BASE_IMAGE_VERSION\t$HPC_PROVISION\t$HPC_PROVISION_VERSION\t$CONFIG_API_VERSION"
