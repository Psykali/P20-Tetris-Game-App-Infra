resource "azurerm_application_insights" "tetris_ai" {
  name                = "tetris-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_application_insights_web_test" "tetris_appinsights" {
  name                = "sktetris-ai"
  resource_group_name = var.resource_group_name
  application_insights_id = azurerm_application_insights.tetris_ai.id
  location       = azurerm_application_insights.tetris_ai.location
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]

  configuration = <<XML
<WebTest Name="WebTest1" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="http://microsoft.com" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

}

output "webtest_id" {
  value = azurerm_application_insights_web_test.tetris_appinsights.id
}

output "webtests_synthetic_id" {
  value = azurerm_application_insights_web_test.tetris_appinsights.synthetic_monitor_id
}


resource "azurerm_app_service_plan" "tetris_asp" {
  name                = "tetris-asp"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux"
  reserved            = true
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