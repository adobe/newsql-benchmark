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

cd ~
curl -O https://raw.githubusercontent.com/torvalds/linux/master/tools/hv/lsvmbus
python lsvmbus -vv | grep -w "Time Synchronization" -A 3
echo 2dd1ce17-079e-403c-b352-a1921ee207ee | sudo tee /sys/bus/vmbus/drivers/hv_util/unbind
sudo service ntp stop
sudo ntpd -b time.google.com
sudo service ntp start
sudo ntpq -p