#!/bin/bash

usage() {
	echo $0: usage: $0 '2018.3'
	exit 1
}

if [ $# != 1 ]
then
	usage
fi
version="$1"

echo ''
echo $0: to install Intel MPI version $version, you need to read and accept the terms of Intel License at
echo ''
echo https://software.intel.com/en-us/articles/end-user-license-agreement
echo ''
echo 'By downloading Intel® Performance Libraries you agree to the terms and conditions stated in the End-User License Agreement (EULA).'
echo ''
echo 'Have you read, and do you agree with, Intel End-User License Agreement (EULA). (No/YeS)'
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

trap - SIGINT
trap - SIGQUIT
trap - SIGSTOP

case "$version" in
2018.3)
	run_on_cluster_nodes.sh sudo yum install -y \
		intel-imb-2018.3-222.x86_64 \
		intel-mkl-2018.3-051.x86_64 \
		intel-mpi-2018.3-051.x86_64 \
		intel-mpi-psxe-2018.3-051.x86_64 \
		intel-mpi-rt-2018.3-222.x86_64 \
		intel-mpi-samples-2018.3-222.x86_64 \
		intel-mpi-sdk-2018.3-222.x86_64
	;;
#2018.4)
#	run_on_cluster_nodes.sh sudo yum install -y \
#		intel-imb-2018.4-274.x86_64 \
#		intel-mkl-2018.4-057.x86_64 \
#		intel-mpi-2018.4-057.x86_64 \
#		intel-mpi-psxe-2018.4-057.x86_64 \
#		intel-mpi-rt-2018.4-274.x86_64 \
#		intel-mpi-samples-2018.4-274.x86_64 \
#		intel-mpi-sdk-2018.4-274.x86_64
#	;;
*)
	usage
	;;
esac
