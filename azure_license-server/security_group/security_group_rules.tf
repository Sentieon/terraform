variable "rg_name" {}
variable "rg_location" {}

resource "azurerm_network_security_group" "security_group" {
  name                = "license-server-security-group"
  location            = var.rg_location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "AllowLicenseServerInboundTCP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "172.31.0.0/16"
    destination_address_prefix = "*"
    destination_port_range     = "8990"
    source_port_range          = "*"
  }

  security_rule {
    name                       = "AllowLicenseServerOutboundHTTPS"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_address_prefix = "52.89.132.242"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    name                       = "AllowLicenseServerInboundSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "22"
    source_address_prefix      = "*"
  }

  security_rule {
    name                       = "AllowLicenseServerICMP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
  }
}
