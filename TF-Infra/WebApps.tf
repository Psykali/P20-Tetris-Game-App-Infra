resource "azurerm_application_insights" "tetris_ai" {
  name                = "tetris-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_app_insights" "tetris_appinsights" {
  count               = 3
  name                = "sktetris-${count.index}-ai"
  resource_group_name = var.resource_group_name
  application_type    = "web"

  depends_on = [
        azurerm_application_insights.tetris_ai,
    azurerm_app_service.tetris_webapps[0]
  ]

  application_id = azurerm_application_insights.tetris_ai.application_id
  location       = azurerm_application_insights.tetris_ai.location

  tags = local.common_tags

  instrumentation_key = azurerm_application_insights.tetris_ai.instrumentation_key

  correlation {
    client_track_enabled = false
  }

  web {
    app_id = azurerm_app_service.tetris_webapps[0].name
  }
}

resource "azurerm_app_service_plan" "tetris_asp" {
  name                = "tetris-asp"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "tetris_webapps" {
  count               = 3
  name                = "sktetris-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.tetris_asp.id

  site_config {
    linux_fx_version = "DOCKER|skP20ContReg.azurecr.io/tetrisgameapp"
  }

  app_settings = {
    "WEBSITES_PORT" = "80"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.tetris_ai.instrumentation_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_app_service_slot" "staging" {
  count               = 3
  name                = "staging"
  app_service_name    = azurerm_app_service.tetris_webapps[count.index].name
  location            = azurerm_app_service.tetris_webapps[count.index].location
  resource_group_name = azurerm_app_service.tetris_webapps[count.index].resource_group_name
  app_service_plan_id = azurerm_app_service_plan.tetris_asp.id

  tags = local.common_tags
}