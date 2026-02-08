# Terraform скрипт

## Цель

Cоздать и запустить базовый Terraform скрипт для автоматизации установки и настройки виртуальной машины в рабочем окружении;
получить базовые навыки работы с Terraform для создания и управления инфраструктурой;
понять принципы IaC (Infrastructure as Code) и научиться применять их для автоматизации инфраструктуры;

### Задание

1. Настроить Terraform скрипт, который выполняет этапы создания, настройки и вывод параметров виртуальной машины. Скрипт должен содержать нужные параметры для автоматического создания виртуальной машины в облаке (тип, регион, операционная система, сеть).
2. Тестирование подтверждает работоспособность (скрипт выдает IP-адрес созданной машины, который соответствует результату выполнения)

Документация подробно описывает процесс

### Решение


#### 1. Настройка окружения Yandex Cloud 

* 1.1 Для работы с Yandex Cloud установим интерфейс командой строки yc на локальной машине для запуска команд касаемо работы с облаком. И настроим доступ к нашему облаку из командной строки yc:

```bash
master@home-server:~$ curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

```bash
master@home-server:~$ yc init
Welcome! This command will take you through the configuration process.
Please go to https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb in order to obtain OAuth token.
 Please enter OAuth token: y0__xDIhdxEGMHdEyClj9a***********************
You have one cloud available: 'cloud-ovchinnikov-el' (id = b1gnpkd**********). It is going to be used by default.
Please choose folder to use:
 [1] default (id = b1gb1a664rt8sd551sr1)
 [2] Create a new folder
Please enter your numeric choice: 1
Your current folder has been set to 'default' (id = b1gb1a664rt8sd551sr1).
Do you want to configure a default Compute zone? [Y/n] Y
Which zone do you want to use as a profile default?
 [1] ru-central1-a
 [2] ru-central1-b
 [3] ru-central1-d
 [4] ru-central1-k
 [5] Don't set default zone
Please enter your numeric choice: 2
Your profile default Compute zone has been set to 'ru-central1-b'.
```

* 1.2 Создание сервисного аккаунта и назначение ему ролей. Для работы с облаком создаем отдельного пользователя ("terraform") в облаке с нужными ролями ("editor").
 
```bash
master@home-server:~$ yc iam service-account create --name terraform
done (2s)
id: ajeoorfujovm***********
folder_id: b1gb1a664rt*******
created_at: "2026-02-07T14:06:42Z"
name: terraform
```

```bash
master@home-server:~$ yc iam service-account list
+----------------------+-----------+--------+---------------------+-----------------------+
|          ID          |   NAME    | LABELS |     CREATED AT      | LAST AUTHENTICATED AT |
+----------------------+-----------+--------+---------------------+-----------------------+
| ajeoorfujo********** | terraform |        | 2026-02-07 14:06:42 |                       |
+----------------------+-----------+--------+---------------------+-----------------------+
```


```bash
master@home-server:~$ yc resource-manager folder add-access-binding b1gb1a664rt8sd551sr1 --role editor --subject serviceAccount:ajeoorf**********
done (2s)
effective_deltas:
  - action: ADD
    access_binding:
      role_id: editor
      subject:
        id: ajeoorf**********
        type: serviceAccount
```


* 1.3 Добавление аутентификационных данных в переменные окружения. Данный шаг необходим для предоставления необходимых данных аутентификации для работы Terraform provider

```bash
export YC_TOKEN=$(yc iam create-token --impersonate-service-account-id ajeoorfujovmc1r9rvtp)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```


#### 2. Настройка Terraform скрипта, который выполняет все этапы: создание, настройка и вывод параметров виртуальной машины

Для автоматизированного развертывания виртуальной машины будем использовать провайдера Yandex Cloud. Также дополнительно настроим интеграцию Terraform c GitLab (локально установленный в рамках домашней сети) для хранения Terraform state.


* 2.1 Настройка провайдера Yandex Cloud в Terraform 

Создаем файл .terraformrc со указанием необходимого провайдера. В данном случае Yandex Cloud. Данные берем с сайта провайдера. Файл кладем с домашнюю директорию пользователя.

```bash
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

В конфигурационном файле main.tf вносим данные о провайдере в следующем виде:

Файл main.tf:

```bash
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = ru-central1-d
}
```

Сейчас можно сделать инициализация провайдера и убедиться, что провайдер корректно устанавливается:

