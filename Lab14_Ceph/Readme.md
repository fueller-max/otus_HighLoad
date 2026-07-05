# Отказоустойчивое хранилище на Ceph

## Цель

Развернуть отказоустойчивый кластер хранения данных на базе Ceph

## Задание

1. Разверните отказоустойчивый кластер Ceph с помощью Terraform и Ansible (можно использовать ceph-ansible)
* Установите фактор репликации ≥2
* Рассчитайте объём хранилища и число PG для пулов: RBD — 50–100%,  CephFS — 30% 
2. Подключите клиентские машины: 
* Пробросьте 3 RBD-тома
* Настройте CephFS как общий раздел для всех клиентов
3. Отработайте аварийные сценарии
*  Сгенерировать split-brain, посмотреть поведение кластера, решить проблему 
*  Сгенерировать сбой ноды с osd, вывести из кластера, добавить новую
*  Расширить кластер на 2+osd, сделать перерасчёт pg, объяснить логику
*  Уменьшить кластер на 1+osd, сделать перерасчёт pg, объяснить логику


## Решение
### 0. Подготовка виртуальных машин для развертывания хранилища

Для развертывания стенда для отказоустойчивого хранилища на Ceph создаем 3 виртуальные машины на Proxmox. Каждая ВМ помимо основого диска будет дополнитально содержать по 3 диска объемом 10Gb, которые будут использоваться в качестве OSD (планируется всего 9 OSD в кластере).
Манифесты развертывания terraform находятся в соответствующем каталоге работы.

### 1. Boostratp отказоустойчивого хранилища

Для развораичвания кластера будем использовать рекомендованная актуальную ansible коллекцию cephadm-ansible (не deprecated ceph-ansible). 

