resource "azurerm_public_ip" "tetris_public_ip" {
  name                = "tetris"
  location            = var.location
  resource_group_name = var.resource_group_name

  allocation_method = "Static"
  sku               = "Standard"

  tags = local.common_tags
}


resource "azurerm_virtual_network" "tetris_vnet" {
  name                = "tetris"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "tetris_subnet" {
  name                 = "default"
  resource_group_name  = "PERSO_SIEF"
  virtual_network_name = azurerm_virtual_network.tetris_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_application_gateway" "tetris_appgw" {
  name                = "tetris"
  location            = var.location
  resource_group_name = var.resource_group_name
 
  backend_address_pool {
    name = "tetris"
  }

  sku {
  name = "Standard_v2"
  tier = "Standard_v2"
 }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.tetris_subnet.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIpIPv4"
    public_ip_address_id = azurerm_public_ip.tetris_public_ip.id
  }
  
  backend_http_settings {
    name                  = "tetrisback"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    request_timeout       = 50
    probe_name            = "tetris_health"
  }
  http_listener {
    name                   = "tetris"
    frontend_ip_configuration_name = "appGwPublicFrontendIpIPv4"
    frontend_port_name     = "port_80"
    protocol               = "Http"
  }
  request_routing_rule {
    name                       = "tetris_rule"
    rule_type                  = "Basic"
    http_listener_name         = "tetris"
    backend_address_pool_name  = "tetris"
    backend_http_settings_name = "tetrisback"
    priority                   = 1
  }
  probe {
    name                = "tetris_health"
    protocol            = "Http"
    host                = "sktetris-1.azurewebsites.net"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200-399"]
    }
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 10
  }
  tags = local.common_tags
}