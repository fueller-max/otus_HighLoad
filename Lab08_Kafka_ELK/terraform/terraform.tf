
terraform {
  required_providers {
    
    # Provder to manage Proxmox hypervisor
    proxmox = {
        source = "telmate/proxmox"
        version = "3.0.2-rc07"
    }

  }
}
