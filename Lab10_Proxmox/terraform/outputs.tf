
#####################  Proxmox #########################

output "lab10_ubuntu_24_ext_ip_address" {

  description = "lab10_ubuntu_24 external net IPv4 address: "
  value = proxmox_vm_qemu.lab10_ubuntu_24.ipconfig0

}

####################################################################


