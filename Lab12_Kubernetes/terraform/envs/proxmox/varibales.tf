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
    vm_state    =  string 
    bridge0     =  string
    bridge1     =  string
    ip_conf0    =  string
    ip_conf1    =  string
    network_tag0 =  number
    network_tag1 =  number
    start_at_node_boot =  bool
  }))

  default = {
    "lab12-kub-master-1" = { 
        vm_id       =  161
        name        =  "lab12-kub-master-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.48/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.48/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-master-2" = { 
        vm_id       =  162
        name        =  "lab12-kub-master-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.49/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.49/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-master-3" = { 
        vm_id       =  163
        name        =  "lab12-kub-master-3"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.50/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.50/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-lb-1" = { 
        vm_id       =  164
        name        =  "lab12-kub-lb-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.51/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.51/24"
        network_tag1 =  0
        start_at_node_boot =  true
      } 
    "lab12-kub-lb-2" = { 
        vm_id       =  165
        name        =  "lab12-kub-lb-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.52/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.52/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-worker-1" = { 
        vm_id       =  166
        name        =  "lab12-kub-worker-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  6000
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.53/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.53/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }  
    "lab12-kub-worker-2" = { 
        vm_id       =  167
        name        =  "lab12-kub-worker-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  6000
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.54/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.54/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }  
  }   
}


