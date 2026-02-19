# GFS2 хранилище

## Цель

* Развернуть конфигурацию для общего хранилища с GFS2, используя Terraform для автоматического создания виртуальных машин.
* Настроить базовую конфигурацию GFS2 для совместного использования диска между виртуальными машинами;

## Задание

1. Настроить Terraform скрипт, который разворачивает 4 виртуальные машины:
  * Одна виртуальная машина с iSCSI для предоставления общего диска.
  * Три виртуальные машины, которые будут использовать общую файловую систему GFS2.
2. Создать Ansible роли для GFS2, которая должна:
    * Установить необходимые пакеты (gfs2-utils, lvm2).
    * Создать тома LVM на выделенном диске от iSCSI.
    * Инициализировать и смонтировать GFS2.

3. Тестирование GFS2:
    * Подключитесь к виртуальным машинам и убедитесь, что общая файловая система корректно монтируется и доступна для записи.
    * Выполните тестовый сценарий записи данных на диск с обеих машин для проверки совместного доступа, используя команды для проверки статуса (mount, df -h).

Документация подробно описывает процесс

## Решение

### 1. Настроика Terraform скрипта.

При выполнении данного задания(и последущих) будем использовать систему виртуализации Proxmox, доступная локально. 

По заданию необходимо развернуть 4 виртуальные машины. Одна из которых будет выполнять роль iSCSI таргета, а 3 другие роль iSCSC инициаторов, которые будут иметь доступ к выделенному диску iSCSI таргета. Также будет развернута файловая система общего доступа GFS2 для работы с данным диском. При разворачивании учтем необходимость наличия дополнительного диска на iSCSI таргете.

Файл tf для iscsi - таргет машины представлен ниже

<details>
  <summary>iscsi.tf</summary>
 
 ```bash 
resource "proxmox_vm_qemu" "iscsi" {
    name = "iscsi"
    description = "Node for iSCSI (target)"

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox"

    # The template name to clone this vm from
    clone = "Ubuntu2404-Template"

    # Activate QEMU agent for this VM
    #agent = 1

    os_type = "cloud-init"

    cpu {
        cores = 2
        sockets = 1
        type = "host"
    }
    memory = 2048
    scsihw = "virtio-scsi-single"

    # Setup the disk
    disks {
        ide {
            ide3 {
                cloudinit {
                    storage = var.storage_name
                }
            }
        }
        virtio {
            virtio0 {
                disk {
                    size            = "10G"
                    storage         = var.storage_name
                    replicate       = true
                }
            }
            virtio1 {
                disk {
                    size            = "10G"
                    storage         = var.storage_name
                    replicate       = true
                }
            }
        }
    }

    # Setup the network interface 
    network {
        id = 0
        model = "virtio"
        bridge = "vmbr0"
    }

    # Setup the ip address using cloud-init.
    boot = "order=virtio0"
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=192.168.70.20/24,gw=192.168.70.1"
    nameserver = "8.8.8.8"
    ciuser = "deploy"
    sshkeys = <<EOF
       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwOGqPyDBruydkg1DPItwaBBwo5/5gAaBYeshgNFmlS maksim@maksim-asus-tuf
     EOF
}
```
</details>

Файл tf для iscsi - инициатора  машины представлен ниже. Все три машины полностью аналогичны

<details>
  <summary>gfs1.tf</summary>
  
  ```bash
resource "proxmox_vm_qemu" "gfs1" {
    name = "gfs1"
    description = "Node for 1st node with gfs2"

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox"

    # The template name to clone this vm from
    clone = "Ubuntu2404-Template"

    # Activate QEMU agent for this VM
    #agent = 1

    os_type = "cloud-init"

    cpu {
        cores = 2
        sockets = 1
        type = "host"
    }
    memory = 2048
    scsihw = "virtio-scsi-single"

    # Setup the disk
    disks {
        ide {
            ide3 {
                cloudinit {
                    storage = var.storage_name
                }
            }
        }
        virtio {
            virtio0 {
                disk {
                    size            = "10G"
                    storage         = var.storage_name
                    replicate       = true
                }
            }
            
        }
    }

    # Setup the network interface 
    network {
        id = 0
        model = "virtio"
        bridge = "vmbr0"
    }

    # Setup the ip address using cloud-init.
    boot = "order=virtio0"
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=192.168.70.31/24,gw=192.168.70.1"
    nameserver = "8.8.8.8"
    ciuser = "deploy"
    sshkeys = <<EOF
       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwOGqPyDBruydkg1DPItwaBBwo5/5gAaBYeshgNFmlS maksim@maksim-asus-tuf
     EOF
}
```
</details>

