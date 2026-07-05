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

### 3. Сценарии сбойных ситуаций

Split brain 

First OK:

```bash
deploy@lab14-ceph-1:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 5m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 35m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 9 osds: 9 up (since 8h), 9 in (since 22h)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 82 GiB / 90 GiB avail
    pgs:     305 active+clean

```


```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_WARN
            failed to probe daemons or devices
            1/3 mons down, quorum lab14-ceph-2,lab14-ceph-3
            3 osds down
            1 host (3 osds) down
            Degraded data redundancy: 4927/14781 objects degraded (33.333%), 302 pgs degraded
 
  services:
    mon: 3 daemons, quorum lab14-ceph-2,lab14-ceph-3 (age 70s) [leader: lab14-ceph-2], out of quorum: lab14-ceph-1
    mgr: lab14-ceph-3.zrtdyq(active, since 50m), standbys: lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 1 standby
    osd: 9 osds: 6 up (since 35s), 9 in (since 23h)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 82 GiB / 90 GiB avail
    pgs:     4927/14781 objects degraded (33.333%)
             302 active+undersized+degraded
             3   active+undersized

```

Файлы доступны:

```bash
deploy@lab14-client-1:~$ ls /mnt/cephfs
README            apt       bootstrap.log  cloud-init-output.log  dist-upgrade  dmesg.1.gz  fontconfig.log  kern.log   lib    log   private  spool    tmp
alternatives.log  auth.log  btmp           cloud-init.log         dmesg         dpkg.log    installer       landscape  local  mail  run      syslog   unattended-upgrades
apport.log        backups   cache          crash                  dmesg.0       faillog     journal         lastlog    lock   opt   snap     sysstat  wtmp

```


```bash
deploy@lab14-ceph-1:~$ sudo iptables -F INPUT
deploy@lab14-ceph-1:~$ sudo iptables -F OUTPUT

```

```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_WARN
            1 hosts fail cephadm check
            Degraded data redundancy: 41/14790 objects degraded (0.277%), 2 pgs degraded
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 23s) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 68m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 9 osds: 9 up (since 43s), 9 in (since 43s); 1 remapped pgs
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 82 GiB / 90 GiB avail
    pgs:     41/14790 objects degraded (0.277%)
             11/14790 objects misplaced (0.074%)
             302 active+clean
             1   active+recovering
             1   active+recovery_wait+degraded
             1   active+recovery_wait+undersized+degraded+remapped

```

```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 66s) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 69m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 9 osds: 9 up (since 86s), 9 in (since 86s)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 82 GiB / 90 GiB avail
    pgs:     305 active+clean

```


#### 2. Исключение одиного диска (симуляция сбоя HDD/SSD)

 В качестве теста принудительно остановим один демон osd на третей ноде, эмулируя выход из строя диск

 ```bash
 deploy@lab14-ceph-3:~$ sudo systemctl list-units | grep osd
  ceph-5e937263-77c4-11f1-a207-bc2411b0df56@osd.6.service                                                          loaded active running   Ceph osd.6 for 5e937263-77c4-11f1-a207-bc2411b0df56
  ceph-5e937263-77c4-11f1-a207-bc2411b0df56@osd.7.service                                                          loaded active running   Ceph osd.7 for 5e937263-77c4-11f1-a207-bc2411b0df56
  ceph-5e937263-77c4-11f1-a207-bc2411b0df56@osd.8.service                                                          loaded active running   Ceph osd.8 for 5e937263-77c4-11f1-a207-bc2411b0df56
deploy@lab14-ceph-3:~$ sudo systemctl stop ceph-5e937263-77c4-11f1-a207-bc2411b0df56@osd.6

 ``` 

 состояние кластера:

 What you will see: The cluster health will shift to HEALTH_WARN with 1 osds down.Unlike the host crash where everything broke, your OSD line will read 9 osds: 8 up, 9 in.Your data PGs will shift to active+degraded. Because your other two nodes (ceph-1 and ceph-2) are still fully online, the data placement rule is still 100% satisfied (you still have 2 healthy hosts), meaning the cluster will not say undersized this time.

 ```bash
 deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_WARN
            1 osds down
            Degraded data redundancy: 1707/14790 objects degraded (11.542%), 106 pgs degraded
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 7m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 75m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 9 osds: 8 up (since 35s), 9 in (since 8m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 82 GiB / 90 GiB avail
    pgs:     1707/14790 objects degraded (11.542%)
             199 active+clean
             106 active+undersized+degraded
 
  io:
    client:   170 B/s rd, 0 op/s rd, 0 op/s wr
 ```

