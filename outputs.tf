# VM Outputs
output "vm_ips" {
  description = "The IP addresses of the created VMs"
  value       = module.vm.vm_ips
}

output "vm_names" {
  description = "The names of the created VMs"
  value       = module.vm.vm_names
}

output "vm_ids" {
  description = "The IDs of the created VMs"
  value       = module.vm.vm_ids
}

output "ansible_inventory" {
  description = "Complete Ansible inventory"
  value = {
    vm = {
      hosts = module.vm.ansible_inventory
    }
  }
}
