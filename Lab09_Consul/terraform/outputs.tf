
#####################  Consul Cluster #########################

output "Node-consul_srv1_ext_ip_address" {

  description = "Node-es1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv1.ipconfig0

}

output "Node-consul_srv1_cluster_ip_address" {

  description = "Node-es1 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv1.ipconfig1

}

output "Node-consul_srv2_ext_ip_address" {

  description = "Node-es2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv2.ipconfig0

}

output "Node-consul_srv2_cluster_ip_address" {

  description = "Node-es1 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv2.ipconfig1

}

output "Node-consul_srv3_ext_ip_address" {

  description = "Node-es3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv3.ipconfig0

}

output "Node-consul_srv3_cluster_ip_address" {

  description = "Node-es3 to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab09-consul-srv3.ipconfig1

}

####################################################################


