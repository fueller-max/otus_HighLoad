resource "proxmox_vm_qemu" "cloud-init" {

  for_each = var.vm_configs

  vmid = each.value.vm_id  
  name        = each.value.name
  target_node = "proxmox"

  clone  = each.value.clone          # The template name to clone from
  full_clone = true
  #bios   = "ovmf"                   # BIOS UEFI
  agent  = 1                         # Activate QEMU agent for this VM

  scsihw = "virtio-scsi-single"      # The SCSI controller to emulate
  
  os_type = "cloud-init" 
  
  memory  = each.value.memory

  cpu {
    type = "x86-64-v2-AES"
    cores = each.value.cores
    sockets = each.value.sockets
  }
                   
  vm_state = each.value.vm_state
  start_at_node_boot = each.value.start_at_node_boot

  network {                        # Lan1:
    id = 0
    model = "virtio"
    bridge = each.value.bridge0 
    tag = each.value.network_tag0
  }

  network {                        # Lan2:
    id = 1
    model = "virtio"
    bridge = each.value.bridge1 
    tag = each.value.network_tag1
  }
   
  disks {                            # Setup disks
    ide {
      ide2 {
        cloudinit {
          storage = "vmdata2"
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          size       = "12G"
          storage    = "vmdata2"
          replicate  = true
        }
      }          
    }
  }

  # Setup the ip address using cloud-init.
  ipconfig0 = each.value.ip_conf0
  nameserver = "8.8.8.8"
  ipconfig1 = each.value.ip_conf1
  
  # Setup user / SSH key for access
  ciuser = "deploy"
  sshkeys = <<EOF
       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwOGqPyDBruydkg1DPItwaBBwo5/5gAaBYeshgNFmlS maksim@maksim-asus-tuf
       EOF

}