Файлы terraform.tf и provider.tf:

<details>
  <summary>terraform.tf</summary>
  
  ```bash
terraform {
  required_providers {
    
    # Provder to manage Proxmox hypervisor
    proxmox = {
        source = "telmate/proxmox"
        version = "3.0.2-rc07"
    }
    
    # Provider to manage terraform outputs to local files
    local = {
        source = "hashicorp/local"
        version = "2.7.0"
    }

  }
}

```
</details>

<details>
  <summary>provider.tf</summary>
  
  ```bash
  provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_api_token_id = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure = true
}


provider "local" {
  # Configuration options
}
```
</details>

Полностью проект Terrafrom представлен в соответствующей директории.

Результатом работы Terrafrom скрипта явлется развернутые 4 машины iscsi, gfs1, gfs2, gfs3:

![](/Lab02_GFS2/pics/Proxmox_4VMs.png)

### 2. Создание Ansible роли для iSCSI и GFS2

 Напишем общий плейбук, который будет выполнять настройку iSCSI и GFS2. В качестве организационных модулей будем использовать роли.

 Общий Ansible плейбук:

<details>
  <summary>main.yaml</summary>

  ``` bash
  - name: Manage iSCSI target node
    hosts: iscsi
    become: true
    roles:
       - role: iscsi-target

  - name: Manage iSCSI initiator nodes 
    hosts: clients
    become: true
    gather_facts: true
    vars:
        open_iscsi_initiator_name: "{{ iscsi_initiator_name }}"
        open_iscsi_authentication: false
        open_iscsi_automatic_startup: true
        open_iscsi_targets:
          - name: 'target1'
            discover: true
            auto_portal_startup: true
            auto_node_startup: true
            target: "{{ iscsi_target }}"
            portal: "{{ iscsi_target_portal }}"
            login: true
       
    roles:
        - role: ricsanfre.iscsi_initiator

  - name: Manage DNS hosts for iSCSI clients (for Corosync and GFS2)
     hosts: clients
     become: true
     roles:
       - dns-hosts     

  - name: Manage neccessary package infrastructure(GFS2, Corosync, DLM)   for iSCSI initiators 
    hosts: clients
    become: true
    roles:
       - ha-gfs-infra 

  - name: Deploy GFS2 on iSCSI initiators
    hosts: clients
    become: true
    roles:
     - gfs2-deploy
  ```
</details>

Расcмотрим роли по отдельности. Роль iscsi-target выполняет настройку iSCSI таргета. В данном плейбуке используем работу с targetcli в режиме "one-shot" - каждая команда выполняется в отдельной таске. Также в рамках данного плейбука выполняем настройку LVM, создав LV объемом 5G, который будем предоставлять для дотсупа в рамках iSCSI. Работа через LVM не обязательна для iSCSI(можно и целиком отдать блочное устройство), однако рекомендуется в рамках обеспечения гибкости при дальнейших возможных изменениях / настройках.

