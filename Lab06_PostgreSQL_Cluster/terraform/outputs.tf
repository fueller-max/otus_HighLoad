
#####################  PostgreSQL/Patroni #########################

output "Node-pg1_ext_ip_address" {

  description = "Node-pg1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node1.ipconfig0

}

output "Node-pg1_cluster_ip_address" {

  description = "Node-pg1 cluster net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node1.ipconfig1

}

output "Node-pg2_ext_ip_address" {

  description = "Node-pg2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node2.ipconfig0

}

output "Node-pg2_cluster_ip_address" {

  description = "Node-pg2 cluster net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node2.ipconfig1

}

output "Node-pg3_ext_ip_address" {

  description = "Node-pg3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node3.ipconfig0

}

output "Node-pg3_cluster_ip_address" {

  description = "Node-pg3 cluster net IPv4 address: "
  value = proxmox_vm_qemu.lab06-pg-node3.ipconfig1

}

####################################################################


#####################  HAProxy    ##################################

output "Node-ha1_ext_ip_address" {

  description = "Node-ha-node1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node1.ipconfig0

}

output "Node-ha1_keepalived_ip_address" {

  description = "Node1-ha keepalived net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node1.ipconfig1

}

output "Node-ha1_cluster_ip_address" {

  description = "Node1-ha cluster net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node1.ipconfig2

}


output "Node-ha2_ext_ip_address" {

  description = "Node-ha-node2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node2.ipconfig0

}

output "Node-ha2_keepalived_ip_address" {

  description = "Node2-ha keepalived net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node2.ipconfig1

}

output "Node-ha2_cluster_ip_address" {

  description = "Node2-ha cluster net IPv4 address: "
  value = proxmox_vm_qemu.lab06-ha-node2.ipconfig2

}

####################################################################


