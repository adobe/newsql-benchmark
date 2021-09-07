#!/bin/bash

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

sudo pkill -f blkdiscard
sudo pkill -f 'dd if'

echo "Preparing the following SSD devices $1"
for i in "$@"; do {
  cmd="sudo blkdiscard /dev/${i}"
  echo "Command \"$cmd\" started..";
  $cmd & pid=$!
  PID_LIST1+=" $pid";
} done

trap "sudo kill $PID_LIST1" SIGINT
echo "Waiting for blkdiscard to complete";
wait $PID_LIST1
echo
echo "sudo blkdiscard completed.";

for i in "$@"; do {
  cmd="sudo dd if=/dev/zero bs=32M of=/dev/${i}"
  echo "Command \"$cmd\" started..";
  $cmd & pid=$!
  PID_LIST2+=" $pid";
} done

trap "sudo kill $PID_LIST2" SIGINT
echo "Waiting for dd to complete";
wait $PID_LIST2
echo
echo "dd completed.";


