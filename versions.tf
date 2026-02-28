terraform {
  required_version = ">= 1.9.8"
  
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.10.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3"
    }
  }
}