<details>
  <summary>iscsi-target</summary>
  
  ```bash
    - name: Install iSCSI target packages
      ansible.builtin.package:
         name:
           - targetcli-fb
         state: present
      when: ansible_facts["os_family"] == "Debian"

    - name: Install iSCSI target packages (RHEL/CentOS)
      ansible.builtin.yum:
         name:
           - scsi-target-utils
         state: present
      when: ansible_facts["os_family"] == "RedHat"

    - name: Create LVM for iscsi target
      ansible.builtin.shell: |
         pvcreate /dev/vdb
         vgcreate vg_iscsi /dev/vdb
         lvcreate -L {{ lvm_size }} -n lun1 vg_iscsi


    - name: Create backstore
      ansible.builtin.shell: "targetcli /backstores/block create name=iscsi_lun1 dev=/dev/vg_iscsi/lun1"
      register: result
      failed_when: result.rc != 0 and 'already exists' not in result.stderr

    - name: Create iSCSI target
      ansible.builtin.shell: "targetcli /iscsi create {{ target_iqn }}"
  
    - name: Create LUN
      ansible.builtin.shell: "targetcli /iscsi/{{ target_iqn }}/tpg1/luns/ create /backstores/block/iscsi_lun1"

    - name: Disable authentication
      ansible.builtin.shell: "targetcli /iscsi/{{ target_iqn }}/tpg1 set attribute authentication=0"

    - name: Add ACL for the first client
      ansible.builtin.shell: "targetcli /iscsi/{{ target_iqn }}/tpg1/acls create {{ ign }}:{{ client1_hostname }}"  
    
    - name: Add ACL for the second client
      ansible.builtin.shell: "targetcli /iscsi/{{ target_iqn }}/tpg1/acls create {{ ign }}:{{ client2_hostname }}"

    - name: Add ACL for the third client
      ansible.builtin.shell: "targetcli /iscsi/{{ target_iqn }}/tpg1/acls create {{ ign }}:{{ client3_hostname }}"

    - name: Save configuration
      ansible.builtin.shell: "targetcli saveconfig" 
   

    - name: Enable rtslib-fb-targetctl
      ansible.builtin.service:
        name: rtslib-fb-targetctl
        enabled: yes
        state: restarted
```
</details>

Следующая роль ricsanfre.iscsi_initiator служит для настройки iSCSI инциаторов. Данная роль взята из ansible-galaxy и мы предоставляем только настроечные данные в секции vars. 

<details>
  <summary>ricsanfre.iscsi_initiator</summary>

```bash
    vars:
       # 1. Define the iSCSI Initiator Name (IQN)
        # This will update /etc/iscsi/initiatorname.iscsi
        # host_vars -> host
        open_iscsi_initiator_name: "{{ iscsi_initiator_name }}"
        open_iscsi_authentication: false
        open_iscsi_automatic_startup: true
        # 2. Specify the iSCSI target details for automatic connection
        # group_vars
        open_iscsi_targets:
          - name: 'target1'
            discover: true
            auto_portal_startup: true
            auto_node_startup: true
            target: "{{ iscsi_target }}"
            portal: "{{ iscsi_target_portal }}"
            login: true
       
    roles:
        - role: ricsanfre.iscsi_initiator
 ```       
</details>



Эти две роли выполняют настройку iSCSI c обехи сторон и результатом должен быть работающий таргет и подключенные блочные устройства на клиентах (инциаторах).


Следующий этап - настройка GFS2.

Здесь присутствуют три роли:

 - Роль dns-hosts выполняет задачу по апдейту /etc/hosts для обеспечения связности узлов в рамках доменных имен - необходимо для корректной работы Corosync.

 <details>
  <summary>dns-hosts</summary>
  
  ```bash
  - name: Replace the whole content of /etc/hosts
  ansible.builtin.template:
      src:  templates/hosts.j2          
      dest: /etc/hosts      
      owner: root                           
      group: root                           
      mode: '0644'
  ```

  ```bash

  ### hosts.j2##########
  {# The value '{{hostname}}' will be replaced with the local-hostname -#}
127.0.1.1 {{ ansible_facts['hostname'] }} {{ ansible_facts['hostname'] }}
127.0.0.1 localhost

{{ client1_ip }} {{ client1_hostname }}.local  {{ client1_hostname }}
{{ client2_ip }} {{ client2_hostname }}.local  {{ client2_hostname }}
{{ client3_ip }} {{ client3_hostname }}.local  {{ client3_hostname }}

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```
</details>

