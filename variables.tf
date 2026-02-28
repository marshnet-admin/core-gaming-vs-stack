#########################
# Environment Variables #
#########################

variable "gbl_environment" {
  description = "The environment to deploy to (e.g., development, staging, production)"
  type        = string
}

# Local environment variables
variable "gbl_local_user" {
  description = "Local user running Terraform/Ansible"
  type        = string
}

variable "gbl_local_home" {
  description = "Home directory of local user"
  type        = string
}

variable "gbl_project_path" {
  description = "Full path to project directory"
  type        = string
}

#####################
# vSphere Variables #
#####################

variable "gbl_vsphere_user" {
  description = "vSphere user name"
  type        = string
}

variable "gbl_vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "gbl_vsphere_server" {
  description = "vSphere server"
  type        = string
}

variable "gbl_vsphere_allow_unverified_ssl" {
  description = "Allow unverified SSL cert for vSphere"
  type        = bool
  default     = false
}

variable "gbl_datacenter" {
  description = "vSphere datacenter"
  type        = string
}

variable "gbl_datastore" {
  description = "vSphere datastore"
  type        = string
}

variable "gbl_template_path" {
  description = "Path to the VM template"
  type        = string
}

################
# VM Variables #
################

variable "gbl_vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "gbl_vm_name" {
  description = "Base name for VMs"
  type        = string
}

variable "gbl_vm_network" {
  description = "vSphere network for VMs"
  type        = string
}

variable "gbl_vm_ip_base" {
  description = "Base IP address for VMs"
  type        = string
}

variable "gbl_vm_netmask" {
  description = "Netmask for VMs"
  type        = number
}

variable "gbl_vm_gateway" {
  description = "Gateway for VMs"
  type        = string
}

variable "gbl_dns_servers" {
  description = "List of DNS server IP addresses"
  type        = list(string)
  default     = ["8.8.8.8"]
}

variable "gbl_dns_suffix" {
  description = "DNS suffix for the VMs"
  type        = string
  default     = "local"
}

variable "gbl_vm_cpu" {
  description = "Number of CPUs for VMs"
  type        = number
  default     = 2
}

variable "gbl_vm_memory" {
  description = "Memory in MB for VMs"
  type        = number
  default     = 2048
}

variable "gbl_vm_disk_size" {
  description = "Disk size in GB for VMs"
  type        = number
  default     = 30
}

variable "gbl_vm_domain" {
  description = "Domain for VMs"
  type        = string
  default     = "local"
}

#####################
# Ansible Variables #
#####################

variable "gbl_ansible_user" {
  description = "The user for Ansible to connect as"
  type        = string
  default     = "debian"
}

variable "gbl_ansible_ssh_private_key_file" {
  description = "Path to the private key file for Ansible SSH connection"
  type        = string
  default     = "./ansible/inventory/ssh_keys/vsphere_ansible_key"
}

variable "gbl_ansible_ssh_public_key_file" {
  description = "Path to the Ansible SSH public key file"
  type        = string
  default     = "./ansible/inventory/ssh_keys/vsphere_ansible_key.pub"
}

#######################
# Snapshot Variables  #
#######################

variable "gbl_create_snapshot" {
  description = "Create a snapshot after VM provisioning (before Ansible)"
  type        = bool
  default     = true
}

variable "gbl_snapshot_name" {
  description = "Name for the post-provisioning snapshot"
  type        = string
  default     = "pre-ansible-clean-state"
}
