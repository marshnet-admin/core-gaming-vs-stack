output "ansible_inventory" {
  description = "Ansible inventory information for all VMs"
  value = {
    for idx, vm in vsphere_virtual_machine.vm : vm.name => {
      # Required Ansible connection information
      ansible_host                 = vm.default_ip_address
      ansible_user                 = var.mod_ansible_user                 # Modify based on your template's default user
      ansible_ssh_private_key_file = var.mod_ansible_ssh_private_key_file # Modify based on your SSH key path

      # VM metadata for Ansible variables
      datacenter  = var.mod_datacenter
      environment = var.mod_environment
      #state_id    = local.state_id
      vm_name = vm.name
      vm_id   = vm.id

      # Resource information
      cpu_count    = vm.num_cpus
      memory_mb    = vm.memory
      disk_size_gb = var.mod_vm_disk_size

      # Network information
      ip_address  = vm.default_ip_address
      netmask     = var.mod_vm_netmask
      gateway     = var.mod_vm_gateway
      dns_servers = var.mod_dns_servers
      dns_suffix  = var.mod_dns_suffix
      domain      = var.mod_vm_domain

      # Groups for Ansible (derived from tags and VM purpose)
      groups = [
        var.mod_environment,
        var.mod_vm_name,
        "vsphere_vms"
      ]

      # All tags as variables
      tags = local.vm_tags
    }
  }
}

output "ansible_groups" {
  description = "Group-based organization for Ansible"
  value = {
    # Environment-based groups
    "${var.mod_environment}" = [
      for vm in vsphere_virtual_machine.vm : vm.name
    ]

    # Role-based group (using VM name as role)
    "${var.mod_vm_name}" = [
      for vm in vsphere_virtual_machine.vm : vm.name
    ]

    # All VSphere VMs group
    "vsphere_vms" = [
      for vm in vsphere_virtual_machine.vm : vm.name
    ]
  }
}

# Keep existing outputs for backward compatibility
output "vsphere_vm_id" {
  value       = local.is_vsphere ? vsphere_virtual_machine.vm[0].id : ""
  description = "The ID of the vSphere VM"
}

output "mod_vm_hostnames" {
  value = [for vm in vsphere_virtual_machine.vm : vm.name]
}

output "vm_ips" {
  description = "The IP addresses of the created VMs"
  value       = vsphere_virtual_machine.vm[*].default_ip_address
}

output "vm_names" {
  description = "The names of the created VMs"
  value       = vsphere_virtual_machine.vm[*].name
}

output "vm_ids" {
  description = "The IDs of the created VMs"
  value       = vsphere_virtual_machine.vm[*].id
}

output "snapshot_ids" {
  description = "The IDs of the pre-Ansible snapshots"
  value       = vsphere_virtual_machine_snapshot.pre_ansible[*].id
}

output "snapshot_info" {
  description = "Information about the pre-Ansible snapshots"
  value = var.mod_create_snapshot ? {
    for idx, snap in vsphere_virtual_machine_snapshot.pre_ansible : vsphere_virtual_machine.vm[idx].name => {
      snapshot_name = snap.snapshot_name
      snapshot_id   = snap.id
      vm_uuid       = snap.virtual_machine_uuid
    }
  } : {}
}
