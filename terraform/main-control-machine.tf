# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

# Create public IP for control machine
resource "azurerm_public_ip" "publicip_control_machine" {
  name                = "${var.prefix}-publicip-control-machine"
  domain_name_label   = "${var.prefix}-dn-control-machine"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = local.tags
  zones               = ["1"]
  sku                 = "Standard"
}
resource "local_file" "public_ip_file_control_machine" {
  depends_on = [azurerm_public_ip.publicip_control_machine]
  content    = azurerm_public_ip.publicip_control_machine.ip_address
  filename   = "out/control-machine-ip.txt"
}

# Create network interface
resource "azurerm_network_interface" "nic_control_machine" {
  name                          = "${var.prefix}-nic-control-machine"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enable_accelerated_networking = "true"
  ip_configuration {
    name                          = "${var.prefix}-ipconfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.publicip_control_machine.id
    private_ip_address            = "${var.private_ip_prefix}254"
  }
  tags = local.tags
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc_control_machine" {
  network_interface_id      = azurerm_network_interface.nic_control_machine.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create virtual machine for Aerospike
resource "azurerm_linux_virtual_machine" "controlvm" {
  name                  = "${var.prefix}-controlvm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_control_machine.id]
  size                  = "Standard_F8s_v2"
  zone                  = "1"

  additional_capabilities {
    ultra_ssd_enabled = false
  }

  os_disk {
    name                 = "OsDisk-controlvm"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "${var.prefix}-controlvm"
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.sshprivatekey.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
  }

  tags = local.tags

  # This is to ensure SSH comes up before we run the local exec.
  provisioner "remote-exec" {
    inline = ["echo 'Hello World'"]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.publicip_control_machine.fqdn
      user        = var.admin_username
      private_key = tls_private_key.sshprivatekey.private_key_pem
    }
  }
}
