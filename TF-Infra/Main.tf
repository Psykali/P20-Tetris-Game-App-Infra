# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet for the Application Gateway
resource "azurerm_subnet" "subnet_gw" {
  name                 = "mySubnet-gw"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name = var.resource_group_name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a subnet for the Web Apps
resource "azurerm_subnet" "subnet_web" {
  name                 = "mySubnet-web"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name = var.resource_group_name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
# Create a public IP address for the Application Gateway
resource "azurerm_public_ip" "pip" {
  name                = "myPublicIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}
# Create an Application Gateway with WAF enabled
resource "azurerm_application_gateway" "appgw" {
  name                = "myAppGateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name      = "myGatewayIPConfig"
    subnet_id = azurerm_subnet.subnet_gw.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "myFrontendIPConfig"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
  backend_address_pool {
    name         = "myBackendAddressPool"
    fqdns        = [azurerm_app_service.webapp1.default_site_hostname, azurerm_app_service.webapp2.default_site_hostname]
    ip_addresses = []
  }
 backend_http_settings {
    name                  = "myBackendHTTPSettings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
    probe_name            = "http-probe"

    # Use the hostname from the backend HTTP settings
    pick_host_name_from_backend_http_settings = true
  }

http_listener {
  name                           ="http-listener"
  frontend_ip_configuration_name ="myFrontendIPConfig"
  frontend_port_name             ="port_80"
  protocol                       ="Http"
}
request_routing_rule{
  name                        ="http-rule"
  rule_type                   ="Basic"
  http_listener_name           ="http-listener"
  backend_address_pool_name   ="myBackendAddressPool"
  backend_http_settings_name   ="myBackendHTTPSettings"
}
probe{
  name="http-probe"
  protocol="Http"
  path="/"
  interval=30
  timeout=30
  unhealthy_threshold=3
}
ssl_policy{
  policy_type="Predefined"
  policy_name="AppGwSslPolicy20170401S"
}
  waf_configuration{
  enabled=true
  firewall_mode="Detection"
  rule_set_type="OWASP"
  rule_set_version="3.1"
  file_upload_limit_mb=100
  max_request_body_size_kb=128
  request_body_check=true
}
}
# Create an App Service Plan for the Web Apps
resource "azurerm_app_service_plan" "example" {
  name                ="myAppServicePlan"
  location            = var.location
  resource_group_name = var.resource_group_name
sku{
  tier="Standard"
  size="S1"
}
  kind="Linux"
  reserved=true
}

# Create the first Web App for Linux
resource "azurerm_app_service" "webapp1" {
name                ="webapp1-${random_string.rs.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.example.id
  site_config {
    linux_fx_version = "DOCKER|skP20ContReg.azurecr.io/tetrisgameapp"
 }
  identity {
    type = "SystemAssigned"
  }
  tags = local.common_tags
}
# Create the second Web App for Linux
resource "azurerm_app_service" "webapp2" {
  name                ="webapp2-${random_string.rs.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.example.id
  site_config {
    linux_fx_version = "DOCKER|skP20ContReg.azurecr.io/tetrisgameapp"
 }
  identity {
    type = "SystemAssigned"
  }
  tags = local.common_tags
}
# Generate a random string for unique resource names
resource "random_string" "rs" {
    length=4

    special=false

    upper=false
}
