#!/bin/bash

#
# NEVER EXECUTE THIS FILE DIRECTLY. DOING SO COULD LEAD TO CORRUPT AND UNUSABLE MELLANOX CX-5.
# ALWAYS USE /opt/oci-hpc/sbin/mlnx_fw_ctl.sh
#

if [ `id -u` -ne 0 ]
then
	echo $0: must run as root.
	exit 1
fi

# hardcoded
PCI_ADDR="5e:00.0"
FW_IMAGES_DIR="/opt/oci-hpc/mellanox-fw/"
CURR_FW_VERSION="16.23.1020"
CURR_FW_CONFIGURATION="$FW_IMAGES_DIR/fw-ConnectX5-rel-16_23_1020-configuration.txt"

check_status() {
	local __status=$1; shift
	local __msg=$*
	if [ $__status -ne 0 ]
	then
		echo $0: ERROR: \"$__msg\" failed with status $__status
		exit $__status
	fi
}

mst_start() {
	mst start > /dev/null 2>&1
	__status=$?
	check_status $? "mst start"
}

set_defaults() {
	#
	mstflint -d $PCI_ADDR query
	__status=$?
	check_status $? "mstflint query"
	#
	echo $0: applying card defaults =============================
	mstconfig -y -d $PCI_ADDR reset
	__status=$?
	check_status $? "mstconfig reset"
	#
	echo $0: applying Mellanox defaults =============================
	mstconfig -y -d $PCI_ADDR set \
		CNP_DSCP_P1=46 CNP_802P_PRIO_P1=6 \
		CNP_DSCP_P2=46 CNP_802P_PRIO_P2=6 \
		MULTI_PORT_VHCA_EN=0 \
		PF_LOG_BAR_SIZE=5 VF_LOG_BAR_SIZE=1 \
		SRIOV_EN=0 NUM_OF_VFS=0
	__status=$?
	check_status $? "mstconfig set"
	echo $0: resetting CX-5 hardware, please wait =============================
	mlxfwreset -y -d $PCI_ADDR -l 3 reset
	__status=$?
	check_status $? "mlxfwreset"
}

show() {
	mstflint -d $PCI_ADDR query
	__status=$?
	check_status $? "mstflint query"
	mstconfig -d $PCI_ADDR query
	__status=$?
	check_status $? "mstconfig query"
}

show_f() {
	mstflint -d $PCI_ADDR query | grep "FW Version"
}

show_s() {
	mstconfig -d $PCI_ADDR query | egrep "CNP_DSCP_P|CNP_802P_PRIO_P|MULTI_PORT_VHCA_EN|PF_LOG_BAR_SIZE|VF_LOG_BAR_SIZE|SRIOV_EN|NUM_OF_VFS" | sort
}

command="$1"
case $command in
set_defaults)
	echo $0: setting Mellanox defaults =============================
	mst_start
	set_defaults
	exit 0
	;;
show)
	echo $0: query settings =============================
	mst_start
	show
	exit 0
	;;
check_update_defaults)
	echo $0: WARNING: TO AVOID POSSIBLE HARDWARE CORRUPTION, DO NOT INTERRUPT THIS COMMAND.
	#
	# FIXME: need to check FW version once we support more than one FW version
	#
	echo $0: checking defaults for FW $CURR_FW_VERSION =============================
	mst_start
	__curr_settings_file=/tmp/mlnx_settings.$$.txt
	show_s > $__curr_settings_file 2>&1
	cmp $CURR_FW_CONFIGURATION $__curr_settings_file
	__status=$?
	if [ $__status == 0 ]
	then
		/bin/rm -f $__curr_settings_file
		echo $0: firmware configuration FW $CURR_FW_VERSION has correct defaults =============================
		show_s
		exit 0
	else
		echo $0: firmware configuration FW $CURR_FW_VERSION does not match defaults, reconfiguring =============================
		diff $CURR_FW_CONFIGURATION $__curr_settings_file
		/bin/rm -f $__curr_settings_file
		set_defaults
		exit 0
	fi
	;;
s)
	mst_start
	show_f
	show_s
	exit 0
	;;
*)
	echo $0: usage: 'set_defaults|check_update_defaults|show|s'
	exit 1
	;;
esac