[githab cephadm-ansible](https://github.com/ceph/cephadm-ansible)

Данная коллекция позволяет упростить процесс развертывания и работает в связке с cephadm, автоматизируя задачи, которые не покрываются cephadm. Такие как:
* подготовка узлов кластера с установкой необходимых пакетов и контейнерезации
* дистрибуция ssh ключей по нодам кластера
* подготовка клиентов
* удаление кластера

и т.д. 

#### 1.1 Первичная настройки нод кластера :

Используем плейбук для **cephadm-preflight.yml** для первичной настройки нод кластера: 
```bash
ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-preflight.yml --limit "nodes"
```

#### 1.2. Первичный Bootstrap с указанием сетей:

После успешной первичной настройки нод кластера на первой ноде делаем первичный Bootstrap кластера Ceph с указанием внешней и внутренней сети кластера с использованием cephadm:
```bash
sudo cephadm bootstrap \
  --mon-ip 192.168.70.91 \
  --cluster-network 10.10.90.0/24 \
  --initial-dashboard-user admin \
  --initial-dashboard-password admin
```

### 1.3 Дистрибуция ssh ключей по нодам кластера 
Для бутстрапа оставшихся нод кластера нужно обеспечить передачу ssh ключей с первой ноды на них.

Запускаем плейбук **cephadm-distribute-ssh-key.yml** для раздачи ssh ключей по нодам кластера:

```bash
ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-distribute-ssh-key.yml -e cephadm_ssh_user=deploy -e admin_node=lab14-ceph-1 --limit "nodes" 
```

### 4. Финальный Bootstrap кластера

Запускаем финальный Bootstrap кластера с передачей файла конфигурации cluster-spec.yaml использованием cephadm:

```bash
deploy@lab14-ceph-1:/tmp$ sudo cephadm shell --mount cluster-spec.yaml:/etc/ceph/cluster-spec.yaml 
Inferring fsid 5e937263-77c4-11f1-a207-bc2411b0df56
Inferring config /var/lib/ceph/5e937263-77c4-11f1-a207-bc2411b0df56/mon.lab14-ceph-1/config
root@lab14-ceph-1:/# ceph orch apply -i /etc/ceph/cluster-spec.yaml
```
Файл конфигурации cluster-spec.yaml:

<details><summary>cluster-spec.yaml</summary>

```yaml
# 1. DEFINE THE STORAGE HOSTS
service_type: host
hostname: lab14-ceph-1
addr: 192.168.70.91
labels:
  - mon
  - mgr
  - osd
  - mds
---
service_type: host
hostname: lab14-ceph-2
addr: 192.168.70.92
labels:
  - mon
  - mgr
  - osd
  - mds
---
service_type: host
hostname: lab14-ceph-3
addr: 192.168.70.93
labels:
  - mon
  - osd
  - mgr
  - mds
---
# 2. HIGH AVAILABILITY CORE SERVICES PLACEMENT
service_type: mon
placement:
  label: mon # Automatically spins up exactly 3 MONs across nodes with this label
---
service_type: mgr
placement:
  label: mgr # Automatically spins up 2 MGRs for active/passive HA
---
# 3. DECLARATIVE OSD MANAGEMENT (Auto-provisions your 3x10GB disks per node)
service_type: osd
service_id: lab_osd_policy
placement:
  label: osd
spec:
  data_devices:
    size: '9GB:11GB' # Dynamically targets any unused disk within this range (10GB)
---
# 4. CEPH FILESYSTEM METADATA DAEMONS (For your Cluster FS client)
service_type: mds
service_id: lab_fs
placement:
  label: mds # Highly Available active/passive metadata servers
```
</details>

### 5. Проверка статуса кластера

После операций развертывания кластера Ceph проверяем его статус:

```bash
deploy@lab14-ceph-1:/tmp$ sudo cephadm shell ceph status
Inferring fsid 5e937263-77c4-11f1-a207-bc2411b0df56
Inferring config /var/lib/ceph/5e937263-77c4-11f1-a207-bc2411b0df56/mon.lab14-ceph-1/config
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 7m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-1.xsllty(active, since 30m), standbys: lab14-ceph-2.bcsnpv, lab14-ceph-3.zrtdyq
    osd: 9 osds: 9 up (since 2m), 9 in (since 5m)
 
  data:
    pools:   1 pools, 1 pgs
    objects: 2 objects, 449 KiB
    usage:   241 MiB used, 90 GiB / 90 GiB avail
    pgs:     1 active+clean

```

Также проверяем доступность и статус UI:

![](/Lab14_Ceph/pics/Ceph_osd_running_cluster.png)

Видим, что кластер Ceph поднялся и находится в статусе **"HEALTH_OK"**, OSD в кол-ве 9 шт доступны - общий объем хранилища 90 Gb. 

### 2. Создание RBD и CephFS.

Сейчас в кластере 9 OSD по 10 Gb каждый. Всего общий объем - 90Gb. Используем стандартный фактор репликации - 3. Соответственно, реальный доступный объем составляет 30 Gb ( общий объем / фактор репликации).


  ####  2.1 Создаем CephFS

  По условию, на ClusterFS выделяется 30% от общего объема, т.е 9Gb в нашем случае. 

  ```bash
  deploy@lab14-ceph-1:/tmp$ sudo cephadm shell
  ```     
  Создаем  CephFS volume (автоматически создаются пулы для данных и метадаты)
  ```bash
  root@lab14-ceph-1:/# ceph fs volume create lab_fs

  ```
  * Создаем subvolumegroup и ограничиваем ее объем в 9Gb:

  ```bash
  root@lab14-ceph-1:/# ceph fs subvolumegroup create lab_fs group1

  root@lab14-ceph-1:/# ceph fs subvolumegroup resize lab_fs group1 9663676416
   [
    {
        "bytes_used": 0
    },
    {
        "bytes_quota": 9663676416
    },
    {
        "bytes_pcent": "0.00"
    }
]

```

```bash
root@lab14-ceph-1:/# ceph fs subvolumegroup info lab_fs group1
{
    "atime": "2026-07-04 18:02:57",
    "bytes_pcent": "0.00",
    "bytes_quota": 9663676416,
    "bytes_used": 0,
    "casesensitive": true,
    "created_at": "2026-07-04 18:02:57",
    "ctime": "2026-07-04 18:05:30",
    "data_pool": "cephfs.lab_fs.data",
    "gid": 0,
    "mode": 16877,
    "mon_addrs": [
        "192.168.70.91:6789",
        "192.168.70.92:6789",
        "192.168.70.93:6789"
    ],
    "mtime": "2026-07-04 18:02:57",
    "normalization": "none",
    "uid": 0
}

  ```

  #### 2.2 Создаем RDB пул

 Создадим пул RDB с 32-ю PG (Placement Groups) и 32-ю PGP (Placement Groups for Placement). 

 В целом, в современных версиях Ceph ручное задание кол-ва Placement Groups не желательно, т.к. система поддерживает автоматическую аллокацию и ручное задание может ухудшить производительность. В данном случае для небольшого пула используем ручное задание в PG - 32. Значение, оптимальное с точки зрения "гранулирования" данных и затрат CPU/RAM на поддержку.

  ```bash
  root@lab14-ceph-1:/# ceph osd pool create rbd_pool 32 32
pool 'rbd_pool' created
```
После создания пула делаем его инциализацию и создаем три блочных устройства по 5GB каждый
```bash
root@lab14-ceph-1:/# rbd pool init rbd_pool
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-1 --size 5G
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-2 --size 5G
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-3 --size 5G
```
![](/Lab14_Ceph/pics/Ceph_block_images.png)


### 3. Подключение клиентских машин 

#### 3.1 Подключение CephFS

Для подключения CephFS на клиентской машине делаем запрос на путь к созданной выше FS:
```bash
root@lab14-ceph-1:/# ceph fs subvolumegroup getpath lab_fs group1
/volumes/group1
```
Запрашиваем fsid:
```bash
root@lab14-ceph-1:/# ceph fsid
5e937263-77c4-11f1-a207-bc2411b0df56
```

Далее на клиентской машине делаем монтирование CephFS с использованием ядра Linux (без установки доп. клиентов Ceph) к каталогу  /mnt/cephfs:

```bash
sudo mount -t ceph admin@5e937263-77c4-11f1-a207-bc2411b0df56.lab_fs=/volumes/group1 \
  -o mon_addr=192.168.70.91:6789/192.168.70.92:6789/192.168.70.93:6789,secret=AQ****************\
  /mnt/cephfs
```

Проверяем в UI, что появилось подключение к CephFS:

![](/Lab14_Ceph/pics/Ceph_filesystem_connected.png)

### 3.2 Проброс RBD тома 

Для проброса RBD тома необходимо установить соответствующие компоненты на клиент (crony, ceph-client), а также выполнить перенос некоторых конфигурацонных файлов. Для автоматизации данного процесса воспользуемся плейбуком **cephadm-clients.yml**, который выполнит данные действия:

```bash
maksim@maksim-asus-tuf:~/ceph/cephadm-ansible$ ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-clients.yml -e fsid=5e937263-77c4-11f1-a207-bc2411b0df56  -e client_group=clients -e keyring=/etc/ceph/ceph.client.admin.keyring --limit "admin,lab14-client-2"
```
После установки запускаем команду ceph -s на клиенте и убеждаемся, что кластер и его статус доступен: 

```bash
deploy@lab14-client-1:~$ sudo ceph -s --keyring /etc/ceph/ceph.keyring
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 2h) [leader: lab14-ceph-1]
    mgr: lab14-ceph-1.xsllty(active, since 3h), standbys: lab14-ceph-2.bcsnpv, lab14-ceph-3.zrtdyq
    mds: 1/1 daemons up, 2 standby
    osd: 9 osds: 9 up (since 2h), 9 in (since 2h)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.41k objects, 537 MiB
    usage:   2.2 GiB used, 88 GiB / 90 GiB avail
    pgs:     305 active+clean
 
  io:
    client:   170 B/s rd, 0 op/s rd, 0 op/s wr
```

 Длаее делаемM маппинг RBD раздела:
```bash
deploy@lab14-client-1:~$ sudo rbd device map rbd_pool/rbd-1
/dev/rbd0
```
Диск появился как /dev/rbd0 с ожидаемым объемом в 5Gb: 

```bash
deploy@lab14-client-1:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1    4M  0 rom  
rbd0                      251:0    0    5G  0 disk 
vda                       253:0    0   12G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0  1.8G  0 part /boot
└─vda3                    253:3    0 10.2G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   10G  0 lvm  /
```

Далее делаем монитрование как с обычным диском: 

```bash
deploy@lab14-client-1:~$ sudo mkdir /mnt/rbd-1
deploy@lab14-client-1:~$ sudo mount /dev/rbd0 /mnt/rbd-1

deploy@lab14-client-1:~$ ls /mnt/rbd-1
lost+found
```

Выполним тест, записав файл, размеров в 2Gb в раздел:

```bash
deploy@lab14-client-1:/mnt/rbd-1$ sudo dd if=/dev/zero of=file.in bs=1M count=2048
2048+0 records in
2048+0 records out
2147483648 bytes (2.1 GB, 2.0 GiB) copied, 57.4815 s, 37.4 MB/s
```

Проверим статус в UI:

![](/Lab14_Ceph/pics/Ceph_rbd1_usage.png)

Видим, что файл записался, а также отобразилось состояние о занятости диска. 

