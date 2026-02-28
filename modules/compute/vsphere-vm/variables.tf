variable "mod_environment" {
  description = "The environment to deploy to (development or production)"
  type        = string
}

variable "mod_datacenter" {
  description = "vSphere datacenter"
  type        = string
  default     = null
}

variable "mod_datastore" {
  description = "vSphere datastore"
  type        = string
  default     = null
}

variable "mod_vm_resource_pool" {
  description = "Define resource pool name"
  type        = string
  default     = "Resources"
}

variable "mod_network" {
  description = "vSphere network"
  type        = string
  default     = null
}

variable "mod_vm_count" {
  description = "The number of Consoles to create"
  type        = number
  default     = 1
}

variable "mod_vm_name" {
  description = "VM name"
  type        = string
}

variable "mod_vm_hostnames" {
  description = "VM hostname"
  type        = string
  default     = null
}

variable "mod_vm_netmask" {
  description = "VM netmask"
  type        = number
  default     = null
}

variable "mod_vm_gateway" {
  description = "VM gateway"
  type        = string
  default     = null
}

variable "mod_template_path" {
  description = "Path to the ISO"
  type        = string
  default     = null
}

variable "mod_vm_guest_id" {
  description = "Guest OS Profile"
  type        = string
  default     = "debian12_64Guest"
}

variable "mod_vm_adapter_type" {
  description = "VM Network adapter type"
  type        = string
  default     = "vmxnet3"
}

variable "mod_vm_domain" {
  description = "VM Domain name"
  type        = string
  default     = "local"
}

variable "mod_vm_cpu" {
  description = "Number of CPUs for the VM"
  type        = number
  default     = 2
}

variable "mod_vm_memory" {
  description = "Memory size for the VM in MB"
  type        = number
  default     = 2048
}

variable "mod_vm_disk_size" {
  description = "Disk size for the VM in GB"
  type        = number
  default     = 30
}

variable "mod_vm_disk_label" {
  description = "Disk label for the VM"
  type        = string
  default     = "disk0"
}

variable "mod_vm_disk_scrub" {
  description = "VM Disk eagerly srub"
  type        = bool
  default     = false
}

variable "mod_vm_disk_thin" {
  description = "VM Disk thin provisioning"
  type        = bool
  default     = true
}

variable "mod_vm_additional_disks" {
  description = "List of additional disks to create"
  type = list(object({
    label            = string
    size             = number
    thin_provisioned = bool
    eagerly_scrub    = optional(bool, false)
    unit_number      = number
  }))
  default = []
}

variable "mod_vm_ip_base" {
  description = "Base IP address for VMs"
  type        = string
  validation {
    condition     = can(cidrhost("${var.mod_vm_ip_base}/32", 0))
    error_message = "The mod_vm_ip_base must be a valid IP address."
  }
}

variable "mod_dns_servers" {
  description = "List of DNS server IP addresses"
  type        = list(string)
}

variable "mod_dns_suffix" {
  description = "DNS suffix for the VMs"
  type        = string
  default     = "local"
}

variable "mod_tags" {
  description = "Map of tags to apply to the VM"
  type        = map(string)
  default     = {}
}

variable "mod_enable_monitoring" {
  description = "Enable built-in vSphere monitoring"
  type        = bool
  default     = true
}

variable "mod_folder_path" {
  description = "VM folder path in vSphere"
  type        = string
  default     = null
}

variable "mod_ansible_user" {
  description = "The user for Ansible to connect as"
  type        = string
  default     = "debian" # or whatever user your VM template uses
}

variable "mod_ansible_ssh_private_key_file" {
  description = "Path to the private key file for Ansible SSH connection"
  type        = string
  default     = "./ansible/inventory/ssh_keys/vsphere_ansible_key"
}

variable "mod_create_snapshot" {
  description = "Create a snapshot after VM provisioning (before Ansible)"
  type        = bool
  default     = true
}

variable "mod_snapshot_name" {
  description = "Name for the post-provisioning snapshot"
  type        = string
  default     = "pre-ansible-clean-state"
}