готовим к извлечению диск:

```bash
deploy@lab14-ceph-3:~$ sudo ceph osd purge osd.6 --yes-i-really-mean-it
purged osd.6
```

```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_WARN
            Degraded data redundancy: 2658/14790 objects degraded (17.972%), 135 pgs degraded
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 10m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 78m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 8 osds: 8 up (since 3m), 8 in (since 10m); 3 remapped pgs
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   7.1 GiB used, 73 GiB / 80 GiB avail
    pgs:     2658/14790 objects degraded (17.972%)
             15/14790 objects misplaced (0.101%)
             170 active+clean
             130 active+recovery_wait+degraded
             3   active+recovery_wait+undersized+degraded+remapped
             2   active+recovering+degraded
 
  io:
    client:   170 B/s rd, 0 op/s rd, 0 op/s wr
    recovery: 3.1 MiB/s, 11 objects/s
 
```

```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 14m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 82m), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 8 osds: 8 up (since 7m), 8 in (since 14m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.0 GiB used, 72 GiB / 80 GiB avail
    pgs:     305 active+clean
 
  io:
    client:   170 B/s rd, 0 op/s rd, 0 op/s wr

```

возврат обратно:

```bash
deploy@lab14-ceph-3:~$ sudo cephadm ceph-volume lvm zap --destroy /dev/vdb
Inferring fsid 5e937263-77c4-11f1-a207-bc2411b0df56

deploy@lab14-ceph-3:~$ sudo dd if=/dev/zero of=/dev/vdb bs=1M count=100 status=progress
100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.0782928 s, 1.3 GB/s
deploy@lab14-ceph-3:~$ sudo ceph orch device ls lab14-ceph-3 --refresh
HOST          PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS                                                           
lab14-ceph-3  /dev/vdb  hdd              10.0G  Yes        5m ago                                                                              
lab14-ceph-3  /dev/vdc  hdd              10.0G  No         5m ago     Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-3  /dev/vdd  hdd              10.0G  No         5m ago     Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  

```

```bash
deploy@lab14-ceph-1:/tmp$ cd /tmp
sudo cephadm shell --mount cluster-spec.yaml:/etc/ceph/cluster-spec.yaml -- ceph orch apply -i /etc/ceph/cluster-spec.yaml
Inferring fsid 5e937263-77c4-11f1-a207-bc2411b0df56
Inferring config /var/lib/ceph/5e937263-77c4-11f1-a207-bc2411b0df56/mon.lab14-ceph-1/config
Added host 'lab14-ceph-1' with addr '192.168.70.91'
Added host 'lab14-ceph-2' with addr '192.168.70.92'
Added host 'lab14-ceph-3' with addr '192.168.70.93'
Scheduled mon update...
Scheduled mgr update...
Scheduled osd.lab_osd_policy update...
Scheduled mds.lab_fs update...
```

