resource "proxmox_virtual_environment_vm" "lab11-salt-minion" {
    name = "lab11-salt-minion"
    description = "lab11-salt-minion"

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox"

    # The template name to clone this vm from
    clone = "Ubuntu26-Template"

    # Activate QEMU agent for this VM
    #agent = 1

    os_type = "cloud-init"

    cpu {
        cores = 2
        sockets = 1
        type = "host"
    }
    memory = 2048
    scsihw = "virtio-scsi-single"

    # Setup the disk
    disks {
        ide {
            ide2 {
                cloudinit {
                    storage = var.storage_name
                }
            }
        }
        virtio {
            virtio0 {
                disk {
                    size            = "10G"
                    storage         = var.storage_name
                    replicate       = true
                }
            }
            
        }
    }

    # Setup the network interfaces

    # Lan1: public (external network) 
    network {
        id = 0
        model = "virtio"
        bridge = "vmbr0"
    }

    cloudinit {
      user_data = templatefile("cloudinit-minion.yaml", {
        salt_master_ip = proxmox_vm_qemu.lab11-salt-master.default_ipv4_address
      })
      ipconfig0 = "ip=192.168.70.112/24,gw=192.168.70.1"
      nameserver = "8.8.8.8"
      ciuser    = "deploy"
      ssh_keys  = var.ssh_public_key
    }

}
