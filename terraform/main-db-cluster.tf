# Create public IPs for Aerospike nodes
resource "azurerm_public_ip" "publicip_db_cluster" {
  count               = local.ascluster["vm_count"]
  name                = "${var.prefix}-publicip-db-cluster${count.index}"
  domain_name_label   = "${var.prefix}-dn-db-cluster${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = local.tags
  zones               = [tostring((count.index % 3) + 1)]
  sku                 = "Standard"
}
resource "local_file" "public_ip_file" {
  depends_on = [azurerm_public_ip.publicip_db_cluster]
  content    = join(", ", azurerm_public_ip.publicip_db_cluster.*.ip_address)
  filename   = "out/db-ips.txt"
}

# Create network interface
resource "azurerm_network_interface" "nic_db_cluster" {
  count                         = local.ascluster["vm_count"]
  name                          = "${var.prefix}-nic-db-cluster-${count.index}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enable_accelerated_networking = "true"
  ip_configuration {
    name                          = "${var.prefix}-ipconfiguration-db-cluster"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.publicip_db_cluster[count.index].id
    private_ip_address            = "${var.private_ip_prefix}${count.index + var.private_ip_reserved + 100}" # DBCluster node IP start at 10.0.1.110
  }
  tags = local.tags
}

# Create Network Security rule and associate with NSG
resource "azurerm_network_security_rule" "ssh_rule_control_machine_dbnode" {
  name                        = "ssh_rule_control_machine_dbnode"
  priority                    = 101
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
resource "azurerm_network_interface_security_group_association" "nic-nsg-assoc-db-cluster" {
  count                     = local.ascluster["vm_count"]
  network_interface_id      = azurerm_network_interface.nic_db_cluster.*.id[count.index]
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create virtual machine for Aerospike
resource "azurerm_linux_virtual_machine" "aerovm" {
  count                 = local.ascluster["vm_count"]
  name                  = "${var.prefix}-vm-${count.index}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_db_cluster.*.id[count.index]]
  size                  = local.ascluster["vm_type"]
  zone                  = tostring((count.index % 3) + 1)

  additional_capabilities {
    ultra_ssd_enabled = var.enable_ultra_ssd
  }

  os_disk {
    name                 = "OsDisk-aerovm-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "${var.prefix}-vm-${count.index}"
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
      host        = azurerm_public_ip.publicip_db_cluster.*.fqdn[count.index]
      user        = var.admin_username
      private_key = tls_private_key.sshprivatekey.private_key_pem
    }
  }
}

# Create Managed Disks
resource "azurerm_managed_disk" "datadisks" {
  count                = local.ascluster["vm_count"] * local.ascluster["disks_per_vm"]
  name                 = "${var.prefix}-datadisk-${count.index}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = local.ascluster["disk_type"]
  disk_size_gb         = local.ascluster["disk_size_gb"]
  create_option        = "Empty"
  //source_resource_id =  trimspace(split(",", data.template_file.snapshot_urls.rendered)[count.index])
  //source_resource_id   = "/subscriptions/60631e84-1bf3-42ca-bacc-c5242b586725/resourceGroups/aerospike-eval2-rg/providers/Microsoft.Compute/snapshots/aerospike-eval2-datadisk-snapshot-${count.index}"
  //create_option        = "Copy"
  //source_resource_id   = azurerm_snapshot.snapshots.*.id[count.index]
  tags                 = local.tags
  zones                = [element(azurerm_linux_virtual_machine.aerovm.*.zone, ceil((count.index + 1) * 1.0 / local.ascluster["disks_per_vm"]) - 1)]
}

# Attach disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data-disk-attach" {
  count              = local.ascluster["vm_count"] * local.ascluster["disks_per_vm"]
  managed_disk_id    = azurerm_managed_disk.datadisks.*.id[count.index]
  virtual_machine_id = element(azurerm_linux_virtual_machine.aerovm.*.id, ceil((count.index + 1) * 1.0 / local.ascluster["disks_per_vm"]) - 1)
  lun                = count.index % local.ascluster["disks_per_vm"]
  caching            = "None"
  create_option      = "Attach"
  depends_on         = [azurerm_managed_disk.datadisks, azurerm_linux_virtual_machine.aerovm]
}
