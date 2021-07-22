#!/bin/bash
# see https://hpcadvisorycouncil.atlassian.net/wiki/spaces/HPCWORKS/pages/156237831/How+to+set+up+IntelMPI+over+RoCEv2


if [ $# -ne 2 ]
then
	echo $0: usage: $0: testname nodes
	echo '       testname = pingpong|pingping|sendrecv|exchange|allreduce|reduce|reduce_scatter|allgather|allgatherv|gather|gatherv|scatter|scatterv|alltoall|alltoallv|bcast|barrier|all'
	exit 1
fi
mpitest="$1"
nodes="$2"

#
# source bashrc file for intelmpi
#
source /etc/opt/oci-hpc/bashrc/.bashrc_intelmpi

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

if [ "$nodes" == "all" ]
then
	nodes=$num_hosts
fi
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

echo $0: ================ $nodes nodes =================
CMD="mpirun -ppn 1 \
	-n $nodes \
	-f $hpc_hosts_file \
	$MPI_INTERFACE_OPTIONS \
	$MPI_DEBUG_OPTIONS \
	$MPI_CPU_BINDING_OPTIONS \
	$MPI_ROOT/intel64/bin/IMB-MPI1 \
	$mpitest"
echo $CMD
$CMD
