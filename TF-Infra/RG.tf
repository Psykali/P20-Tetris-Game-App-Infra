##########
## Tags ##
##########
locals {
  common_tags = {
    CreatedBy   = "SK"
    Env         = "Prod"
    Why         = "DipP20"
    Proj        = "TetrisGameAppInfra"
    Infratype   = "PaaS-IaC"
    Ressources  = "ASP-WA-AGW-ContReg-DockerImg"
  }
}
############################
## Create Ressource Group ##
############################
#resource "azurerm_resource_group" "example" {
#  name     = "PERSO_SIEF"
#  location = "France Central"
#}