resource "azurerm_app_service_plan" "asp" {
  name                = "webapp-asp"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux"
  reserved = true

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

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_virtual_network.vnet.subnet[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "webapp-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_application_gateway" "waf" {
  name                = "tetris-waf"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_Small"

  gateway_ip_configuration {
    name      = "tetris-gateway-ip"
    subnet_id = azurerm_virtual_network.vnet.subnet[0].id
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
  }

  request_routing_rule {
    name                       = "tetris-routing-rule"
    rule_type                  = "PathBasedRouting"
    http_listener_name         = azurerm_application_gateway.waf.http_listener[0].name
    backend_address_pool_name  = azurerm_application_gateway.waf.backend_address_pool[0].name
    backend_http_settings_name = azurerm_application_gateway.waf.backend_http_settings[0].name

    path_based_routing_configuration {
      paths = ["/*"]
      backend_address_pool_name = azurerm_application_gateway.waf.backend_address_pool[0].name
    }
  }

  connection_draining {
    enabled = true
  }

  enable_http2 = true

  tags = {
    environment = "production"
  }
}

resource "azurerm_application_gateway_web_application_firewall_policy" "waf_policy" {
  name                = "webapp-waf-policy"
  location            = var.location
  resource_group_name = var.resource_group_name

  policy {
    mode = "Prevention"

    custom_rules {
      name = "rule-1"
      rule_type = "MatchRule"
      action = "Block"
      priority = 1
      match_conditions {
        match_variables {
          variable_name = "RemoteAddr"
          selector = "RemoteAddr"
        }
        match_values = ["1.2.3.4"]  # Add the IP address you want to block
        operator = "IPMatch"
      }
    }
  }
}

resource "azurerm_application_gateway_web_application_firewall_policy_association" "waf_policy_association" {
  resource_group_name = var.resource_group_name
  application_gateway_name       = azurerm_application_gateway.waf.name
  web_application_firewall_policy_id = azurerm_application_gateway_web_application_firewall_policy.waf_policy.id
}

resource "azurerm_application_gateway_request_routing_rule" "waf_routing_rule" {
  resource_group_name = var.resource_group_name
  application_gateway_name     = azurerm_application_gateway.waf.name
  name                         = "waf-routing-rule"
  rule_type                    = "Basic"
  http_listener_name           = azurerm_application_gateway.waf.http_listener[0].name
  backend_address_pool_name    = azurerm_application_gateway.waf.backend_address_pool[0].name
  backend_http_settings_name   = azurerm_application_gateway.waf.backend_http_settings[0].name
  path_map {
    priority = 1
    path     = "/"
    backend_address_pool_name = azurerm_application_gateway.waf.backend_address_pool[0].name
  }
}

resource "azurerm_application_gateway_probe" "waf_probe" {
  resource_group_name = var.resource_group_name
  application_gateway_name = azurerm_application_gateway.waf.name
  name                    = "waf-probe"
  protocol                = "Http"
  host                    = "localhost"
  path                    = "/"
  interval                = 30
  timeout                 = 30
  unhealthy_threshold     = 3
  pick_host_name_from_backend_http_settings = true
}

resource "azurerm_application_gateway_backend_http_settings" "waf_backend_http_settings" {
  resource_group_name = var.resource_group_name
  application_gateway_name = azurerm_application_gateway.waf.name
  name                    = "waf-backend-http-settings"
  port                    = 80
  protocol                = "Http"
  cookie_based_affinity   = "Enabled"
}

resource "azurerm_application_gateway_backend_address_pool" "waf_backend_address_pool" {
  resource_group_name = var.resource_group_name
  application_gateway_name = azurerm_application_gateway.waf.name
  name                    = "waf-backend-address-pool"
}

resource "azurerm_application_gateway_http_listener" "waf_http_listener" {
  resource_group_name = var.resource_group_name
  application_gateway_name = azurerm_application_gateway.waf.name
  name                    = "waf-http-listener"
  frontend_ip_configuration_name = azurerm_application_gateway.waf.frontend_ip_configuration[0].name
  frontend_port_name             = azurerm_application_gateway.waf.frontend_port[0].name
  protocol                        = "Http"
}

resource "azurerm_application_gateway_frontend_ip_configuration" "waf_frontend_ip_configuration" {
  resource_group_name = var.resource_group_name
  application_gateway_name = azurerm_application_gateway.waf.name
  name                    = "waf-frontend-ip-configuration"
  public_ip_address_id    = "public_ip_address_id = azurerm_public_ip.waf_public_ip."
}