2-ая роль ha-gfs-infra. Ее здача установка необходимых пакетов:
  * gfs2-utils 
  * corosync 
  * dlm-controld

  И настройка Сorosync путем конфигурирования  /etc/corosync/corosync.conf:

  <details>
  <summary>ha-gfs-infra</summary>

  ```bash

   - name: Install list of neccessary packages
     package:
      name:
          - gfs2-utils 
          - corosync 
          - dlm-controld
      state: present

   - name: Template and copy corosync.conf  
     ansible.builtin.template:
      src:  templates/corosync.conf.j2         
      dest: /etc/corosync/corosync.conf     
      owner: root                           
      group: root                           
      mode: '0644'      

   - name: Restart Corosync service
     ansible.builtin.service:
        name: corosync
        enabled: yes
        state: restarted
  ``` 
 </details>

 Темплейт файла /etc/corosync/corosync.conf:

 <details>
  <summary>corosync.conf</summary>

  ```bash
   # Please read the corosync.conf.5 manual page
   system {
	# This is required to use transport=knet in an unprivileged
	# environment, such as a container. See man page for details.
	allow_knet_handle_fallback: yes
   }

    totem {
	 version: 2

	# Corosync itself works without a cluster name, but DLM needs one.
	# The cluster name is also written into the VG metadata of newly
	# created shared LVM volume groups, if lvmlockd uses DLM locking.
	cluster_name: {{ corosync_cluster_name }}

	# crypto_cipher and crypto_hash: Used for mutual node authentication.
	# If you choose to enable this, then do remember to create a shared
	# secret with "corosync-keygen".
	# enabling crypto_cipher, requires also enabling of crypto_hash.
	# crypto works only with knet transport
	crypto_cipher: none
	crypto_hash: none
   }

   logging {
	# Log the source file and line where messages are being
	# generated. When in doubt, leave off. Potentially useful for
	# debugging.
	fileline: off
	# Log to standard error. When in doubt, set to yes. Useful when
	# running in the foreground (when invoking "corosync -f")
	to_stderr: yes
	# Log to a log file. When set to "no", the "logfile" option
	# must not be set.
	to_logfile: yes
	logfile: /var/log/corosync/corosync.log
	# Log to the system log daemon. When in doubt, set to yes.
	to_syslog: yes
	# Log debug messages (very verbose). When in doubt, leave off.
	debug: off
	# Log messages with time stamps. When in doubt, set to hires (or on)
	#timestamp: hires
	logger_subsys {
		subsys: QUORUM
		debug: off
	}
   }

   quorum {
	 # Enable and configure quorum subsystem (default: off)
	 # see also corosync.conf.5 and votequorum.5
	 provider: corosync_votequorum
   }

   nodelist {
	# Change/uncomment/add node sections to match cluster configuration

	node {
		# Hostname of the node.
		# name: {{ client1_hostname }}
		# Cluster membership node identifier
		nodeid: 1
        quorum_votes: 1
		# Address of first link
		ring0_addr: {{ client1_ip }}
	}

    node {
		# Hostname of the node.
		# name: {{ client2_hostname }}
		# Cluster membership node identifier
		nodeid: 2
        quorum_votes: 1
		# Address of first link
		ring0_addr: {{ client2_ip }}
	}

    node {
		# Hostname of the node.
		# name: {{ client3_hostname }}
		# Cluster membership node identifier
		nodeid: 3
        quorum_votes: 1
		# Address of first link
		ring0_addr: {{ client3_ip }}
	}
	
  }

``` 
</details>

И третья роль gfs2-deploy, задача которой создать и примонтировать gfs2 на клиентах. Роль создает gfs2 на iSCSI разделе на одном из клиентов (1ом), и далее этот раздел примонтируется к точке /mnt/gfs2/ на каждом из клиентов отдельно. Физически это один общий диск с gfs2 на 3 клиента, к которому обеспечивается конкурентный доступ. 


<details>
  <summary>gfs2-deploy</summary>

  ```bash
  - name: Create File System GFS2 on the first client  
  ansible.builtin.shell: |
        echo "y" | mkfs.gfs2 -p lock_dlm -t {{ corosync_cluster_name }}:clusterdisk -j 3 {{ dev }}
  when: ansible_facts["hostname"] == "gfs1"

##
## -p lock_dlm                    позволяет осуществлять блокировку на основе DLM для использования в конфигурациях общего хранилищ
##  t <clustername>:<lockspace>   пара "таблица блокировки", используемая для уникальной идентификации этой файловой системы в кластере
##  clustername -> /etc/corosync/corosync.conf
## -j 3                           количество журналов, которые необходимо создать для mkfs.gfs2.
##

- name: Create mount point on each client 
  ansible.builtin.shell: |
         mkdir /mnt/gfs2/

        
- name: Read UUID of a created disk 
  ansible.builtin.shell:  blkid -s UUID -o value /dev/sda
  register: sda_uuid
 
- name: Print the value of UUID 
  ansible.builtin.debug:
    var: sda_uuid.stdout
  when: ansible_facts["hostname"] == "gfs1"   

- name: Mount disk using UUID
  ansible.builtin.shell: |
      mount -U {{ sda_uuid.stdout }} /mnt/gfs2/ -o noatime   

  ```
