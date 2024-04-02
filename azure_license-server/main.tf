variable "azure_region" {}
variable "resource_name" {}
variable "private_key_location" {}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_name
  location = var.azure_region
  key      = var.private_key_location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "sentieon-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["172.31.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "sentieon-subnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["172.31.0.0/24"]
}

resource "azurerm_public_ip" "license_server_public_ip" {
  name                = "license-server-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "license_server_nic" {
  name                      = "license-server-nic"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.license_server_public_ip.id
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_linux_virtual_machine" "license_server_instance" {
  name                  = "license-server-instance"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminUser"
  network_interface_ids = [azurerm_network_interface.license_server_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "adminUser"
    public_key = tls_private_key.ssh.public_key_openssh
  }
}

module "security_group" {
  source = "./security_group"
  
  rg_name    = azurerm_resource_group.rg.name
  rg_location = azurerm_resource_group.rg.location 
  private_ip_address = azurerm_linux_virtual_machine.license_server_instance.private_ip_address
}

output "license_server_private_ip" {
  value = azurerm_linux_virtual_machine.license_server_instance.private_ip_address
}

resource "local_file" "admin_ssh_key_pem" {
  filename = azurerm_resource_group.rg.key  # Specify the path where you want to save the PEM key
  content = tls_private_key.ssh.private_key_pem
}
