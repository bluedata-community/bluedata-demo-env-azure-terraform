# Deployment variables
variable "project_id" { }
# used also for creating local admin users in deployed VMs but this username is replaced with bluedata in cloud-init files
variable "user" { }

# AzureRM variables
variable "region" { }
variable "subscription_id" { }
variable "client_id" { }
variable "client_secret" { }
variable "tenant_id" { }
variable "cloud_init_file" { default = "./cloud-init.yaml" }
variable "ctr_cloud_init_file" { default = "./cloud-init-ctr.yaml" }

# BlueData cluster variables
variable "worker_count" { default = 3 }

# Azure VM Sizes
variable "gtw_instance_type" { default = "Standard_D16_v3" }
variable "ctr_instance_type" { default = "Standard_D16_v3" }
variable "wkr_instance_type" { default = "Standard_D16_v3" }
variable "nfs_instance_type" { default = "Standard_D2_v3" }
variable "ad_instance_type" { default = "Standard_D2_v3" }

# environment
variable "ssh_pub_key_path" { default = "~/.ssh/id_rsa.pub" }

provider "azurerm" {
    version = "=1.44.0"
    subscription_id = var.subscription_id
    client_id = var.client_id
    client_secret = var.client_secret
    tenant_id = var.tenant_id
}

# Create a resource group
resource "azurerm_resource_group" "resourcegroup" {
  name     = "${var.project_id}-rg"
  location = var.region
  tags = {
        environment = var.project_id,
        user = var.user
    }
}

