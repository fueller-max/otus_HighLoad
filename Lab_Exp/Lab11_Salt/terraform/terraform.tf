terraform {
  required_providers {
    
    # Provder to manage Proxmox hypervisor
    proxmox = {
        source  = "bpg/proxmox"
        version = "0.106.0"
    }

  }
}
