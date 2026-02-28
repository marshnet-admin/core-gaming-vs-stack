locals {
  # Define environment attributes in a map for easy extension
  environments = {
    development = {
      is_active = var.mod_environment == "development"
    }
    staging = {
      is_active = var.mod_environment == "staging"
    }
    production = {
      is_active = var.mod_environment == "production"
    }
  }

  # Shortcuts for easier referencing
  is_vsphere     = local.environments.development.is_active || local.environments.staging.is_active || local.environments.production.is_active
  is_development = local.environments.development.is_active
  is_staging     = local.environments.staging.is_active
  is_production  = local.environments.production.is_active

  # Enhanced tags with consistent structure
  vm_tags = merge(
    {
      "Name"         = var.mod_vm_name
      "CreatedBy"    = "Terraform"
      "Module"       = "vsphere-vm"
      "LastModified" = timestamp()
      "Environment"  = var.mod_environment
    },
    var.mod_tags
  )
}

# VSphere Configuration
data "vsphere_datacenter" "dc" {
  count = local.is_vsphere ? 1 : 0
  name  = var.mod_datacenter
}

data "vsphere_datastore" "datastore" {
  count         = local.is_vsphere ? 1 : 0
  name          = var.mod_datastore
  datacenter_id = data.vsphere_datacenter.dc[0].id
}

data "vsphere_network" "network" {
  count         = local.is_vsphere ? 1 : 0
  name          = var.mod_network
  datacenter_id = data.vsphere_datacenter.dc[0].id
}

data "vsphere_resource_pool" "pool" {
  count         = local.is_vsphere ? 1 : 0
  name          = var.mod_vm_resource_pool
  datacenter_id = data.vsphere_datacenter.dc[0].id
}

data "vsphere_virtual_machine" "template" {
  count         = local.is_vsphere ? 1 : 0
  name          = var.mod_template_path
  datacenter_id = data.vsphere_datacenter.dc[0].id
}

resource "vsphere_virtual_machine" "vm" {
  count            = var.mod_vm_count
  name             = "${var.mod_vm_name}-${count.index + 1}"
  resource_pool_id = data.vsphere_resource_pool.pool[0].id
  datastore_id     = data.vsphere_datastore.datastore[0].id

  num_cpus = var.mod_vm_cpu
  memory   = var.mod_vm_memory
  guest_id = var.mod_vm_guest_id

  network_interface {
    network_id   = data.vsphere_network.network[0].id
    adapter_type = var.mod_vm_adapter_type
  }

  wait_for_guest_net_timeout = 5 # 5 minutes, adjust as needed

  # Enable VMware tools sync time
  sync_time_with_host = true

  # System disk
  disk {
    label            = var.mod_vm_disk_label
    size             = var.mod_vm_disk_size
    eagerly_scrub    = var.mod_vm_disk_scrub
    thin_provisioned = var.mod_vm_disk_thin
    unit_number      = 0
  }

  # Additional disks
  dynamic "disk" {
    for_each = var.mod_vm_additional_disks
    content {
      label            = "${disk.value.label}-${count.index + 1}"
      size             = disk.value.size
      thin_provisioned = disk.value.thin_provisioned
      eagerly_scrub    = disk.value.eagerly_scrub
      unit_number      = disk.value.unit_number
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template[0].id
    customize {
      linux_options {
        host_name = "${var.mod_vm_name}-${count.index + 1}"
        domain    = var.mod_vm_domain
      }

      network_interface {
        ipv4_address = cidrhost(
          "${var.mod_vm_ip_base}/${var.mod_vm_netmask}",
          tonumber(split(".", var.mod_vm_ip_base)[3]) + count.index
        )
        ipv4_netmask = var.mod_vm_netmask
      }

      ipv4_gateway    = var.mod_vm_gateway
      dns_server_list = var.mod_dns_servers
      dns_suffix_list = [var.mod_dns_suffix]
    }
  }
}

# Create snapshot after VM provisioning (clean state before Ansible)
resource "vsphere_virtual_machine_snapshot" "pre_ansible" {
  count = var.mod_create_snapshot ? var.mod_vm_count : 0

  virtual_machine_uuid = vsphere_virtual_machine.vm[count.index].id
  snapshot_name        = var.mod_snapshot_name
  description          = "Clean state after Terraform provisioning, before Ansible configuration"
  memory               = false
  quiesce              = true
  remove_children      = true
  consolidate          = true
}
