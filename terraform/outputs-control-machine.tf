# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

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