```bash
eploy@lab14-ceph-2:~$ sudo ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.08817  root default                                    
-5         0.02939      host lab14-ceph-1                           
 0    hdd  0.00980          osd.0              up   1.00000  1.00000
 2    hdd  0.00980          osd.2              up   1.00000  1.00000
 4    hdd  0.00980          osd.4              up   1.00000  1.00000
-3         0.02939      host lab14-ceph-2                           
 1    hdd  0.00980          osd.1              up   1.00000  1.00000
 3    hdd  0.00980          osd.3              up   1.00000  1.00000
 5    hdd  0.00980          osd.5              up   1.00000  1.00000
-7         0.02939      host lab14-ceph-3                           
 7    hdd  0.00980          osd.7              up   1.00000  1.00000
 8    hdd  0.00980          osd.8              up   1.00000  1.00000
 9    hdd  0.00980          osd.9              up   1.00000  1.00000
 6               0  osd.6                    down         0  1.00000

deploy@lab14-ceph-2:~$ sudo ceph osd rm osd.6
removed osd.6
deploy@lab14-ceph-2:~$ sudo ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.08817  root default                                    
-5         0.02939      host lab14-ceph-1                           
 0    hdd  0.00980          osd.0              up   1.00000  1.00000
 2    hdd  0.00980          osd.2              up   1.00000  1.00000
 4    hdd  0.00980          osd.4              up   1.00000  1.00000
-3         0.02939      host lab14-ceph-2                           
 1    hdd  0.00980          osd.1              up   1.00000  1.00000
 3    hdd  0.00980          osd.3              up   1.00000  1.00000
 5    hdd  0.00980          osd.5              up   1.00000  1.00000
-7         0.02939      host lab14-ceph-3                           
 7    hdd  0.00980          osd.7              up   1.00000  1.00000
 8    hdd  0.00980          osd.8              up   1.00000  1.00000
 9    hdd  0.00980          osd.9              up   1.00000  1.00000

```


How it works in a real production environmentIn a true hardware replacement scenario, you do not use the purge command. Instead, you let the automated orchestrator handle the workflow:
The Drive Dies: The physical disk breaks. Ceph marks it down and out.
You Swap the Drive: You physically pull the dead drive out of the server slot and slide in a brand-new, completely blank disk.
Automatic Discovery: Every 10 minutes, the cephadm daemon on that host automatically runs a background hardware inventory scan.
Automatic Provisioning: The orchestrator sees a brand new, empty disk that matches your cluster-spec.yaml size criteria (9GB:11GB). 
It automatically zaps it, creates the LVM logical volumes, provisions the new OSD, and hooks it back into the cluster—without you typing a single command


### Добавим 3 диска

This is an excellent scenario to test. Because you used a declarative cluster-spec.yaml at the beginning, adding capacity to your cluster is incredibly simple and showcases the true power of Ceph's automation.Since your current OSD specification file dictates that Ceph should automatically grab any unused disk between 9GB:11GB, you do not need to create any new configurations or apply new service files. Cephadm will discover the new hardware and scale the cluster on its own

```bash
deploy@lab14-ceph-3:~$ sudo ceph orch device ls --refresh
HOST          PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS                                                           
lab14-ceph-1  /dev/vdb  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-1  /dev/vdc  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-1  /dev/vdd  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-1  /dev/vde  hdd              10.0G  Yes        18s ago                                                                             
lab14-ceph-2  /dev/vdb  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-2  /dev/vdc  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-2  /dev/vdd  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-2  /dev/vde  hdd              10.0G  Yes        18s ago                                                                             
lab14-ceph-3  /dev/vdb  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-3  /dev/vdc  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-3  /dev/vdd  hdd              10.0G  No         18s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
lab14-ceph-3  /dev/vde  hdd              10.0G  Yes        18s ago  
```


```bash
deploy@lab14-ceph-2:~$ sudo ceph -s
  cluster:
    id:     5e937263-77c4-11f1-a207-bc2411b0df56
    health: HEALTH_WARN
            2 OSD(s) experiencing slow operations in BlueStore
 
  services:
    mon: 3 daemons, quorum lab14-ceph-1,lab14-ceph-2,lab14-ceph-3 (age 8m) [leader: lab14-ceph-1]
    mgr: lab14-ceph-3.zrtdyq(active, since 3h), standbys: lab14-ceph-1.xsllty, lab14-ceph-2.bcsnpv
    mds: 1/1 daemons up, 2 standby
    osd: 12 osds: 12 up (since 8m), 12 in (since 11m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 305 pgs
    objects: 4.93k objects, 2.5 GiB
    usage:   8.3 GiB used, 112 GiB / 120 GiB avail
    pgs:     305 active+clean
 
  io:
    client:   170 B/s rd, 0 op/s rd, 0 op/s wr

```