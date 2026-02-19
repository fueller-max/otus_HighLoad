
output "iscsi_ip_address" {

  description = "The IPv4 addresses of the created VM"
  value = proxmox_vm_qemu.iscsi.ipconfig0

}

output "gfs1_ip_address" {

  description = "The IPv4 addresses of the created VM"
  value = proxmox_vm_qemu.gfs1.ipconfig0

}

output "gfs2_ip_address" {

  description = "The IPv4 addresses of the created VM"
  value = proxmox_vm_qemu.gfs2.ipconfig0

}

output "gfs3_ip_address" {

  description = "The IPv4 addresses of the created VM"
  value = proxmox_vm_qemu.gfs3.ipconfig0

}

#resource "local_file" "output_data" {

#   content  =  proxmox_vm_qemu.iscsi.ipconfig0
#   filename = "${path.module}/instances_ip.txt"

#}