// # Create private DNS zone
// resource "azurerm_private_dns_zone" "dnszone" {
//   name                = "${var.project_id}.bdlocal"
//   resource_group_name = azurerm_resource_group.resourcegroup.name
//   tags = {
//     environment = var.project_id,
//     user = var.user
//   }
// }

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "network" {
    name                = "${var.project_id}-vnet"
    address_space       = ["10.1.0.0/16"]
    location            = var.region
    resource_group_name = azurerm_resource_group.resourcegroup.name

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

// # Link Private DNS Zone to Virtual Network
// resource "azurerm_private_dns_zone_virtual_network_link" "dnslink" {
//   name                  = "dnslink"
//   resource_group_name   = azurerm_resource_group.resourcegroup.name
//   private_dns_zone_name = azurerm_private_dns_zone.dnszone.name
//   virtual_network_id    = azurerm_virtual_network.network.id
// }

# Create the subnet
resource "azurerm_subnet" "subnet" {
    name                 = "${var.project_id}-subnet"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.1.1.0/24"
}

# Create a Network Security Group 
# allow ssh & http

resource "azurerm_network_security_group" "nsg" {
    name                = "${var.project_id}-nsg"
    location            = var.region
    resource_group_name = azurerm_resource_group.resourcegroup.name
    
  security_rule {
    name = "AllowSSH"
    priority = 100
    direction = "Inbound"
    access         = "Allow"
    protocol = "Tcp"
    source_port_range       = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "AllowHTTP"
    priority= 200
    direction= "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range       = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
      environment = var.project_id,
      user = var.user
  }
}

# Controller Public IP
resource "azurerm_public_ip" "controllerpublicip" {
    name                         = "controller-ip"
    location                     = var.region
    resource_group_name          = azurerm_resource_group.resourcegroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Gateway Public IP
resource "azurerm_public_ip" "gatewaypublicip" {
    name                         = "gateway-ip"
    location                     = var.region
    resource_group_name          = azurerm_resource_group.resourcegroup.name
    allocation_method            = "Dynamic"
    domain_name_label            = "${var.user}-${var.project_id}"

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Controller NIC
resource "azurerm_network_interface" "controllernic" {
    name                        = "controller-nic"
    location                    = var.region
    resource_group_name         = azurerm_resource_group.resourcegroup.name
    network_security_group_id   = azurerm_network_security_group.nsg.id

    ip_configuration {
        name                          = "controller-nic-configuration"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.controllerpublicip.id
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Gateway NIC
resource "azurerm_network_interface" "gatewaynic" {
    name                        = "gateway-nic"
    location                    = var.region
    resource_group_name         = azurerm_resource_group.resourcegroup.name
    network_security_group_id   = azurerm_network_security_group.nsg.id

    ip_configuration {
        name                          = "gateway-nic-configuration"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.gatewaypublicip.id
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Worker NICs
resource "azurerm_network_interface" "workernics" {
    count                       = var.worker_count
    name                        = "worker${count.index + 1}-nic"
    location                    = var.region
    resource_group_name         = azurerm_resource_group.resourcegroup.name
    network_security_group_id   = azurerm_network_security_group.nsg.id

    ip_configuration {
        name                          = "worker${count.index + 1}-nic-configuration"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        // public_ip_address_id          = azurerm_public_ip.workerpublicips[count.index].id
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Random ID generator for storage account
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resourcegroup.name
    }
    byte_length = 8
}

resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.resourcegroup.name
    location                    = var.region
    account_replication_type    = "LRS"
    account_tier                = "Standard"

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Create VMs

# Controller VM
resource "azurerm_virtual_machine" "controller-vm" {
    name                  = "controller-vm"
    location              = var.region
    resource_group_name   = azurerm_resource_group.resourcegroup.name
    network_interface_ids = [azurerm_network_interface.controllernic.id]
    vm_size               = var.ctr_instance_type

    storage_os_disk {
        name              = "controller-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        disk_size_gb      = "400"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name              = "controller-data-disk0"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "512"
        lun               = 1
    }

    storage_data_disk {
        name              = "controller-data-disk1"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "512"
        lun               = 2
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS-CI"
        sku       = "7-CI"
        version   = "latest"
    }

    os_profile {
        computer_name  = "controller.${var.project_id}.local"
        admin_username = var.user
        custom_data = file(pathexpand(var.ctr_cloud_init_file))
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = file(pathexpand(var.ssh_pub_key_path))
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Gateway VM
resource "azurerm_virtual_machine" "gateway-vm" {
    name                  = "gateway-vm"
    location              = var.region
    resource_group_name   = azurerm_resource_group.resourcegroup.name
    network_interface_ids = [azurerm_network_interface.gatewaynic.id]
    vm_size               = var.gtw_instance_type

    storage_os_disk {
        name              = "gateway-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        disk_size_gb      = "400"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name              = "gateway-data-disk0"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "512"
        lun               = 1
    }

    storage_data_disk {
        name              = "gateway-data-disk1"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "512"
        lun               = 2
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS-CI"
        sku       = "7-CI"
        version   = "latest"
    }

    os_profile {
        // To avoid name collapse with the gateway for vnet
        computer_name  = "bd-gateway.${var.project_id}.local"
        admin_username = var.user
        custom_data = file(pathexpand(var.cloud_init_file))
    }

    os_profile_linux_config {
        disable_password_authentication = true 
        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = file(pathexpand(var.ssh_pub_key_path))
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# Worker VMs
resource "azurerm_virtual_machine" "workers" {
    name                  = "worker${count.index + 1}-vm"
    count                 = var.worker_count
    location              = var.region
    resource_group_name   = azurerm_resource_group.resourcegroup.name
    network_interface_ids = [element(azurerm_network_interface.workernics.*.id, count.index)]
    vm_size               = var.wkr_instance_type

    storage_os_disk {
        name              = "worker${count.index + 1}-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        disk_size_gb      = "400"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name              = "worker${count.index + 1}-data-disk0"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "1024"
        lun               = 1
    }

    storage_data_disk {
        name              = "worker${count.index + 1}-data-disk1"
        caching           = "ReadWrite"
        create_option     = "Empty"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "1024"
        lun               = 2
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS-CI"
        sku       = "7-CI"
        version   = "latest"
    }

    os_profile {
        computer_name  = "worker${count.index + 1}.${var.project_id}.local"
        admin_username = var.user
        custom_data = file(pathexpand(var.cloud_init_file))
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = file(pathexpand(var.ssh_pub_key_path))
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.project_id,
        user = var.user
    }
}

# outputs

# workaround since public IP cannot be get before attaching to an online VM 
# https://github.com/terraform-providers/terraform-provider-azurerm/issues/764#issuecomment-365019882

data "azurerm_public_ip" "ctr_ip" {
  name                = azurerm_public_ip.controllerpublicip.name
  resource_group_name = azurerm_virtual_machine.controller-vm.resource_group_name
}

output "controller_public_ip" {
  value = data.azurerm_public_ip.ctr_ip.ip_address
}

output "controller_ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ${var.user}@${data.azurerm_public_ip.ctr_ip.ip_address}"
}

data "azurerm_public_ip" "gw_ip" {
  name                = azurerm_public_ip.gatewaypublicip.name
  resource_group_name = azurerm_virtual_machine.gateway-vm.resource_group_name
}

output "gateway_public_ip" {
  value = data.azurerm_public_ip.gw_ip.ip_address
}

output "controller_private_ip" {
    value = azurerm_network_interface.controllernic.private_ip_address
}

output "gateway_private_ip" {
    value = azurerm_network_interface.gatewaynic.private_ip_address
}

output "worker_private_ips" {
    value = azurerm_network_interface.workernics.*.private_ip_address
}
