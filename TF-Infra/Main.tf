resource "azurerm_public_ip" "multiwebgate_public_ip" {
  name                = "multiwebgate"
  resource_group_name = "PERSO_SIEF"
  location            = "francecentral"

  allocation_method = "Static"

  tags = {
    CreatedBy = ""
    ENV       = "Prod"
    Why       = "DipP20"
  }
}

resource "azurerm_virtual_network" "multiwebgate_vnet" {
  name                = "multiwebgate"
  resource_group_name = "PERSO_SIEF"
  location            = "francecentral"
  address_space       = ["10.0.0.0/16"]

  tags = {
    CreatedBy = ""
    ENV       = "Prod"
    Why       = "DipP20"
  }
}

resource "azurerm_subnet" "multiwebgate_subnet" {
  name                 = "default"
  resource_group_name  = "PERSO_SIEF"
  virtual_network_name = azurerm_virtual_network.multiwebgate_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  tags = {
    CreatedBy = ""
    ENV       = "Prod"
    Why       = "DipP20"
  }
}

resource "azurerm_application_gateway" "multiwebgate_appgw" {
  name                = "multiwebgate"
  resource_group_name = "PERSO_SIEF"
  location            = "francecentral"
  sku                 = "Standard_v2"
  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.multiwebgate_subnet.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIpIPv4"
    public_ip_address_id = azurerm_public_ip.multiwebgate_public_ip.id
  }
  backend_address_pool {
    name = "multiwebgate"
    backend_addresses = [
      "1stwppsyckprjst.azurewebsites.net",
      "2ndwppsyckprjs.azurewebsites.net",
      "3rdwppsyckprjs.azurewebsites.net",
    ]
  }
  backend_http_settings {
    name                  = "multgateback"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    request_timeout       = 50
    probe_name            = "multiwebhealth"
  }
  http_listener {
    name                   = "multiwebgate"
    frontend_ip_configuration_name = "appGwPublicFrontendIpIPv4"
    frontend_port_name     = "port_80"
    protocol               = "Http"
  }
  request_routing_rule {
    name                       = "mutliwebgate"
    rule_type                  = "Basic"
    http_listener_name         = "multiwebgate"
    backend_address_pool_name  = "multiwebgate"
    backend_http_settings_name = "multgateback"
  }
  probe {
    name                = "multiwebhealth"
    protocol            = "Http"
    host                = "1stwppsyckprjst.azurewebsites.net"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_codes = ["200-399"]
    }
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 10
  }
  tags = {
    CreatedBy = ""
    ENV       = "Prod"
    Why       = "DipP20"
  }
}