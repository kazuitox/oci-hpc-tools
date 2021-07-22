#!/bin/bash

echo $0: WARNING: this package manager is in BETA. UNINSTALL IS NOT SUPPORTED.

usage() {
	echo $0: usage: $0 'install_2018.3|install_2018.4|install_2019.4'
	exit 1
}

if [ $# != 1 ]
then
	usage
fi
version="$1"

ask_install() {
	echo ''
	echo $0: to install Intel MPI version $version, you need to read and accept the terms of Intel License at
	echo ''
	echo https://software.intel.com/en-us/articles/end-user-license-agreement
	echo ''
	echo 'By downloading Intel® Performance Libraries you agree to the terms and conditions stated in the End-User License Agreement (EULA).'
	echo ''
	echo 'Have you read, and do you agree with, the Intel End-User License Agreement (EULA). (No/YeS)'
	echo -n ': '
	read answ
	if [ "$answ" != "YeS" ]
	then
		echo You need to read and agree to the above terms, and to respond \'YeS\' to this question.
		echo ''
		exit 2
	fi
	echo ''
	echo ''
	echo ''
	echo -n $0: installing Intel MPI version $version, it will take quite a while
	sleep 1 ; echo -n .
	sleep 1 ; echo -n .
	sleep 1 ; echo -n .
	sleep 1 ; echo -n .
	echo ''
}

ask_install_generic() {
	local __install="$*"
	echo ''
	echo 'Are you sure you want to do a' $__install '(No/YeS)'
	echo -n ': '
	read answ
	if [ "$answ" != "YeS" ]
	then
		echo ''
		exit 2
	fi
}

trap - SIGINT
trap - SIGQUIT
trap - SIGSTOP

INTEL_MPI_2018_3_RPMS=" \
	intel-imb-2018.3-222.x86_64 \
	intel-mkl-2018.3-051.x86_64 \
	intel-mpi-2018.3-051.x86_64 \
	intel-mpi-psxe-2018.3-051.x86_64 \
	intel-mpi-rt-2018.3-222.x86_64 \
	intel-mpi-samples-2018.3-222.x86_64 \
	intel-mpi-sdk-2018.3-222.x86_64 \
"

INTEL_MPI_2018_4_RPMS=" \
	intel-imb-2018.4-274.x86_64 \
	intel-mkl-2018.4-057.x86_64 \
	intel-mpi-2018.4-057.x86_64 \
	intel-mpi-psxe-2018.4-057.x86_64 \
	intel-mpi-rt-2018.4-274.x86_64 \
	intel-mpi-samples-2018.4-274.x86_64 \
	intel-mpi-sdk-2018.4-274.x86_64 \
"

INTEL_MPI_2019_4_RPMS=" \
	intel-imb-2019.4-243.x86_64 \
	intel-mkl-2019.4-070.x86_64 \
	intel-mpi-2019.4-070.x86_64 \
	intel-mpi-psxe-2019.4-070.x86_64 \
	intel-mpi-rt-2019.4-243.x86_64 \
	intel-mpi-samples-2019.4-243.x86_64 \
	intel-mpi-sdk-2019.4-243.x86_64 \
"

#erase_all_rpms() {
#	run_on_cluster_nodes.sh sudo yum erase -y $INTEL_MPI_2018_3_RPMS
#	run_on_cluster_nodes.sh sudo yum erase -y $INTEL_MPI_2018_4_RPMS
#	run_on_cluster_nodes.sh sudo yum erase -y $INTEL_MPI_2019_4_RPMS
#}

#local_erase_all_rpms() {
#	sudo yum erase -y $INTEL_MPI_2018_3_RPMS
#	sudo yum erase -y $INTEL_MPI_2018_4_RPMS
#	sudo yum erase -y $INTEL_MPI_2019_4_RPMS
#}

if [ -d /opt/intel ]
then
	echo $0: ERROR: /opt/intel already exists, this tool does not support installing over an existing package.
	exit 3
fi

case "$version" in
install_2018.3)
	ask_install
	#erase_all_rpms
	run_on_cluster_nodes.sh sudo yum install -y $INTEL_MPI_2018_3_RPMS
	;;
#2018.3_local_install)
#	ask_install_generic "local install"
#	#local_erase_all_rpms
#	sudo yum install -y $INTEL_MPI_2018_3_RPMS
#	;;
install_2018.4)
	ask_install
	#erase_all_rpms
	run_on_cluster_nodes.sh sudo yum install -y $INTEL_MPI_2018_4_RPMS
	;;
#2018.4_local_install)
#	ask_local_install "local install"
#	local_erase_all_rpms
#	sudo yum install -y $INTEL_MPI_2018_4_RPMS
#	;;
install_2019.4)
	ask_install
	#erase_all_rpms
	run_on_cluster_nodes.sh sudo yum install -y $INTEL_MPI_2019_4_RPMS
	;;
#2019.4_local_install)
#	ask_install_generic "local install"
#	#local_erase_all_rpms
#	sudo yum install -y $INTEL_MPI_2019_4_RPMS
#	;;
#local_uninstall)
#	ask_install_generic "local uninstall"
#	local_erase_all_rpms
#	;;
#uninstall)
#	ask_install_generic "uninstall"
#	erase_all_rpms
#	;;
*)
	usage
	;;
esac
