#!/bin/bash
# run on receiving node
if [ `id -u` != 0 ]
then
	echo $0: need to run as root
	exit 1
fi
# use -F to disable CPU freq warning. it's useless, as CPU freq is adjusted dynamically
ib_write_bw -F -d mlx5_0 -p 1 -T 105 -R -x 3 -D 60
