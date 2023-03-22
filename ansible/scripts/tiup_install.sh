#!/bin/sh
#
# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

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
