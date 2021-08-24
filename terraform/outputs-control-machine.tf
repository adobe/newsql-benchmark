# Write the ansible inventory file
data "template_file" "ansible_inventory_control_machine" {
  template = "[control]\n$${control_ip}\n\n[control_private_ip]\n$${control_private_ip}\n\n[control_dns]\n$${control_dns}\n\n"
  vars = {
    control_ip = azurerm_public_ip.publicip_control_machine.ip_address
    control_dns = azurerm_public_ip.publicip_control_machine.fqdn
    control_private_ip = azurerm_network_interface.nic_control_machine.private_ip_address
  }
}

resource "local_file" "ansible_inventory_control_machine" {
  depends_on 		= [azurerm_public_ip.publicip_control_machine]
  content    		= data.template_file.ansible_inventory_control_machine.rendered
  filename   		= "../ansible/inventory-cm.yaml"
  file_permission	= "0600"
}