gbl_environment = "production"

### Authentication
gbl_vsphere_server               = "10.10.10.16"
gbl_vsphere_user                 = "marshnet@vsphere.local"
gbl_vsphere_allow_unverified_ssl = true # Only for development

### vSphere Vars
gbl_datacenter    = "Marshnet"
gbl_datastore     = "DS-VMStorage"
gbl_template_path = "debian-13.3.0-template"

# VM Settings - Gaming Server
# 6 vCPUs: headroom for 4 Bedrock instances + OS
# 16GB RAM: ~2-3GB per Bedrock server + OS overhead
# 100GB disk: worlds data + daily/pre-update backups
gbl_vm_count     = 1
gbl_vm_name      = "Gaming-Server"
gbl_vm_cpu       = 6
gbl_vm_memory    = 16384
gbl_vm_disk_size = 100
gbl_vm_network   = "VLAN40-SERVERS"
gbl_vm_ip_base   = "10.10.40.40"
gbl_vm_netmask   = 24
gbl_vm_gateway   = "10.10.40.1"
gbl_dns_servers  = ["10.10.40.1"]
gbl_vm_domain    = "local"
