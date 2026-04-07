
#####################  Elastic Search Cluster #########################

output "Node-es1_ext_ip_address" {

  description = "Node-es1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node1.ipconfig0

}

output "Node-es1_cluster_ip_address" {

  description = "Node-es1 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node1.ipconfig1

}

output "Node-es2_ext_ip_address" {

  description = "Node-es2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node2.ipconfig0

}

output "Node-es2_cluster_ip_address" {

  description = "Node-es2 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node2.ipconfig1

}

output "Node-es3_ext_ip_address" {

  description = "Node-es3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node3.ipconfig0

}

output "Node-es3_cluster_ip_address" {

  description = "Node-es3 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-es-node3.ipconfig1

}

####################################################################


#####################  Logstash  ###################################

output "Node-logstash_ext_ip_address" {

  description = "Node-logstash external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-node-logstash.ipconfig0

}

output "Node-logstash_cluster_ip_address" {

  description = "Node-logstash to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-node-logstash.ipconfig1

}

####################################################################

#####################  Kibana  ###################################

output "Node-kibana_ext_ip_address" {

  description = "Node-kibana external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-node-kibana.ipconfig0

}

output "Node-kibana_cluster_ip_address" {

  description = "Node-kibana to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-node-kibana.ipconfig1

}

####################################################################

#####################  Kafka  ######################################

output "Node-kafka1_ext_ip_address" {

  description = "Node-kibana external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node1.ipconfig0

}

output "Node-kafka1_cluster_ip_address" {

  description = "Node-kibana to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node1.ipconfig1

}

output "Node-kafka2_ext_ip_address" {

  description = "Node-kibana external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node2.ipconfig0

}

output "Node-kafka2_cluster_ip_address" {

  description = "Node-kibana to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node2.ipconfig1

}

output "Node-kafka3_ext_ip_address" {

  description = "Node-kibana external net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node3.ipconfig0

}

output "Node-kafka3_cluster_ip_address" {

  description = "Node-kibana to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab08-kafka-node3.ipconfig1

}

####################################################################
