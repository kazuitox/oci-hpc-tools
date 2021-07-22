#!/bin/bash

#
# source bashrc file for openmpi3
#
source /etc/opt/oci-hpc/bashrc/.bashrc_config
source /etc/opt/oci-hpc/bashrc/.bashrc_openmpi3

usage() {
	echo $0: "usage: $0 [-c] [-l|-b]"
	echo '  -h : prints help'
	echo '  -c : displays results in a compact table'
	echo '  -l : tests latency using 64 bytes messages (default)'
	echo '  -b : tests bandwidth using 4 Mbytes messages'
	exit $1
}

opts=`getopt -o hclb -- $@`
if [ $? -ne 0 ]
then
	usage 1
fi

test_latency="yes"
compact="no"
while true
do
	case "$1" in
	-h)
		usage 0
		shift
		;;
	-c)
		compact="yes"
		shift
		;;
	-l)
		test_latency="yes"
		shift
		;;
	-b)
		test_latency="no"
		shift
		;;
	--)
		shift
		;;
	"")
		break
		;;
	*)
		echo $0: INTERNAL ERROR: unknown option "$1"
		exit 3
		;;
	esac
done

if [ ! -d "$NFS_MOUNT_PATH" ]
then
	echo $0: ERROR: "NFS_MOUNT_PATH $NFS_MOUNT_PATH is not set or does not exist: don't know where the shared file system is"
fi

mkdir -p $NFS_MOUNT_PATH"/tmp/"

#
# get hostfile
#
hpc_hosts_file=/etc/opt/oci-hpc/hostfile
#echo $0: ==== $hpc_hosts_file ===
#cat $hpc_hosts_file
HPC_HOSTS=`cat $hpc_hosts_file`

#
# count how many hosts we have
#
num_hosts=`wc $hpc_hosts_file | awk ' { print $1; } '`
#echo $0: num_hosts=$num_hosts

if [ $num_hosts -lt 2 ]
then
	echo $0: cannot run this test, minimum number of nodes is 2
	exit 3
fi

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

pingpong_test() {
	local __src_node=$1
	local __dst_node=$2
	local __msglenfile=$3
	local __msglen=$4
	local __iter=$5
	local __nodes=2
	local __ppn=1
	local __ranks=$(($__nodes * $__ppn))
	local __rankfile=$NFS_MOUNT_PATH/tmp/rankfile_openmpi3.$$-$__nodes-$__ppn-$__ranks
	/bin/rm -f $__rankfile
	echo "rank 0=$__src_node slot=0" >> $__rankfile
	echo "rank 1=$__dst_node slot=0" >> $__rankfile
	# cat $__rankfile

	CMD="mpirun \
		$MPI_FLAGS \
		-np $__ranks \
		--hostfile $hpc_hosts_file \
		--rankfile $__rankfile \
		$MPI_ROOT/tests/imb/IMB-MPI1 \
		-msglen $__msglenfile -iter $__iter pingpong"
	$CMD | grep "   $__msglen   "

	/bin/rm -f $__rankfile
}

/bin/rm -f $NFS_MOUNT_PATH/tmp/msglen.64.$$
/bin/rm -f $NFS_MOUNT_PATH/tmp/msglen.4194304.$$
echo 64 > $NFS_MOUNT_PATH/tmp/msglen.64.$$
echo 4194304 > $NFS_MOUNT_PATH/tmp/msglen.4194304.$$


for src_node in $HPC_HOSTS
do
	for dst_node in $HPC_HOSTS
	do
		if [ "$compact" != "yes" ]
		then
			echo -n "$src_node ---> $dst_node: "
		fi
		if [ $src_node == $dst_node ]
		then
			if [ "$compact" == "yes" ]
			then
				echo -n "-   "
			else
				echo "- -"
			fi
			continue
		fi
		if [ "$test_latency" == "yes" ]
		then
			out=`pingpong_test $src_node $dst_node $NFS_MOUNT_PATH/tmp/msglen.64.$$ 64 2000`
			if [ "$compact" == "yes" ]
			then
				echo -n `echo $out | awk ' { print $3; } '` "   "
			else
				echo $out | awk ' { print $3, $4; } '
			fi
		else
			out=`pingpong_test $src_node $dst_node $NFS_MOUNT_PATH/tmp/msglen.4194304.$$ 4194304 20`
			if [ "$compact" == "yes" ]
			then
				echo -n `echo $out | awk ' { print $4; } '` "   "
			else
				echo $out | awk ' { print $3, $4; } '
			fi
		fi
	done
	if [ "$compact" == "yes" ]
	then
		echo ''
	fi
done


/bin/rm -f $NFS_MOUNT_PATH/tmp/msglen.64.$$
/bin/rm -f $NFS_MOUNT_PATH/tmp/msglen.4194304.$$
