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
