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

#
# here we demo the generation of rankfile for those applications which do not
# specify ppn and need an explicit number of ranks per node
#
__rankfile="./rankfile_intel-$nodes"
generate_hostfile_rank $hpc_hosts_file 1 $nodes $__rankfile
CMD="mpirun -ppn 1 \
	-n $nodes \
	-f $__rankfile \
	-iface $MLNX_INTERFACE_NAME \
	-genv I_MPI_FABRICS=$I_MPI_FABRICS \
	-genv DAT_OVERRIDE=$DAT_OVERRIDE \
	-genv I_MPI_DAT_LIBRARY=$I_MPI_DAT_LIBRARY \
	-genv I_MPI_DAPL_PROVIDER=$I_MPI_DAPL_PROVIDER \
	-genv I_MPI_FALLBACK=0 \
	-genv I_MPI_DEBUG=4 \
	-genv I_MPI_PIN_PROCESSOR_LIST=$I_MPI_PIN_PROCESSOR_LIST \
	-genv I_MPI_PROCESSOR_EXCLUDE_LIST=$I_MPI_PROCESSOR_EXCLUDE_LIST \
	$MPI_ROOT/intel64/bin/IMB-MPI1 \
	$mpitest"
echo $CMD
$CMD
