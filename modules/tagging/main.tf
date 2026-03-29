locals {
  required_tags = {
    Workspace          = var.workspace
    Service            = var.service
    Team               = var.team
    CostCenter         = var.cost_center
    ManagedBy          = var.managed_by
    DataClassification = var.data_classification
  }

  repository_tag = var.repository != "" ? { Repository = var.repository } : {}

  tags = merge(local.required_tags, local.repository_tag, var.additional_tags)
}
