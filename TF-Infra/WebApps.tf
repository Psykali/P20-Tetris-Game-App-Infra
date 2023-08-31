resource "azurerm_app_service_plan" "asp" {
  name                = "webapp-asp"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "webapp" {
  count               = 3
  name                = "sktetris-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  site_config {
    linux_fx_version = "DOCKER|skP20ContReg.azurecr.io/tetrisgameapp"
  }

  app_settings = {
    "WEBSITES_PORT" = "80"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_public_ip" "waf_public_ip" {
  name                = "waf-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "webapp-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name           = "webapp-subnet"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_application_gateway" "waf" {
  name                = "tetris-waf"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_Small"

  gateway_ip_configuration {
    name      = "tetris-gateway-ip"
    subnet_id = tolist(azurerm_virtual_network.vnet.subnet)[0].id
    http_listener_name = tolist(azurerm_application_gateway.waf.http_listener)[0].name
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "tetrismy-frontend-ip"
    public_ip_address_id = azurerm_public_ip.waf_public_ip.id
  }

  backend_address_pool {
    name = "tetris-backend-pool"
  }

  backend_http_settings {
    name                  = "tetris-http-settings"
    cookie_based_affinity = "Enabled"
    port                  = 80
    protocol              = "Http"
  }

  http_listener {
    name                           = "tetris-http-listener"
    frontend_ip_configuration_name = "tetris-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "tetris-routing-rule"
    rule_type                  = "Basic"
    http_listener_name = tolist(azurerm_application_gateway.waf.http_listener)[0].name
    backend_address_pool_name = tolist(azurerm_application_gateway.waf.backend_address_pool)[0].name
    backend_http_settings_name = tolist(azurerm_application_gateway.waf.backend_http_settings)[0].name
  }

  connection_draining {
    enabled = true
  }

  enable_http2 = true

  tags = {
    environment = "production"
  }
}
