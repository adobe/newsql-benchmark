# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

variable "override_ascluster_map" {
  type = map(string)
  default = {}
}

variable "override_loadgencluster_map" {
  type = map(string)
  default = {}
}

locals {
  default_ascluster_map = {
    "vm_type"         = "Standard_L8s_v2"
    "vm_count"        = "0"
    "disks_per_vm"    = "0"
    //"disk_type"       = "StandardSSD_LRS"
    "disk_type"       = "Premium_LRS"
    //"disk_type"       = "UltraSSD_LRS"
    //"disk_iops_read_write" = "5000"
    //"disk_mbps_read_write" = "500"
    "disk_size_gb"    = "1024"
    "disk_size_tb"    = "1T"
    "db_node_mem"     = "120G"
    "replication_factor" = "3"
  }
  ascluster = merge(local.default_ascluster_map, var.override_ascluster_map)

  default_loadgencluster_map = {
    "vm_type"  = "Standard_F8s_v2"
    "vm_count" = "0"
  }
  loadgencluster = merge(local.default_loadgencluster_map, var.override_loadgencluster_map)
}

output "debug1" {
  value = local.ascluster
}

output "debug2" {
  value = var.override_ascluster_map
}

variable "enable_ultra_ssd" {
  type    = string
  default = "false"
}
