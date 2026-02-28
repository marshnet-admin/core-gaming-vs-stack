terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

locals {
  state_id = sha256("${var.gbl_environment}-${timestamp()}")
}

# Provision VM(s)
module "vm" {
  source          = "./modules/compute/vsphere-vm"
  mod_environment = var.gbl_environment

  mod_vm_count = var.gbl_vm_count

  ### vSphere Vars
  mod_datacenter    = var.gbl_datacenter
  mod_datastore     = var.gbl_datastore
  mod_template_path = var.gbl_template_path

  ### VM Settings
  mod_vm_name      = var.gbl_vm_name
  mod_network      = var.gbl_vm_network
  mod_vm_ip_base   = var.gbl_vm_ip_base
  mod_vm_netmask   = var.gbl_vm_netmask
  mod_vm_gateway   = var.gbl_vm_gateway
  mod_dns_servers  = var.gbl_dns_servers
  mod_dns_suffix   = var.gbl_dns_suffix
  mod_vm_cpu       = var.gbl_vm_cpu
  mod_vm_memory    = var.gbl_vm_memory
  mod_vm_disk_size = var.gbl_vm_disk_size
  mod_vm_domain    = var.gbl_vm_domain

  # Tags for Ansible integration
  mod_tags = {
    Application = var.gbl_vm_name
    Component   = "infrastructure"
    Environment = var.gbl_environment
    StateID     = local.state_id
  }

  # Snapshot settings
  mod_create_snapshot = var.gbl_create_snapshot
  mod_snapshot_name   = var.gbl_snapshot_name
}
