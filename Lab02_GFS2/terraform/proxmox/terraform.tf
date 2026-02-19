
terraform {
  required_providers {
    
    # Provder to manage Proxmox hypervisor
    proxmox = {
        source = "telmate/proxmox"
        version = "3.0.2-rc07"
    }
    
    # Provider to manage terraform outputs to local files
    local = {
        source = "hashicorp/local"
        version = "2.7.0"
    }

  }
}
