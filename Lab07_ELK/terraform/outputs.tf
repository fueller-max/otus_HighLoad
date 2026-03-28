
#####################  Elastic Search Cluster #########################

output "Node-es1_ext_ip_address" {

  description = "Node-es1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node1.ipconfig0

}

output "Node-es1_cluster_ip_address" {

  description = "Node-es1 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node1.ipconfig1

}

output "Node-es2_ext_ip_address" {

  description = "Node-es2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node2.ipconfig0

}

output "Node-es2_cluster_ip_address" {

  description = "Node-es2 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node2.ipconfig1

}

output "Node-es3_ext_ip_address" {

  description = "Node-es3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node3.ipconfig0

}

output "Node-es3_cluster_ip_address" {

  description = "Node-es3 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab07-es-node3.ipconfig1

}

####################################################################


#####################  Logstash  ###################################

output "Node-logstash_ext_ip_address" {

  description = "Node-logstash external net IPv4 address: "
  value = proxmox_vm_qemu.lab07-node-logstash.ipconfig0

}

output "Node-logstash_cluster_ip_address" {

  description = "Node-logstash to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab07-node-logstash.ipconfig1

}

####################################################################

#####################  Kibana  ###################################

output "Node-kibana_ext_ip_address" {

  description = "Node-kibana external net IPv4 address: "
  value = proxmox_vm_qemu.lab07-node-kibana.ipconfig0

}

output "Node-kibana_cluster_ip_address" {

  description = "Node-kibana to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab07-node-kibana.ipconfig1

}

####################################################################
