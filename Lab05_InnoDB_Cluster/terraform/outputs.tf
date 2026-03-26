


#####################  Data Base ###################################

output "Node-db1_ext_ip_address" {

  description = "Node-db1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db1.ipconfig0

}

output "Node-db1_to_backends_ip_address" {

  description = "Database to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db1.ipconfig1

}

output "Node-db2_ext_ip_address" {

  description = "Node-db1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db2.ipconfig0

}

output "Node-db2_to_backends_ip_address" {

  description = "Database to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db2.ipconfig1

}

output "Node-db3_ext_ip_address" {

  description = "Node-db3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db3.ipconfig0

}

output "Node-db3_to_backends_ip_address" {

  description = "Database to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab05-node-db3.ipconfig1

}

####################################################################







