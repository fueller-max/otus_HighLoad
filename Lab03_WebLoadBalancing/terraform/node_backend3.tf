resource "proxmox_vm_qemu" "backend3" {
    name = "backend3"
    description = "backend3"

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox"

    # The template name to clone this vm from
    clone = "Ubuntu2404-Template"

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
            ide3 {
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
    
    # Lan2: internal network (balancer <-> backend)
    network {
        id = 1
        model = "virtio"
        bridge = "vmbr1"
    }
    
    # Lan3: internal network (backend <-> database)
    network {
        id = 2
        model = "virtio"
        bridge = "vmbr2"
    }


    # Setup the ip address using cloud-init.
    boot = "order=virtio0"
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=192.168.70.33/24,gw=192.168.70.1"
    nameserver = "8.8.8.8"
    ciuser = "deploy"
    sshkeys = <<EOF
       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwOGqPyDBruydkg1DPItwaBBwo5/5gAaBYeshgNFmlS maksim@maksim-asus-tuf
     EOF
     ipconfig1 = "ip=10.10.10.23/24"
     ipconfig2 = "ip=10.10.20.23/24"
}

