provider "vsphere" {
  user           = var.gbl_vsphere_user
  password       = var.gbl_vsphere_password
  vsphere_server = var.gbl_vsphere_server

  allow_unverified_ssl = var.gbl_vsphere_allow_unverified_ssl

  # Increase API timeout for long-running operations like snapshot deletion
  api_timeout = 20
}