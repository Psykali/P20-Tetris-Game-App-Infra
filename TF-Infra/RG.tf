##########
## Tags ##
##########
locals {
  common_tags = {
    CreatedBy = "SK"
    Env       = "Prod"
    Why       = "DipP20"
  }
}
############################
## Create Ressource Group ##
############################
#resource "azurerm_resource_group" "example" {
#  name     = "PERSO_SIEF"
#  location = "France Central"
#}