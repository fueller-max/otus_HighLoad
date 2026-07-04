
### 1. Boostratp Кластера

1. Используем плейбук для первичной настройки нод кластера Ceph:

```bash
ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-preflight.yml --limit "nodes"
```

2. Делаем первичный Bootstrap с указанием сетей:

```bash
sudo cephadm bootstrap \
  --mon-ip 192.168.70.91 \
  --cluster-network 10.10.90.0/24 \
  --initial-dashboard-user admin \
  --initial-dashboard-password admin
```

3. Запускаем плейбук для раздачи ssh ключей по нодам кластера (нужно для бутстрапа оставшихся нод кластера)

```bash
ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-distribute-ssh-key.yml -e cephadm_ssh_user=deploy -e admin_node=lab14-ceph-1 --limit "nodes" 
```

4. Запускаем  Bootstrap кластера с передачей файла конфигурации cluster-spec.yaml:

```bash
deploy@lab14-ceph-1:/tmp$ sudo cephadm shell --mount cluster-spec.yaml:/etc/ceph/cluster-spec.yaml 
Inferring fsid 5e937263-77c4-11f1-a207-bc2411b0df56
Inferring config /var/lib/ceph/5e937263-77c4-11f1-a207-bc2411b0df56/mon.lab14-ceph-1/config
root@lab14-ceph-1:/# ceph orch apply -i /etc/ceph/cluster-spec.yaml
Added host 'lab14-ceph-1' with addr '192.168.70.91'
Added host 'lab14-ceph-2' with addr '192.168.70.92'
Added host 'lab14-ceph-3' with addr '192.168.70.93'
Scheduled mon update...
Scheduled mgr update...
Scheduled osd.lab_osd_policy update...
Scheduled mds.lab_fs update...


```

5. Проверка статуса

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

### 2. Создание RBD и CephFS.

Сейчас в кластере 9 OSD по 10 Gb каждый. Всего общий объем - 90Gb. Используем стандартный фактор репликации - 3. Соответственно, реальный доступный объем составляет 30 Gb.

По условию, на ClusterFS выделяется 30% от общего объема, т.е 9Gb в нашем случае. 

  2.1 Создаем CephFS

  ```bash
  deploy@lab14-ceph-1:/tmp$ sudo cephadm shell
  ```     
 * Create the CephFS volume (This automatically provisions the required data and metadata pools)
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

  2.2 Создаем RDB пул

  ```bash
  root@lab14-ceph-1:/# ceph osd pool create rbd_pool 32 32
pool 'rbd_pool' created
root@lab14-ceph-1:/# rbd pool init rbd_pool
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-1 --size 5G
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-2 --size 5G
root@lab14-ceph-1:/# rbd create rbd_pool/rbd-3 --size 5G
  ```



### 3. Подключение клиентских машин 

3.1 Подключение CephFS

* query the exact system path that Ceph generated for group1
```bash
root@lab14-ceph-1:/# ceph fs subvolumegroup getpath lab_fs group1
/volumes/group1

```
```bash
root@lab14-ceph-1:/# ceph fsid
5e937263-77c4-11f1-a207-bc2411b0df56
```

```bash
sudo mount -t ceph admin@5e937263-77c4-11f1-a207-bc2411b0df56.lab_fs=/volumes/group1 \
  -o mon_addr=192.168.70.91:6789/192.168.70.92:6789/192.168.70.93:6789,secret=AQ****************\
  /mnt/cephfs

```

3.2 Проброс RBD тома 


```bash
maksim@maksim-asus-tuf:~/ceph/cephadm-ansible$ ansible-playbook -i /home/maksim/otus/git_repo/otus_HighLoad/Lab14_Ceph/ansible/inventory.yaml cephadm-clients.yml -e fsid=5e937263-77c4-11f1-a207-bc2411b0df56  -e client_group=clients -e keyring=/etc/ceph/ceph.client.admin.keyring --limit "admin,lab14-client-2"
```

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

* Map the RBD Image
```bash
deploy@lab14-client-1:~$ sudo rbd device map rbd_pool/rbd-1
/dev/rbd0

```

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

* Mount
```bash
deploy@lab14-client-1:~$ sudo mkdir /mnt/rbd-1
deploy@lab14-client-1:~$ sudo mount /dev/rbd0 /mnt/rbd-1

deploy@lab14-client-1:~$ ls /mnt/rbd-1
lost+found
```


* Test

```bash
deploy@lab14-client-1:/mnt/rbd-1$ sudo dd if=/dev/zero of=file.in bs=1M count=2048
2048+0 records in
2048+0 records out
2147483648 bytes (2.1 GB, 2.0 GiB) copied, 57.4815 s, 37.4 MB/s
```

