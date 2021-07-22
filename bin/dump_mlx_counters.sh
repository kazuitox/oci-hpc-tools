#!/bin/bash
PATH=/bin:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/opt/ibutils/bin:/opt/oci-hpc/bin
#
# FIXME: HACK WARNING:
# either deprecate EXADATA FW and get rid of interface renaming, or change this tool to accept port numer as well, or interface name.
# right now it only works because we just grep for Up interfaces.
#
# arg1: mlx5_0 or mlx5_1
case $# in
	0)
		MLX_DEV="mlx5_0"
		;;
	1)
		MLX_DEV="$1"
		;;
	*)
		echo $0: usage: $0 '[mlx5_0|mlx5_1]'
		exit 1
		;;
esac
case "$MLX_DEV" in
"mlx5_0"|"mlx5_1")
	;;
*)
	echo $0: usage: $0 '[mlx5_0|mlx5_1]'
	exit 1
esac
DEV_PORT=`ibdev2netdev | grep Up | grep $MLX_DEV | awk '{ print $3; }'`
ETH_DEV=`ibdev2netdev | grep Up | grep $MLX_DEV | awk '{ print $5; }'`
if [ "$ETH_DEV" == "" ]
then
	echo $0: ERROR: invalid MLX_DEV=$MLX_DEV
	exit 1
fi
#
echo '#' $0: MLX_DEV=$MLX_DEV, DEV_PORT=$DEV_PORT, ETH_DEV=$ETH_DEV
#
# hw_counters
#
hw_counters=" \
duplicate_request \
local_ack_timeout_err \
out_of_buffer \
out_of_sequence \
packet_seq_err \
duplicate_request \
rx_read_requests \
rx_write_requests \
np_cnp_sent \
np_ecn_marked_roce_packets \
rp_cnp_handled \
rp_cnp_ignored \
implied_nak_seq_err \
rnr_nak_retry_err \
"
#
# all hw counters
#
#np_cnp_sent                 req_cqe_flush_error         resp_remote_access_errors  rx_read_requests
#np_ecn_marked_roce_packets  req_remote_access_errors    rnr_nak_retry_err          rx_write_requests
#duplicate_request      out_of_buffer               req_remote_invalid_request  rp_cnp_handled
#implied_nak_seq_err    out_of_sequence             resp_cqe_error              rp_cnp_ignored
#lifespan               packet_seq_err              resp_cqe_flush_error        rx_atomic_requests
#local_ack_timeout_err  req_cqe_error               resp_local_length_error     rx_dct_connect
#
hw_path="/sys/class/infiniband/$MLX_DEV/ports/$DEV_PORT/hw_counters"
#
# sw counters
#
sw_counters=" \
port_rcv_data \
port_rcv_packets \
port_rcv_errors \
port_xmit_data \
port_xmit_discards \
port_xmit_packets \
port_xmit_wait \
excessive_buffer_overrun_errors \
port_rcv_remote_physical_errors \
port_rcv_switch_relay_errors \
port_xmit_constraint_errors \
"
#
# all counters
#
# multicast_rcv_packets       port_rcv_remote_physical_errors  port_xmit_wait
# multicast_xmit_packets      port_rcv_switch_relay_errors     symbol_error
# excessive_buffer_overrun_errors  port_rcv_constraint_errors  port_xmit_constraint_errors      unicast_rcv_packets
# link_downed                      port_rcv_data               port_xmit_data                   unicast_xmit_packets
# link_error_recovery              port_rcv_errors             port_xmit_discards               VL15_dropped
# local_link_integrity_errors      port_rcv_packets            port_xmit_packets
#
sw_path=/sys/class/infiniband/$MLX_DEV/ports/$DEV_PORT/counters

eth_counters=" \
	rx_discards_phy \
"
for f in $hw_counters
do
	# echo $0: $f: `cat $hw_path"/"$f`
	__out=`cat $hw_path"/"$f`
	echo "dump_mlx_counters_"$f"="$__out
done
for f in $sw_counters
do
	# echo $0: $f: `cat $sw_path"/"$f`
	__out=`cat $sw_path"/"$f`
	echo "dump_mlx_counters_"$f"="$__out
done
for f in $eth_counters
do
	__out=`ethtool -S $ETH_DEV | fgrep $f | awk '{ print $2; }'`
	echo "dump_mlx_counters_"$f"="$__out
done
