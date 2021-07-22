#!/bin/bash

if [ $# -ne 2 ]
then
	echo $0: usage: $0: testname nodes
	echo '       testname = pingpong|pingping|sendrecv|exchange|allreduce|reduce|reduce_scatter|allgather|allgatherv|gather|gatherv|scatter|scatterv|alltoall|alltoallv|bcast|barrier|all'
	exit 1
fi
mpitest="$1"
nodes="$2"

#
# source bashrc file for openmpi3
#
source /etc/opt/oci-hpc/bashrc/.bashrc_openmpi3

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

#
# this deserves an explanation. the most specific way to bind threads
# in openmpi3 is to have a rankfile, and bind a specific rank to a specific node and cpu.
# this shell function is in /etc/opt/oci-hpc/bashrc/.bashrc_openmpi3 and given as inputs:
#	hosts_file
#	number_of_nodes
#	processes_per_node
# generates an output
#       rankfile
#
# the use of this shell function avoids the use of hardcoded rankfiles.
#
# for example, if you want to have 2 processes per node and you have 8 nodes,
# you'd need a total of 16 ranks, 2 per node.
# the input would be:
#
#       generate_rank_file_openmpi3 $hpc_hosts_file 8 2 ./rankfile_output
#
# the generated rankfile would be:
#
# rank 0=hpc1-rdma-br1 slot=0
# rank 1=hpc1-rdma-br1 slot=1
# rank 2=hpc2-rdma-br1 slot=0
# rank 3=hpc2-rdma-br1 slot=1
# rank 4=hpc3-rdma-br1 slot=0
# rank 5=hpc3-rdma-br1 slot=1
# rank 6=hpc4-rdma-br1 slot=0
# rank 7=hpc4-rdma-br1 slot=1
# rank 8=hpc7-rdma-br1 slot=0
# rank 9=hpc7-rdma-br1 slot=1
# rank 10=hpc8-rdma-br1 slot=0
# rank 11=hpc8-rdma-br1 slot=1
#

# in this sample app we only have one process per node
ppn=1
ranks=$(($nodes * $ppn))

__rankfile=/tmp/rankfile_openmpi3.$$-$nodes-$ppn-$ranks
echo $0: generate_rank_file_openmpi3 $hpc_hosts_file $nodes $ppn $__rankfile
generate_rank_file_openmpi3 $hpc_hosts_file $nodes $ppn $__rankfile
echo $0: == rankfile ==
cat $__rankfile

CMD="mpirun --display-map \
	$MPI_FLAGS \
	-np $ranks \
	--hostfile $hpc_hosts_file \
	--rankfile $__rankfile \
	$MPI_ROOT/tests/imb/IMB-MPI1 \
	$mpitest"
echo $CMD
$CMD

/bin/rm -f $__rankfile
