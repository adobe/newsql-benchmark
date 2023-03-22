# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

# Create public IPs for Aerospike nodes
resource "azurerm_public_ip" "publicip_loadgen_cluster" {
  count               = local.loadgencluster["vm_count"]
  name                = "${var.prefix}-publicip-loadgen-cluster-${count.index}"
  domain_name_label   = "${var.prefix}-dn-loadgen-cluster-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = local.tags
  zones               = [tostring((count.index % 3) + 1)]
  sku                 = "Standard"
}
resource "local_file" "public_ip_file_loadgen_cluster" {
  depends_on = [azurerm_public_ip.publicip_loadgen_cluster]
  content    = join(", ", azurerm_public_ip.publicip_loadgen_cluster.*.ip_address)
  filename   = "out/loadgen-ips.txt"
}

# Create network interface
resource "azurerm_network_interface" "nic_loadgen_cluster" {
  count                         = local.loadgencluster["vm_count"]
  name                          = "${var.prefix}-nic-loadgen-cluster-${count.index}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enable_accelerated_networking = "true"
  ip_configuration {
    name                          = "${var.prefix}-ipconfiguration-loadgen-cluster"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.publicip_loadgen_cluster[count.index].id
    private_ip_address            = "${var.private_ip_prefix}${count.index + var.private_ip_reserved}" # Loadgen node IP start at 10.0.1.10
  }
  tags = local.tags
  depends_on = [azurerm_public_ip.publicip_loadgen_cluster]
}

# Create Network Security rule and associate with NSG
resource "azurerm_network_security_rule" "ssh_rule_control_machine_loadgen" {
  name                        = "ssh_rule_control_machine_loadgen"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = [tostring(azurerm_public_ip.publicip_control_machine.ip_address)]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc_loadgen_cluster" {
  count                     = local.loadgencluster["vm_count"]
  network_interface_id      = azurerm_network_interface.nic_loadgen_cluster.*.id[count.index]
  network_security_group_id = azurerm_network_security_group.nsg.id
}


# Create virtual machine for load generator
resource "azurerm_linux_virtual_machine" "loadgenvm" {
  count                 = local.loadgencluster["vm_count"]
  name                  = "${var.prefix}-loadgen-vm-${count.index}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_loadgen_cluster.*.id[count.index]]
  size                  = local.loadgencluster["vm_type"]
  zone                  = tostring(((count.index) % 3) + 1)

  depends_on = [
    azurerm_network_interface_security_group_association.nic_nsg_assoc_loadgen_cluster
  ]

  additional_capabilities {
    ultra_ssd_enabled = false
  }

  os_disk {
    name = "OsDisk-loadgenvm-${count.index}"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  computer_name = "${var.prefix}-loadgen-vm-${count.index}"
  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = true

  admin_ssh_key {
    username = var.admin_username
    public_key = tls_private_key.sshprivatekey.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
  }

  tags = local.tags

  # This is to ensure SSH comes up before we run the local exec.
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello World'"]

    connection {
      type = "ssh"
      host = azurerm_public_ip.publicip_loadgen_cluster.*.fqdn[count.index]
      user = var.admin_username
      private_key = tls_private_key.sshprivatekey.private_key_pem
    }
  }
}

