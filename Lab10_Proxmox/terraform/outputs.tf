
#####################  Proxmox #########################

output "lab10_centos_10_ext_ip_address" {

  description = "lab10_centos_10 external net IPv4 address: "
  value = proxmox_vm_qemu.lab10_centos_10.ipconfig0

}

####################################################################


