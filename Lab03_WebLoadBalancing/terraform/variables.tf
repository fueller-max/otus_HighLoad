variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API url"
  default     = "https://proxmox.maxhome.net/api2/json"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
  default     = "root@pam!root_token"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  default     = "888b1514-f40b-40ed-9a41-5d2b5f6245cb"
  sensitive   = true
}

variable "storage_name" {
   type        = string
   description = "Proxmox storage name"
   default     = "vmdata"
}






