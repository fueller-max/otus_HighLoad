resource "proxmox_virtual_environment_vm" "lab11-salt-master" {
    name      = "lab11-salt-master"
    node_name = "pve"

    clone {
      vm_id     = 2003   # ID of the template in Proxmox
      full_clone = true  # a full clone (not a linked clone)
    }

    initialization {
      hostname = "lab11-salt-master"
      # uncomment and specify the datastore for cloud-init disk if default `local-lvm` is not available
      datastore_id = var.storage_name

      # Reference the cloud-init-snippet created below
      user_data_file_id = proxmox_virtual_environment_file.cloud_config_master.id
   
      ip_config {
        ipv4 {
          address = "192.168.70.110/24"
          gateway = "192.168.70.1"
        }
      }

      user_account {
        username = "deploy"
        keys     = var.ssh_public_key
      }

    }

    network_device {
      bridge = "vmbr0"
      model  = "virtio"
    }
}

# Resource for cloud-init for master 
resource "proxmox_virtual_environment_file" "cloud_config_master" {
  content_type = "snippets"
  datastore_id = var.storage_name
  node_name    = "pve"

  #data       = file("cloudinit-master.yaml")
  #file_name = "cloudinit-master.yaml"
}