```bash
master@home-server:~/terraform/projects/yacloud$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding latest version of yandex-cloud/yandex...
- Installing yandex-cloud/yandex v0.184.0...
- Installed yandex-cloud/yandex v0.184.0 (unauthenticated)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.
....
Terraform has been successfully initialized!
```

и создаются доп. файлы в директории проекта Terraform:

![](/Lab01_Terraform/pics/terrafom_init_provider.jpg)


В нашем случае также используется Gitlab terraform state интеграция, которая позволяет хранить файл состояния state в удаленном репозитории:

```bash
terraform init -migrate-state -backend-config="address=http://gitlab.maxhome.net/api/v4/projects/1/terraform/state/$TF_STATE_NAME"     -backend-config="lock_address=http://gitlab.maxhome.net/api/v4/projects/1/terraform/state/$TF_STATE_NAME/lock"     -backend-config="unlock_address=http://gitlab.maxhome.net/api/v4/projects/1/terraform/state/$TF_STATE_NAME/lock"     -backend-config="username=terraform"     -backend-config="password=$GITLAB_ACCESS_TOKEN"     -backend-config="lock_method=POST"     -backend-config="unlock_method=DELETE"     -backend-config="retry_wait_min=5"
```

Также в файле main.tf добавляем блок для бекенда:

```bash
 backend "http" {
        }
```

* 2.2 Составляем план инфраструктуры разворачиваемого окружения. 
 Развернем одну виртуальную машину на базе Ubuntu 20.04, 2 vCPU, 2 GB RAM.

Находим идентификатор образа загрузочного диска Yandex Cloud нужного образа Ubuntu 20.04:

fd833ivvmqp6cuq7shpc : ubuntu-20-04-lts

Полный файл main.tf:

```bash
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

  backend "http" {
  }

}

provider "yandex" {
  zone = "ru-central1-d"
}

resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-d"
  size     = "10"
  image_id = "fd833ivvmqp6cuq7shpc"
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"
  platform_id = "standard-v2"
  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("/home/master/terraform/projects/yacloud/meta.txt")}"
  }
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}
```

Используем блок metadata, где определена ссылка на файл meta.txt, в котором указаны данные для создания пользователя и публичный ssh-ключ, чтобы создать пользователя при развертывании машины.Используется механизм cloud-config. 

```bash
#cloud-config
users:
  - name: deploy
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGXMwIH6kOdzJdIBsl+g2oxT4sVWG940FcikV5rzaWQ homeserver@maxhome.net
```
Также определены блоки output, чтобы после создания ВМ иметь информацию о назначенных IP адресах.

Тестируем план развертывания:

```bash
master@home-server:~/terraform/projects/yacloud$ terraform plan

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # yandex_compute_disk.boot-disk-1 will be created
  + resource "yandex_compute_disk" "boot-disk-1" {
      + block_size  = 4096
      + created_at  = (known after apply)
      + folder_id   = (known after apply)
      + id          = (known after apply)
      + image_id    = "fd833ivvmqp6cuq7shpc"
      + name        = "boot-disk-1"
      + product_ids = (known after apply)
      + size        = 10
      + status      = (known after apply)
      + type        = "network-hdd"
      + zone        = "ru-central1-d"

      + disk_placement_policy (known after apply)

      + hardware_generation (known after apply)
    }

  # yandex_compute_instance.vm-1 will be created
  + resource "yandex_compute_instance" "vm-1" {
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + gpu_cluster_id            = (known after apply)
      + hardware_generation       = (known after apply)
      + hostname                  = (known after apply)
      + id                        = (known after apply)
      + maintenance_grace_period  = (known after apply)
      + maintenance_policy        = (known after apply)
      + metadata                  = {
          + "user-data" = <<-EOT
                #cloud-config
                users:
                  - name: deploy
                    groups: sudo
                    shell: /bin/bash
                    sudo: 'ALL=(ALL) NOPASSWD:ALL'
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGXMwIH6kOdzJdIBsl+g2oxT4sVWG940FcikV5rzaWQ homeserver@maxhome.net
            EOT
        }
      + name                      = "terraform1"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v2"
      + status                    = (known after apply)
      + zone                      = (known after apply)

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params (known after apply)
        }

      + metadata_options (known after apply)

      + network_interface {
          + index          = (known after apply)
          + ip_address     = (known after apply)
          + ipv4           = true
          + ipv6           = (known after apply)
          + ipv6_address   = (known after apply)
          + mac_address    = (known after apply)
          + nat            = true
          + nat_ip_address = (known after apply)
          + nat_ip_version = (known after apply)
          + subnet_id      = (known after apply)
        }

      + placement_policy (known after apply)

      + resources {
          + core_fraction = 100
          + cores         = 2
          + memory        = 2
        }

      + scheduling_policy (known after apply)
    }

  # yandex_vpc_network.network-1 will be created
  + resource "yandex_vpc_network" "network-1" {
      + created_at                = (known after apply)
      + default_security_group_id = (known after apply)
      + folder_id                 = (known after apply)
      + id                        = (known after apply)
      + labels                    = (known after apply)
      + name                      = "network1"
      + subnet_ids                = (known after apply)
    }

  # yandex_vpc_subnet.subnet-1 will be created
  + resource "yandex_vpc_subnet" "subnet-1" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet1"
      + network_id     = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.10.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-d"
    }

Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + external_ip_address_vm_1 = (known after apply)
  + internal_ip_address_vm_1 = (known after apply)

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.

```

