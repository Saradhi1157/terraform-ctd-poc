
data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

data "azuread_service_principal" "logged_in_app" {
  count          = var.logged_aad_app_objectId == null ? 0 : 1
  application_id = data.azurerm_client_config.current.client_id
}

############### Data Factory ####################

module "data_factory" {
  source   = "/datafactory/modules/data_factory"
  for_each = local.data_factory.data_factory

  df_name             = var.name
  global_settings     = local.global_settings
  client_config       = local.client_config
  settings            = each.value
  diagnostics         = local.combined_diagnostics
  diagnostic_profiles = try(each.value.diagnostic_profiles, {})
  location            = can(local.global_settings.regions[each.value.region]) ? local.global_settings.regions[each.value.region] : local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].location
  base_tags           = try(local.global_settings.inherit_tags, false) ? try(local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].tags, {}) : {}
  resource_groups     = local.combined_objects_resource_groups

  remote_objects = {
    managed_identities = local.combined_objects_managed_identities
    private_dns        = local.combined_objects_private_dns
    vnets              = local.combined_objects_networking
    private_endpoints  = try(each.value.private_endpoints, {})
    resource_groups    = try(each.value.private_endpoints, {}) == {} ? null : local.combined_objects_resource_groups
  }

}

output "data_factory" {
  value = module.data_factory
}

##### azurerm_data_factory_pipeline ###################

module "data_factory_pipeline" {
  source   = "./datafactory/modules/data_factory_pipeline"
  for_each = local.data_factory.data_factory_pipeline

  global_settings = local.global_settings
  client_config   = local.client_config
  settings        = each.value

  resource_group_name = can(each.value.resource_group.name) || can(each.value.resource_group_name) ? try(each.value.resource_group.name, each.value.resource_group_name) : local.combined_objects_resource_groups[try(local.client_config.landingzone_key, each.value.resource_group.lz_key)][try(each.value.resource_group_key, each.value.resource_group.key)].name
  data_factory_id     = can(each.value.data_factory.id) ? each.value.data_factory.id : local.combined_objects_data_factory[try(local.client_config.landingzone_key, each.value.data_factory.lz_key)][try(each.value.data_factory.key, each.value.data_factory_key)].id
}

output "data_factory_pipeline" {
  value = module.data_factory_pipeline
}


##################### Blob Storage linked service #################

module "data_factory_linked_service_azure_blob_storage" {
  source = "./datafactory/modules/linked_services/blob_storage"

  for_each = local.data_factory.linked_services.azure_blob_storage

  global_settings     = local.global_settings
  client_config       = local.client_config
  settings            = each.value
  resource_group_name = can(each.value.resource_group.name) || can(each.value.resource_group_name) ? try(each.value.resource_group.name, each.value.resource_group_name) : local.combined_objects_resource_groups[try(local.client_config.landingzone_key, each.value.resource_group.lz_key)][try(each.value.resource_group_key, each.value.resource_group.key)].name
  data_factory_id     = can(each.value.data_factory.id) ? each.value.data_factory.id : local.combined_objects_data_factory[try(local.client_config.landingzone_key, each.value.data_factory.lz_key)][try(each.value.data_factory.key, each.value.data_factory_key)].id
  storage_account     = can(each.value.storage_account.key) ? local.combined_objects_storage_accounts[try(each.value.storage_account.lz_key, local.client_config.landingzone_key)][each.value.storage_account.key] : null

  integration_runtime_name = try(
    coalesce(
      try(local.combined_objects_data_factory_integration_runtime_self_hosted[each.value.integration_runtime.data_factory_integration_runtime_self_hosted.lz_key][each.value.integration_runtime.data_factory_integration_runtime_self_hosted.key].name, null),
      try(local.combined_objects_data_factory_integration_runtime_self_hosted[local.client_config.landingzone_key][each.value.integration_runtime.data_factory_integration_runtime_self_hosted.key].name, null),
      try(each.value.integration_runtime.data_factory_integration_runtime_self_hosted.name, null),
      try(local.combined_objects_data_factory_integration_runtime_azure_ssis[each.value.integration_runtime.combined_objects_data_factory_integration_runtime_azure_ssis.lz_key][each.value.integration_runtime.combined_objects_data_factory_integration_runtime_azure_ssis.key].name, null),
      try(local.combined_objects_data_factory_integration_runtime_azure_ssis[local.client_config.landingzone_key][each.value.integration_runtime.combined_objects_data_factory_integration_runtime_azure_ssis.key].name, null),
      try(each.value.integration_runtime.combined_objects_data_factory_integration_runtime_azure_ssis.name, null)
    ),
  null)
}

output "data_factory_linked_service_azure_blob_storage" {
  value = module.data_factory_linked_service_azure_blob_storage
}
