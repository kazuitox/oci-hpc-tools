# RDMA で通信していることを確認したい
以下のスクリプトで送受信のデータサイズとパケット数が確認可能。
このスクリプトは計算ノードに負荷が掛かるのでご注意ください。
```
$ cd oci-hpc-tools/bin

# BM.Optimized3.36 の場合
$ ./dump_mlx_periodic.sh 1 mlx5_2
2022年 2月 19日 土曜日 08:34:26 GMT: recv_data=25378781, recv_packets=103318, xmit_data=23817383, xmit_packets=100877
2022年 2月 19日 土曜日 08:34:27 GMT: recv_data=26281714, recv_packets=76186, xmit_data=32492127, xmit_packets=90459
2022年 2月 19日 土曜日 08:34:28 GMT: recv_data=29166371, recv_packets=127388, xmit_data=29066583, xmit_packets=122254

# BM.HPC2.36 の場合
$ ./dump_mlx_periodic.sh 1 mlx5_0
```