#### 3. Запуск Terraform скрипта, проверка результатов работы

* 3.1 Запускаем развертывание виртуальной машины на основе созданного скрипта:

```bash
master@home-server:~/terraform/projects/yacloud$ terraform apply
yandex_compute_disk.boot-disk-1: Refreshing state... [id=fv4bgov3h4scnma7p8jc]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # yandex_compute_instance.vm-1 will be created
  + resource "yandex_compute_instance" "vm-1" {
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + gpu_cluster_id            = (known after apply)
      + hardware_generation       = (known after apply)
      + hostname                  = (known after apply)
      + id                        = (known after apply)
      + maintenance_grace_period  = (known after apply)
      + maintenance_policy        = (known after apply)
      + metadata                  = {
          + "user-data" = <<-EOT
                #cloud-config
                users:
                  - name: deploy
                    groups: sudo
                    shell: /bin/bash
                    sudo: 'ALL=(ALL) NOPASSWD:ALL'
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGXMwIH6kOdzJdIBsl+g2oxT4sVWG940FcikV5rzaWQ homeserver@maxhome.net
            EOT
        }
      + name                      = "terraform1"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v2"
      + status                    = (known after apply)
      + zone                      = (known after apply)

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = "fv4bgov3h4scnma7p8jc"
          + mode        = (known after apply)

          + initialize_params (known after apply)
        }

      + metadata_options (known after apply)

      + network_interface {
          + index          = (known after apply)
          + ip_address     = (known after apply)
          + ipv4           = true
          + ipv6           = (known after apply)
          + ipv6_address   = (known after apply)
          + mac_address    = (known after apply)
          + nat            = true
          + nat_ip_address = (known after apply)
          + nat_ip_version = (known after apply)
          + subnet_id      = (known after apply)
        }

      + placement_policy (known after apply)

      + resources {
          + core_fraction = 100
          + cores         = 2
          + memory        = 2
        }

      + scheduling_policy (known after apply)
    }

  # yandex_vpc_network.network-1 will be created
  + resource "yandex_vpc_network" "network-1" {
      + created_at                = (known after apply)
      + default_security_group_id = (known after apply)
      + folder_id                 = (known after apply)
      + id                        = (known after apply)
      + labels                    = (known after apply)
      + name                      = "network1"
      + subnet_ids                = (known after apply)
    }

  # yandex_vpc_subnet.subnet-1 will be created
  + resource "yandex_vpc_subnet" "subnet-1" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet1"
      + network_id     = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.10.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-d"
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + external_ip_address_vm_1 = (known after apply)
  + internal_ip_address_vm_1 = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

yandex_vpc_network.network-1: Creating...
yandex_vpc_network.network-1: Creation complete after 2s [id=enpdje8ealsj8p7sdcl4]
yandex_vpc_subnet.subnet-1: Creating...
yandex_vpc_subnet.subnet-1: Creation complete after 1s [id=fl869k7sae91pak0ud6s]
yandex_compute_instance.vm-1: Creating...
yandex_compute_instance.vm-1: Still creating... [00m10s elapsed]
yandex_compute_instance.vm-1: Still creating... [00m20s elapsed]
yandex_compute_instance.vm-1: Still creating... [00m30s elapsed]
yandex_compute_instance.vm-1: Still creating... [00m40s elapsed]
yandex_compute_instance.vm-1: Creation complete after 46s [id=fv4lbvs0v18s1tvj0png]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

external_ip_address_vm_1 = "158.160.223.144"
internal_ip_address_vm_1 = "192.168.10.28"

```

