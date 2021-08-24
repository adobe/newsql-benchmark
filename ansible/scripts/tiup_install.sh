#!/bin/sh
tiup uninstall --all
tiup uninstall --self
rm -r /home/fdb/.tiup

curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
export PATH=/home/fdb/.tiup/bin:$PATH
tiup cluster
tiup update --self && tiup update cluster
tiup --binary cluster

tiup cluster deploy tidb-test v4.0.0 /home/fdb/tidb_topology.yaml -y --user fdb -i /home/fdb/.ssh/id_rsa_tf

tiup cluster start tidb-test

sudo apt install mysql-client-core-5.7
