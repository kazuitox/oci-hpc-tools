#!/bin/bash


if [ $# -ne 2 ]
then
	echo $0: usage: $0: 'ping|flood|jlink|dgemm' nodes
	exit 1
fi
mpitest="$1"
nodes="$2"
case "$1" in
ping)
	mpitool_args="-ppr 64"
	;;
flood)
	mpitool_args="-flood 4096"
	;;
jlink)
	mpitool_args="-jlink"
	;;
dgemm)
	mpitool_args="-dgemm"
	;;
*)
	echo $0: usage: $0: 'ping|flood|jlink|dgemm' nodes
	exit 1
	;;
esac

#
# source bashrc file for platformmpi
#
source /etc/opt/oci-hpc/bashrc/.bashrc_platformmpi

#
# get hostfile
#
hpc_hosts_file=/etc/opt/oci-hpc/hostfile
echo $0: ==== $hpc_hosts_file ===
cat $hpc_hosts_file

#
# count how many hosts we have
#
num_hosts=`wc $hpc_hosts_file | awk ' { print $1; } '`
echo $0: num_hosts=$num_hosts

if [ $nodes -lt 2 ]
then
	echo $0: cannot run this test, minimum number of nodes is 2
	exit 3
fi
if [ $nodes -gt $num_hosts ]
then
	echo $0: cannot run this test, requested nodes is $nodes, available nodes is $num_hosts
	exit 3
fi

#
# Platform MPI requires this
#
export MPI_WORKDIR=`/bin/pwd`

for ppn in 1 2
do
	echo $0: ================ $nodes nodes, $ppn ppn =================

	#
	# this bash function generates a rankfile given a hostfile, number of processes, and number of nodes.
	# by using this function there is no need to have a hardcoded rankfile
	#
	__rankfile=./rankfile_platformmpi-$nodes-$ppn
	echo $0: generate_hostfile_rank $hpc_hosts_file $ppn $nodes $__rankfile
	generate_hostfile_rank $hpc_hosts_file $ppn $nodes $__rankfile
	echo $0: == rankfile ==
	ranks=$(($ppn * $nodes))
	CMD="mpirun -d -v -prot -intra=mix \
		-e MPI_FLAGS=$MPI_FLAGS \
		-cpu_bind=$MPI_MAP_CPU_BIND \
		-np $ranks \
		-hostfile $__rankfile \
		-IBV \
		$MPI_ROOT/bin/mpitool $mpitool_args"
	echo $0: $CMD
	$CMD
done