Видим, что скрипт отработал корректно и выдал в конце данные об IP адресах, используя которые можно подключится к машине.


Также машина появилась в панели управления Yandex Cloud:

![](/Lab01_Terraform/pics/vm_created.jpg)

Пробуем зайти на созданную машину под заранее заданным пользователем (deploy):

```bash

master@home-server:~/terraform/projects/yacloud$ ssh deploy@158.160.223.144
The authenticity of host '158.160.223.144 (158.160.223.144)' can't be established.
ED25519 key fingerprint is SHA256:csmJ7kE8tsyvKK41wBd1irgfH3ykgrwWeSHutMLQycE.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '158.160.223.144' (ED25519) to the list of known hosts.
Welcome to Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-51-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sun Feb  8 01:52:04 PM UTC 2026

  System load:  0.08              Processes:             132
  Usage of /:   29.7% of 9.76GB   Users logged in:       0
  Memory usage: 8%                IPv4 address for eth0: 192.168.10.28
  Swap usage:   0%

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge


deploy@fv4lbvs0v18s1tvj0png:~$

```

Видно, что подключение работает корректно с использованием ssh-ключей.

Также отработала интеграция с GitLab и state сохранился в репозитории.

![](/Lab01_Terraform/pics/gitlab_tstates.jpg)

После тестов выполним удаление созданной машины используя команду destroy: 

```bash
master@home-server:~/terraform/projects/yacloud$ terraform destroy
yandex_vpc_network.network-1: Refreshing state... [id=enpdje8ealsj8p7sdcl4]
yandex_compute_disk.boot-disk-1: Refreshing state... [id=fv4bgov3h4scnma7p8jc]
yandex_vpc_subnet.subnet-1: Refreshing state... [id=fl869k7sae91pak0ud6s]
yandex_compute_instance.vm-1: Refreshing state... [id=fv4lbvs0v18s1tvj0png]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # yandex_compute_disk.boot-disk-1 will be destroyed
  - resource "yandex_compute_disk" "boot-disk-1" {
      - block_size  = 4096 -> null
      - created_at  = "2026-02-08T13:29:24Z" -> null
      - folder_id   = "b1gb1a664rt8sd551sr1" -> null
      - id          = "fv4bgov3h4scnma7p8jc" -> null
      - image_id    = "fd833ivvmqp6cuq7shpc" -> null
      - labels      = {} -> null
      - name        = "boot-disk-1" -> null
      - product_ids = [
          - "f2ent8creb56ehrb473q",
        ] -> null
      - size        = 10 -> null
      - status      = "ready" -> null
      - type        = "network-hdd" -> null
      - zone        = "ru-central1-d" -> null
        # (2 unchanged attributes hidden)

      - disk_placement_policy {
            # (1 unchanged attribute hidden)
        }

      - hardware_generation {
          - legacy_features {
              - pci_topology = "PCI_TOPOLOGY_V1" -> null
            }
        }
    }

  # yandex_compute_instance.vm-1 will be destroyed
 
 ...

  Enter a value: yes

yandex_compute_instance.vm-1: Destroying... [id=fv4lbvs0v18s1tvj0png]
yandex_compute_instance.vm-1: Still destroying... [id=fv4lbvs0v18s1tvj0png, 00m10s elapsed]
yandex_compute_instance.vm-1: Still destroying... [id=fv4lbvs0v18s1tvj0png, 00m20s elapsed]
yandex_compute_instance.vm-1: Still destroying... [id=fv4lbvs0v18s1tvj0png, 00m30s elapsed]
yandex_compute_instance.vm-1: Destruction complete after 31s
yandex_vpc_subnet.subnet-1: Destroying... [id=fl869k7sae91pak0ud6s]
yandex_compute_disk.boot-disk-1: Destroying... [id=fv4bgov3h4scnma7p8jc]
yandex_compute_disk.boot-disk-1: Destruction complete after 1s
yandex_vpc_subnet.subnet-1: Destruction complete after 2s
yandex_vpc_network.network-1: Destroying... [id=enpdje8ealsj8p7sdcl4]
yandex_vpc_network.network-1: Destruction complete after 0s

Destroy complete! Resources: 4 destroyed.
```

Все созданные ранее ресурсы (машина, сети, диск) были успешно удалены из облака.

