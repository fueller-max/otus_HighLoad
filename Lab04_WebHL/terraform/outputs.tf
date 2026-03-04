
#####################  Load Balancer  1 ###############################

output "loadbalancer1_ext_ip_address" {

  description = "Load balacner external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-1.ipconfig0
}

output "loadbalancer1_keepalived_ip_address" {

  description = "Load balancer keepalived net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-1.ipconfig1

}

output "loadbalancer1_to_backend_ip_address" {

  description = "Load balancer internal net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-1.ipconfig2

}
#######################################################################


#####################  Load Balancer  2 ###############################

output "loadbalancer2_ext_ip_address" {

  description = "Load balacner2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-2.ipconfig0

}

output "loadbalancer2_keepalived_ip_address" {

  description = "Load balancer2 keepalived net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-2.ipconfig1

}

output "loadbalancer2_to_backend_ip_address" {

  description = "Load balancer2 internal net IPv4 address: "
  value = proxmox_vm_qemu.lab04-load-balancer-2.ipconfig2

}
#####################################################################


#####################  Backend 1 ###################################

output "backend1_ext_ip_address" {

  description = "Backend1 external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend1.ipconfig0

}

output "backend1_to_balancer_ip_address" {

  description = "Backend to balancer net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend1.ipconfig1

}

output "backend1_to_database_ip_address" {

  description = "Backend to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend1.ipconfig2

}

output "backend1_to_iscsi_ip_address" {

  description = "Backend to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend1.ipconfig3

}

####################################################################


#####################  Backend 2 ###################################

output "backend2_ext_ip_address" {

  description = "Backend2 external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend2.ipconfig0

}

output "backend2_to_balancer_ip_address" {

  description = "Backend2 to balancer net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend2.ipconfig1

}

output "backend2_to_database_ip_address" {

  description = "Backend2 to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend2.ipconfig2

}

output "backend2_to_iscsi_ip_address" {

  description = "Backend2 to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend2.ipconfig3

}

####################################################################


#####################  Backend 3 ###################################

output "backend3_ext_ip_address" {

  description = "Backend3 external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend3.ipconfig0

}

output "backend3_to_balancer_ip_address" {

  description = "Backend3 to balancer net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend3.ipconfig1

}

output "backend3_to_database_ip_address" {

  description = "Backend3 to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend3.ipconfig2

}

output "backend3_to_iscsi_ip_address" {

  description = "Backend3 to database net IPv4 address: "
  value = proxmox_vm_qemu.lab04-backend3.ipconfig3

}

####################################################################


#####################  Data Base ###################################

output "database_ext_ip_address" {

  description = "Database external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-database.ipconfig0

}

output "database_to_backends_ip_address" {

  description = "Database to backend net IPv4 address: "
  value = proxmox_vm_qemu.lab04-database.ipconfig1

}

####################################################################


#####################  iSCSI ###################################

output "iscsi_ext_ip_address" {

  description = "iSCSI external net IPv4 address: "
  value = proxmox_vm_qemu.lab04-iscsi.ipconfig0

}

output "iscsi_to_backends_ip_address" {

  description = "iSCSI to balancer net IPv4 address: "
  value = proxmox_vm_qemu.lab04-iscsi.ipconfig1

}

####################################################################