</details>

Полный проект ansible представлен в соответствующем каталоге. 

### 3. Тестирование.

Сначала проверим работу отдельных систем. 

Убедимся, что iSCSI таргет работает корректно. Для этого воспользуемся утилитой targetcli и посмотрим на актуальный конфиг: 
```bash
deploy@iscsi:~$ sudo targetcli
targetcli shell version 2.1.53
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> ls
o- / ......................................................................................................................... [...]
  o- backstores .............................................................................................................. [...]
  | o- block .................................................................................................. [Storage Objects: 1]
  | | o- iscsi_lun1 ............................................................. [/dev/vg_iscsi/lun1 (5.0GiB) write-thru activated]
  | |   o- alua ................................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ....................................................................... [ALUA state: Active/optimized]
  | o- fileio ................................................................................................. [Storage Objects: 0]
  | o- pscsi .................................................................................................. [Storage Objects: 0]
  | o- ramdisk ................................................................................................ [Storage Objects: 0]
  o- iscsi ............................................................................................................ [Targets: 1]
  | o- iqn.2026-02.org.test:target1 ...................................................................................... [TPGs: 1]
  |   o- tpg1 ............................................................................................... [no-gen-acls, no-auth]
  |     o- acls .......................................................................................................... [ACLs: 3]
  |     | o- iqn.2026-02.org.test:gfs1 ............................................................................ [Mapped LUNs: 1]
  |     | | o- mapped_lun0 ............................................................................ [lun0 block/iscsi_lun1 (rw)]
  |     | o- iqn.2026-02.org.test:gfs2 ............................................................................ [Mapped LUNs: 1]
  |     | | o- mapped_lun0 ............................................................................ [lun0 block/iscsi_lun1 (rw)]
  |     | o- iqn.2026-02.org.test:gfs3 ............................................................................ [Mapped LUNs: 1]
  |     |   o- mapped_lun0 ............................................................................ [lun0 block/iscsi_lun1 (rw)]
  |     o- luns .......................................................................................................... [LUNs: 1]
  |     | o- lun0 ....................................................... [block/iscsi_lun1 (/dev/vg_iscsi/lun1) (default_tg_pt_gp)]
  |     o- portals .................................................................................................... [Portals: 1]
  |       o- 0.0.0.0:3260 ..................................................................................................... [OK]
  o- loopback ......................................................................................................... [Targets: 0]
  o- vhost ............................................................................................................ [Targets: 0]
/> 

```

Также убедимся, что таргет слушает на порту 3260 (дефолтный для iSCSI)

```bash
deploy@iscsi:~$ ss -tulpn
Netid         State           Recv-Q          Send-Q                   Local Address:Port                   Peer Address:Port         Process         
udp           UNCONN          0               0                           127.0.0.54:53                          0.0.0.0:*                            
udp           UNCONN          0               0                        127.0.0.53%lo:53                          0.0.0.0:*                            
tcp           LISTEN          0               4096                        127.0.0.54:53                          0.0.0.0:*                            
tcp           LISTEN          0               4096                     127.0.0.53%lo:53                          0.0.0.0:*                            
tcp           LISTEN          0               4096                           0.0.0.0:22                          0.0.0.0:*                            
tcp           LISTEN          0               256                            0.0.0.0:3260                        0.0.0.0:*                            
tcp           LISTEN          0               4096                              [::]:22                             [::]:*  
```

Проверим на одном из клиентов, что подключение по iSCSI работает:

```bash
deploy@gfs1:~$ sudo iscsiadm -m node -P 1
Target: iqn.2026-02.org.test:target1
	Portal: 192.168.70.20:3260,1
		Iface Name: default
```

Далее, на клиенте также убедимся, что Corosync работает нормально и есть кворум из 3 узлов:

```bash
deploy@gfs1:~$ sudo corosync-quorumtool -s
Quorum information
------------------
Date:             Thu Feb 19 14:58:54 2026
Quorum provider:  corosync_votequorum
Nodes:            3
Node ID:          1
Ring ID:          1.12
Quorate:          Yes

Votequorum information
----------------------
Expected votes:   3
Highest expected: 3
Total votes:      3
Quorum:           2  
Flags:            Quorate 

Membership information
----------------------
    Nodeid      Votes Name
         1          1 gfs1.local (local)
         2          1 gfs2.local
         3          1 gfs3.local
```

Результатом увляется подмонитрованный раздел /mnt/gfs2 на всех клиентах размеров в 5GB (/dev/sda):

```bash
deploy@gfs1:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0    5G  0 disk /mnt/gfs2
sr0      11:0    1    4M  0 rom  
vda     253:0    0   10G  0 disk 
├─vda1  253:1    0    9G  0 part /
├─vda14 253:14   0    4M  0 part 
├─vda15 253:15   0  106M  0 part /boot/efi
└─vda16 259:0    0  913M  0 part /boot
```

```bash
deploy@gfs2:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0    5G  0 disk /mnt/gfs2
sr0      11:0    1    4M  0 rom  
vda     253:0    0   10G  0 disk 
├─vda1  253:1    0    9G  0 part /
├─vda14 253:14   0    4M  0 part 
├─vda15 253:15   0  106M  0 part /boot/efi
└─vda16 259:0    0  913M  0 part /boot
```
```bash
deploy@gfs3:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0    5G  0 disk /mnt/gfs2
sr0      11:0    1    4M  0 rom  
vda     253:0    0   10G  0 disk 
├─vda1  253:1    0    9G  0 part /
├─vda14 253:14   0    4M  0 part 
├─vda15 253:15   0  106M  0 part /boot/efi
└─vda16 259:0    0  913M  0 part /boot
```

Проверим фактическую работу раздела путем записи файла размером в 1GB из каждого из клиента в данный раздел.

```bash
deploy@gfs1:~$ sudo dd if=/dev/urandom of=/mnt/gfs2/bench1.img bs=1M count=1000
1000+0 records in
1000+0 records out
1048576000 bytes (1.0 GB, 1000 MiB) copied, 2.70044 s, 388 MB/s

deploy@gfs2:~$ sudo dd if=/dev/urandom of=/mnt/gfs2/bench2.img bs=1M count=1000
1000+0 records in
1000+0 records out
1048576000 bytes (1.0 GB, 1000 MiB) copied, 4.4612 s, 235 MB/s

deploy@gfs3:~$ sudo dd if=/dev/urandom of=/mnt/gfs2/bench3.img bs=1M count=1000
1000+0 records in
1000+0 records out
1048576000 bytes (1.0 GB, 1000 MiB) copied, 4.4557 s, 235 MB/s
```
Проверяем, что на всех клиентах файлы отображаются корректно.

```bash
deploy@gfs1:~$ sudo ls /mnt/gfs2/ -lh
total 3.0G
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench1.img
-rw-r--r-- 1 root root 1000M Feb 19 12:52 bench2.img
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench3.img

deploy@gfs2:~$ sudo ls /mnt/gfs2/ -lh
total 3.0G
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench1.img
-rw-r--r-- 1 root root 1000M Feb 19 12:52 bench2.img
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench3.img

deploy@gfs3:~$ sudo ls /mnt/gfs2/ -lh
total 3.0G
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench1.img
-rw-r--r-- 1 root root 1000M Feb 19 12:52 bench2.img
-rw-r--r-- 1 root root 1000M Feb 19 12:53 bench3.img
```

Как видим, раздел работает корректно. Также обеспечивается высокая скорость его работы - порядка 200-300 MB/s. Однако это с учетом связи машин непосредственно через сетевой бридж-интерфейса гипервизора.


### 4. Выводы

В рамках данной лабораторной работы был настроен стенд для демонстрации работы протоколов iSCSI для предоставления блочных устройств по сети, а также работа файловой системы GFS2. Выполнена базовая настройка систем без настроек более жесткой аутентификации. Также рекомендуется настройка Pacemaker для автоматического монтирования разделов GFS2. 
В рамках данной работы также применен раздельный запуск скрипта terrafrom и плейбука ansible. В последующих работах будет изучен метод совместного запуска для реализации единого сценария автоматизации.  