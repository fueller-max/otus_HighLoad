variable "proxmox_api_url" {
  type        = string
}

variable "proxmox_api_token_id" {
  type        = string
}

variable "proxmox_api_token_secret" {
  type        = string
}

variable vm_configs{

  type = map(object({
    vm_id       =  number
    name        =  string
    clone       =  string
    memory      =  number
    cores       =  number
    sockets     =  number
    disk_size   = string
    vm_state    =  string 
    bridge0     =  string
    bridge1     =  string
    bridge2     =  string
    ip_conf0    =  string
    ip_conf1    =  string
    ip_conf2    =  string
    start_at_node_boot =  bool
    
  }))

  default = {
    "lab14-ceph-1" = { 
        vm_id       =  171
        name        =  "lab14-ceph-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  6144
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.91/24,gw=192.168.70.1"
        bridge1     =  "vmbr8"
        ip_conf1    =  "ip=10.10.80.91/24"
        bridge2     =  "vmbr9"
        ip_conf2    =  "ip=10.10.90.91/24"
        start_at_node_boot =  true
        disk_size   = "10G"
      }
    "lab14-ceph-2" = { 
        vm_id       =  172
        name        =  "lab14-ceph-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  6144
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.92/24,gw=192.168.70.1"
        bridge1     =  "vmbr8"
        ip_conf1    =  "ip=10.10.80.92/24"
        bridge2     =  "vmbr9"
        ip_conf2    =  "ip=10.10.90.92/24"
        start_at_node_boot =  true
        disk_size   = "10G"
      }  
    "lab14-ceph-3" = { 
        vm_id       =  173
        name        =  "lab14-ceph-3"
        clone       =  "Ubuntu2404-live-server"
        memory      =  6144
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.93/24,gw=192.168.70.1"
        bridge1     =  "vmbr8"
        ip_conf1    =  "ip=10.10.80.93/24"
        bridge2     =  "vmbr9"
        ip_conf2    =  "ip=10.10.90.93/24"
        start_at_node_boot =  true
        disk_size   = "10G"
      }  

    "lab14-client-1" = { 
        vm_id       =  174
        name        =  "lab14-client-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.94/24,gw=192.168.70.1"
        bridge1     =  "vmbr8"
        ip_conf1    =  "ip=10.10.80.94/24"
        bridge2     =  "vmbr9"
        ip_conf2    =  "ip=10.10.90.94/24"
        start_at_node_boot =  true
        disk_size   = "1G"
      } 

    "lab14-client-2" = { 
        vm_id       =  175
        name        =  "lab14-client-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.95/24,gw=192.168.70.1"
        bridge1     =  "vmbr8"
        ip_conf1    =  "ip=10.10.80.95/24"
        bridge2     =  "vmbr9"
        ip_conf2    =  "ip=10.10.90.95/24"
        start_at_node_boot =  true
        disk_size   = "1G"
      }  
   }       
   
}


