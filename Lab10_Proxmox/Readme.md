# Развертывание виртуальных машин на Proxmox с помощью Terraform

## Цель

Научиться писать Terraform-скрипты для развёртывания виртуальных машин в Proxmox

## Задание

1. Настройте подключение Terraform к Proxmox.
2. Напишите скрипт для развёртывания хотя бы одной виртуальной машины.
3. Укажите параметры ВМ: имя, CPU, RAM, диск, сеть.
4. Запустите terraform apply и проверьте, что ВМ создана.

## Решение

```bash

maksim@maksim-asus-tuf:~/otus/git_repo/otus_HighLoad/Lab10_Proxmox/terraform$ terraform plan

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # proxmox_vm_qemu.lab10_ubuntu_24 will be created
  + resource "proxmox_vm_qemu" "lab10_ubuntu_24" {
      + additional_wait           = 5
      + agent                     = 0
      + agent_timeout             = 90
      + automatic_reboot          = true
      + automatic_reboot_severity = "error"
      + balloon                   = 0
      + bios                      = "seabios"
      + boot                      = "order=virtio0"
      + bootdisk                  = (known after apply)
      + ciupgrade                 = false
      + ciuser                    = "deploy"
      + clone                     = "Ubuntu2404-live-server"
      + clone_wait                = 10
      + current_node              = (known after apply)
      + default_ipv4_address      = (known after apply)
      + default_ipv6_address      = (known after apply)
      + define_connection_info    = true
      + description               = "lab10_ubuntu_24"
      + force_create              = false
      + full_clone                = true
      + hotplug                   = "network,disk,usb"
      + id                        = (known after apply)
      + ipconfig0                 = "ip=192.168.70.101/24,gw=192.168.70.1"
      + kvm                       = true
      + linked_vmid               = (known after apply)
      + memory                    = 2048
      + name                      = "lab10-ubuntu-24"
      + nameserver                = "8.8.8.8"
      + os_type                   = "cloud-init"
      + protection                = false
      + reboot_required           = (known after apply)
      + scsihw                    = "virtio-scsi-single"
      + skip_ipv4                 = false
      + skip_ipv6                 = false
      + ssh_host                  = (known after apply)
      + ssh_port                  = (known after apply)
      + sshkeys                   = <<-EOT
            ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwOGqPyDBruydkg1DPItwaBBwo5/5gAaBYeshgNFmlS maksim@maksim-asus-tuf
        EOT
      + tablet                    = true
      + target_node               = "proxmox"
      + unused_disk               = (known after apply)
      + vm_state                  = "running"
      + vmid                      = (known after apply)

      + cpu {
          + cores   = 2
          + limit   = 0
          + numa    = false
          + sockets = 1
          + type    = "host"
          + units   = 0
          + vcores  = 0
        }

      + disks {
          + ide {
              + ide3 {
                  + cloudinit {
                      + storage = "vmdata2"
                    }
                }
            }
          + virtio {
              + virtio0 {
                  + disk {
                      + backup               = true
                      + format               = "raw"
                      + id                   = (known after apply)
                      + iops_r_burst         = 0
                      + iops_r_burst_length  = 0
                      + iops_r_concurrent    = 0
                      + iops_wr_burst        = 0
                      + iops_wr_burst_length = 0
                      + iops_wr_concurrent   = 0
                      + linked_disk_id       = (known after apply)
                      + mbps_r_burst         = 0
                      + mbps_r_concurrent    = 0
                      + mbps_wr_burst        = 0
                      + mbps_wr_concurrent   = 0
                      + replicate            = true
                      + size                 = "12G"
                      + storage              = "vmdata2"
                    }
                }
            }
        }

      + network {
          + bridge    = "vmbr0"
          + firewall  = false
          + id        = 0
          + link_down = false
          + macaddr   = (known after apply)
          + model     = "virtio"
        }

      + smbios (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + lab10_ubuntu_24_ext_ip_address = "ip=192.168.70.101/24,gw=192.168.70.1"

```



```bash
maksim@maksim-asus-tuf:~$ ssh deploy@192.168.70.101
The authenticity of host '192.168.70.101 (192.168.70.101)' can't be established.
ED25519 key fingerprint is SHA256:yc4bZW+41mcZUq7pCY7NEx4grw74qO4OCsQCJY39n4w.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.70.101' (ED25519) to the list of known hosts.
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-101-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sun Apr 26 02:03:23 PM UTC 2026

  System load:  0.93              Processes:             111
  Usage of /:   51.0% of 9.75GB   Users logged in:       0
  Memory usage: 12%               IPv4 address for eth0: 192.168.70.101
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

6 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


The list of available updates is more than a week old.
To check for new updates run: sudo apt update

deploy@lab10-ubuntu-24:~$ 

``