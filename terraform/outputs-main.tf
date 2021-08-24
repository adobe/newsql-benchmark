# Write the ansible inventory file
data "template_file" "ansible_inventory_main" {
  template = "[as]\n$${as_ips}\n\n[as_dns]\n$${as_dns}\n\n[as_private]\n$${as_private_ips}\n\n[loadgen]\n$${loadgen_ips}\n\n[loadgen_dns]\n$${loadgen_dns}\n\n[loadgen_private]\n$${loadgen_private_ips}"

  vars = {
    as_ips = join("\n", slice(azurerm_public_ip.publicip_db_cluster.*.ip_address, 0, local.ascluster["vm_count"]))
    as_dns = join("\n", slice(azurerm_public_ip.publicip_db_cluster.*.fqdn, 0, local.ascluster["vm_count"]))
    as_private_ips = join("\n", slice(azurerm_network_interface.nic_db_cluster.*.private_ip_address, 0, local.ascluster["vm_count"]))

    loadgen_ips	= join("\n", slice(azurerm_public_ip.publicip_loadgen_cluster.*.ip_address, 0, local.loadgencluster["vm_count"]))
    loadgen_dns	= join("\n", slice(azurerm_public_ip.publicip_loadgen_cluster.*.fqdn, 0, local.loadgencluster["vm_count"]))
    loadgen_private_ips	= join("\n", slice(azurerm_network_interface.nic_loadgen_cluster.*.private_ip_address, 0, local.loadgencluster["vm_count"]))
  }
}
resource "local_file" "ansible_inventory" {
  depends_on 		= [azurerm_public_ip.publicip_db_cluster]
  content    		= data.template_file.ansible_inventory_main.rendered
  filename   		= "../ansible/inventory.yaml"
  file_permission	= "0755"
}

#Write ansible vars file for common role
resource "local_file" "ansible_vars" {
  content    		= "real_user: ${var.admin_username}\nreplication_factor: ${local.ascluster["replication_factor"]}\nmemory_size: '${local.ascluster["db_node_mem"]}'\nmanaged_disk_size: '${local.ascluster["disk_size_tb"]}'\ndisks_per_vm: ${local.ascluster["disks_per_vm"]}"
  filename   		= "../ansible/roles/common/vars/tf-vars.yaml"
  file_permission	= "0755"
}