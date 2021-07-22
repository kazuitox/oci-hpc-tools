#!/bin/bash

#
# NOTE: OpenMpi3 does not let you override the fabric.
# To run TCP tests, you need to disable the RDMA fabric.
#

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

# mpirun --display-map -d -mca mtl ^mxm -mca btl tcp,self --mca btl_base_verbose 30 --mca btl_tcp_if_include 10.0.1.0/24 --mca oob_tcp_if_include 10.0.1.0/24 --mca oob_tcp_disable_family IPv6 -x HCOLL_ENABLE_MCAST_ALL=0 -mca coll_hcoll_enable 0 --cpu-set 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35 -np 2 --hostfile ./hostfile.tcp --rankfile ./rankfile_openmpi3-2 /usr/mpi/gcc/openmpi-3.1.1rc1/tests/imb/IMB-MPI1 pingpong

#
# get hostfile
#
hpc_hosts_file=/etc/opt/oci-hpc/hostfile.tcp
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

# mpirun --display-map -d -mca mtl ^mxm -mca btl tcp,self --mca btl_base_verbose 30 --mca btl_tcp_if_include 10.0.1.0/24 --mca oob_tcp_if_include 10.0.1.0/24 --mca oob_tcp_disable_family IPv6 -x HCOLL_ENABLE_MCAST_ALL=0 -mca coll_hcoll_enable 0 --cpu-set 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35 -np 2 --hostfile ./hostfile.tcp --rankfile ./rankfile_openmpi3-2 /usr/mpi/gcc/openmpi-3.1.1rc1/tests/imb/IMB-MPI1 pingpong

interface="eno2"
#__MPI_FLAGS_TRANSPORT="-d -mca btl tcp,self --mca btl_base_verbose 30 --mca btl_tcp_if_include $interface --mca oob_tcp_if_include $interface --mca oob_tcp_disable_family IPv6 -x HCOLL_ENABLE_MCAST_ALL=0 -mca coll_hcoll_enable 0"
__MPI_FLAGS_TRANSPORT="-mca btl tcp,self --mca btl_tcp_if_include $interface --mca oob_tcp_if_include $interface --mca oob_tcp_disable_family IPv6 -x HCOLL_ENABLE_MCAST_ALL=0 -mca coll_hcoll_enable 0"
__MPI_FLAGS_CPU_SET="--cpu-set $MPI_CPU_SET"
MPI_FLAGS="$__MPI_FLAGS_TRANSPORT $__MPI_FLAGS_CPU_SET"

ranks=$(($nodes * $ppn))
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
