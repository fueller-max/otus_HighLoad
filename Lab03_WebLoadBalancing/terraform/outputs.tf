
#####################  Load Balancer ###############################

output "loadbalancer_ext_ip_address" {

  description = "Load balacner external net IPv4 address: "
  value = proxmox_vm_qemu.load-balancer.ipconfig0

}

output "loadbalancer_to_backend_ip_address" {

  description = "Load balancer internal net IPv4 address: "
  value = proxmox_vm_qemu.load-balancer.ipconfig1

}
####################################################################


#####################  Backend 1 ###################################

output "backend1_ext_ip_address" {

  description = "Backend1 external net IPv4 address: "
  value = proxmox_vm_qemu.backend1.ipconfig0

}

output "backend1_to_balancer_ip_address" {

  description = "Backend to balancer net IPv4 address: "
  value = proxmox_vm_qemu.backend1.ipconfig1

}

output "backend1_to_database_ip_address" {

  description = "Backend to database net IPv4 address: "
  value = proxmox_vm_qemu.backend1.ipconfig2

}

####################################################################



#####################  Backed 2 ####################################

output "backend2_ext_ip_address" {

  description = "Backend2 external net IPv4 address: "
  value = proxmox_vm_qemu.backend2.ipconfig0

}

output "backend2_to_balancer_ip_address" {

  description = "Backend 2 to balancer net IPv4 address: "
  value = proxmox_vm_qemu.backend2.ipconfig1

}

output "backend2_to_database_ip_address" {

  description = "Backend 2 to database net IPv4 address: "
  value = proxmox_vm_qemu.backend2.ipconfig2

}

####################################################################

#####################  Backed 3 ####################################

output "backend3_ext_ip_address" {

  description = "Backend2 external net IPv4 address: "
  value = proxmox_vm_qemu.backend3.ipconfig0

}

output "backend3_to_balancer_ip_address" {

  description = "Backend 3 to balancer net IPv4 address: "
  value = proxmox_vm_qemu.backend3.ipconfig1

}

output "backend3_to_database_ip_address" {

  description = "Backend 3 to database net IPv4 address: "
  value = proxmox_vm_qemu.backend3.ipconfig2

}

####################################################################


#####################  Data Base ###################################

output "database_ext_ip_address" {

  description = "Backend2 external net IPv4 address: "
  value = proxmox_vm_qemu.database.ipconfig0

}

output "database_to_backends_ip_address" {

  description = "Backend 3 to balancer net IPv4 address: "
  value = proxmox_vm_qemu.database.ipconfig1

}

####################################################################





