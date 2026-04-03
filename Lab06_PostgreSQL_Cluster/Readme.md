# Кластер PostgreSQL с Patroni

## Цель

Развернуть отказоустойчивый кластер PostgreSQL;
Обеспечить автоматическое управление лидерством и высокую доступность с помощью Patroni;
Настроить сервис-дискавери через etcd/Consul/ZooKeeper и балансировку с HAProxy или PgBouncer;

## Задание

1. Разверните кластер PostgreSQL, используя Patroni.
2. Настройте один из инструментов сервис-дискавери: etcd, Consul или ZooKeeper
3. Добавьте балансировщик:
   * HAProxy или PgBouncer
   * обеспечьте маршрутизацию к активному узлу кластера.
4. Перенесите базу данных веб-портала из предыдущего домашнего задания в кластер PostgreSQL.
5. Проверьте отказоустойчивость — при выключении ведущего узла должен автоматически назначаться новый.

## Решение

#etcd cluster:

```bash
deploy@lab06-pg-node2:~$ etcdctl endpoint health --cluster
http://10.10.70.72:2379 is healthy: successfully committed proposal: took = 1.631279ms
http://10.10.70.73:2379 is healthy: successfully committed proposal: took = 1.908909ms
http://10.10.70.74:2379 is healthy: successfully committed proposal: took = 2.097764ms

```

```bash
deploy@lab06-pg-node2:~$ etcdctl member list
70f0c6f79d03049d, started, lab06-pg-node3, http://10.10.70.74:2380, http://10.10.70.74:2379, false
8cd541aa2731c522, started, lab06-pg-node1, http://10.10.70.72:2380, http://10.10.70.72:2379, false
e070309dc3b2d3e7, started, lab06-pg-node2, http://10.10.70.73:2380, http://10.10.70.73:2379, false

```


```bash
deploy@lab06-pg-node1:~$ etcdctl --endpoints=http://10.10.70.72:2379 get "" --prefix --keys-only
/postgresql-common/patroni_cluster/config

/postgresql-common/patroni_cluster/history

/postgresql-common/patroni_cluster/initialize

/postgresql-common/patroni_cluster/leader

/postgresql-common/patroni_cluster/members/lab06-pg-node1

/postgresql-common/patroni_cluster/members/lab06-pg-node2

/postgresql-common/patroni_cluster/members/lab06-pg-node3

/postgresql-common/patroni_cluster/status

/postgresql-common/patroni_cluster/sync

```

```bash
deploy@lab06-pg-node1:~$ sudo systemctl status patroni
● patroni.service - Patroni high-availability PostgreSQL
     Loaded: loaded (/etc/systemd/system/patroni.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-04-02 11:08:50 UTC; 3min 53s ago
   Main PID: 1284 (patroni)
      Tasks: 17 (limit: 2315)
     Memory: 117.4M (peak: 117.9M)
        CPU: 845ms
     CGroup: /system.slice/patroni.service
             ├─1284 /usr/bin/python3 /usr/bin/patroni /etc/patroni/config.yml.in
             ├─1301 /usr/lib/postgresql/18/bin/postgres -D /var/lib/postgresql/18 --config-file=/var/lib/postgresql/18/postgresql.conf "--listen_addresses=*" --port=5432 --cluster_>
             ├─1303 "postgres: patroni_cluster: logger "
             ├─1304 "postgres: patroni_cluster: io worker 0"
             ├─1305 "postgres: patroni_cluster: io worker 1"
             ├─1306 "postgres: patroni_cluster: io worker 2"
             ├─1307 "postgres: patroni_cluster: checkpointer "
             ├─1308 "postgres: patroni_cluster: background writer "
             ├─1309 "postgres: patroni_cluster: startup recovering 000000020000000000000006"
             ├─1310 "postgres: patroni_cluster: walreceiver streaming 0/6000060"
             └─1316 "postgres: patroni_cluster: postgres postgres [local] idle"

Apr 02 11:11:04 lab06-pg-node1 patroni[1284]: 2026-04-02 11:11:04,953 INFO: no action. I am (lab06-pg-node1), a secondary, and following a leader (lab06-pg-node2)

```

```bash
deploy@lab06-pg-node2:~$ sudo systemctl status patroni
● patroni.service - Patroni high-availability PostgreSQL
     Loaded: loaded (/etc/systemd/system/patroni.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-04-02 10:55:52 UTC; 17min ago
   Main PID: 49532 (patroni)
      Tasks: 20 (limit: 2315)
     Memory: 113.0M (peak: 115.2M)
        CPU: 1.272s
     CGroup: /system.slice/patroni.service
             ├─49532 /usr/bin/python3 /usr/bin/patroni /etc/patroni/config.yml.in
             ├─49546 /usr/lib/postgresql/18/bin/postgres -D /var/lib/postgresql/18 --config-file=/var/lib/postgresql/18/postgresql.conf "--listen_addresses=*" --port=5432 --cluster>
             ├─49548 "postgres: patroni_cluster: logger "
             ├─49549 "postgres: patroni_cluster: io worker 0"
             ├─49550 "postgres: patroni_cluster: io worker 1"
             ├─49551 "postgres: patroni_cluster: io worker 2"
             ├─49552 "postgres: patroni_cluster: checkpointer "
             ├─49553 "postgres: patroni_cluster: background writer "
             ├─49560 "postgres: patroni_cluster: postgres postgres [local] idle"
             ├─49677 "postgres: patroni_cluster: walsender replicator 10.10.70.74(51622) streaming 0/6000060"
             ├─49686 "postgres: patroni_cluster: walwriter "
             ├─49687 "postgres: patroni_cluster: autovacuum launcher "
             ├─49688 "postgres: patroni_cluster: logical replication launcher "
             └─49718 "postgres: patroni_cluster: walsender replicator 10.10.70.72(38530) streaming 0/6000060"

Apr 02 11:11:54 lab06-pg-node2 patroni[49532]: 2026-04-02 11:11:54,330 INFO: no action. I am (lab06-pg-node2), the leader with the lock

```

```bash
deploy@lab06-pg-node2:~$ sudo patronictl -c /etc/patroni/config.yml.in list
+ Cluster: patroni_cluster (7624113203280740141) ---------+----+-------------+-----+------------+-----+
| Member         | Host        | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Replica      | streaming |  2 |   0/6478FB8 |   0 |  0/6478FB8 |   0 |
| lab06-pg-node2 | 10.10.70.73 | Leader       | running   |  2 |             |     |            |     |
| lab06-pg-node3 | 10.10.70.74 | Sync Standby | streaming |  2 |   0/6478FB8 |   0 |  0/6478FB8 |   0 |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+

```


switchover

```bash
deploy@lab06-pg-node2:~$ sudo patronictl -c /etc/patroni/config.yml.in switchover
Current cluster topology
+ Cluster: patroni_cluster (7624113203280740141) ---------+----+-------------+-----+------------+-----+
| Member         | Host        | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Replica      | streaming |  2 |   0/6478FB8 |   0 |  0/6478FB8 |   0 |
| lab06-pg-node2 | 10.10.70.73 | Leader       | running   |  2 |             |     |            |     |
| lab06-pg-node3 | 10.10.70.74 | Sync Standby | streaming |  2 |   0/6478FB8 |   0 |  0/6478FB8 |   0 |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
Primary [lab06-pg-node2]: 
Candidate ['lab06-pg-node1', 'lab06-pg-node3'] []: lab06-pg-node3
When should the switchover take place (e.g. 2026-04-03T07:04 )  [now]: now
Are you sure you want to switchover cluster patroni_cluster, demoting current leader lab06-pg-node2? [y/N]: y
2026-04-03 06:04:19.56026 Successfully switched over to "lab06-pg-node3"
+ Cluster: patroni_cluster (7624113203280740141) --+----+-------------+-----+------------+-----+
| Member         | Host        | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+---------+---------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Replica | running |  2 |   0/6479138 |   0 |  0/6479138 |   0 |
| lab06-pg-node2 | 10.10.70.73 | Replica | stopped |    |     unknown |     |    unknown |     |
| lab06-pg-node3 | 10.10.70.74 | Leader  | running |  2 |             |     |            |     |
+----------------+-------------+---------+---------+----+-------------+-----+------------+-----+

```

```bash
deploy@lab06-pg-node2:~$ sudo patronictl -c /etc/patroni/config.yml.in list
+ Cluster: patroni_cluster (7624113203280740141) ---------+----+-------------+-----+------------+-----+
| Member         | Host        | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Sync Standby | streaming |  3 |   0/64793D0 |   0 |  0/64793D0 |   0 |
| lab06-pg-node2 | 10.10.70.73 | Replica      | streaming |  3 |   0/64793D0 |   0 |  0/64793D0 |   0 |
| lab06-pg-node3 | 10.10.70.74 | Leader       | running   |  3 |             |     |            |     |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+

```


```bash
deploy@lab06-pg-node3:~$ sudo systemctl stop patroni

deploy@lab06-pg-node2:~$ sudo patronictl -c /etc/patroni/config.yml.in list
+ Cluster: patroni_cluster (7624113203280740141) ----+----+-------------+-----+------------+-----+
| Member         | Host        | Role    | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+---------+-----------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Leader  | running   |  3 |             |     |            |     |
| lab06-pg-node2 | 10.10.70.73 | Replica | streaming |  4 |   0/647FAB0 |   0 |  0/647FAB0 |   0 |
| lab06-pg-node3 | 10.10.70.74 | Replica | stopped   |    |     unknown |     |    unknown |     |
+----------------+-------------+---------+-----------+----+-------------+-----+------------+-----+
```

```bash
eploy@lab06-ha-node1:~$ sudo systemctl status haproxy
● haproxy.service - HAProxy Load Balancer
     Loaded: loaded (/usr/lib/systemd/system/haproxy.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-04-02 13:38:37 UTC; 16h ago
       Docs: man:haproxy(1)
             file:/usr/share/doc/haproxy/configuration.txt.gz
   Main PID: 25595 (haproxy)
     Status: "Ready."
      Tasks: 3 (limit: 2315)
     Memory: 7.5M (peak: 8.0M)
        CPU: 16.338s
     CGroup: /system.slice/haproxy.service
             ├─25595 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock
             └─25597 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock

Apr 02 13:38:38 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server primary/node3 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable">
Apr 02 13:38:39 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server standbys/node2 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable>
Apr 03 06:04:24 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server primary/node3 is UP, reason: Layer7 check passed, code: 200, check duration: 0ms. 2 active>
Apr 03 06:04:24 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server primary/node2 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable">
Apr 03 06:04:27 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server standbys/node3 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable>
Apr 03 06:04:27 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server standbys/node2 is UP, reason: Layer7 check passed, code: 200, check duration: 7ms. 2 activ>
Apr 03 06:11:55 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server primary/node1 is UP, reason: Layer7 check passed, code: 200, check duration: 1ms. 2 active>
Apr 03 06:11:58 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server primary/node3 is DOWN, reason: Layer4 connection problem, info: "Connection refused", chec>
Apr 03 06:11:58 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server standbys/node1 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable>
Apr 03 06:15:13 lab06-ha-node1 haproxy[25597]: [WARNING]  (25597) : Server standbys/node3 is UP, reason: Layer7 check passed, code: 200, check duration: 13ms. 2 acti>
```



Haproxy

```bash
deploy@lab06-ha-node1:~$ sudo systemctl stop haproxy

deploy@lab06-ha-node1:~$ sudo systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-04-03 06:38:37 UTC; 36s ago


Apr 03 06:38:37 lab06-ha-node1 Keepalived[36972]: Starting VRRP child process, pid=36973
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: (/etc/keepalived/keepalived.conf: Line 6) Unterminated quote 'script "killall -0 haproxy""'
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: (/etc/keepalived/keepalived.conf: Line 6) Unmatched quote: 'script "killall -0 haproxy""'
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: WARNING - script `killall` resolved by path search to `/usr/bin/killall`. Please specify full path.
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: (ha_proxy) Entering BACKUP STATE (init)
Apr 03 06:38:37 lab06-ha-node1 Keepalived[36972]: Startup complete
Apr 03 06:38:37 lab06-ha-node1 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: VRRP_Script(chk_haproxy) succeeded
Apr 03 06:38:37 lab06-ha-node1 Keepalived_vrrp[36973]: (ha_proxy) Changing effective priority from 100 to 102
Apr 03 06:38:41 lab06-ha-node1 Keepalived_vrrp[36973]: (ha_proxy) Entering MASTER STATE

deploy@lab06-ha-node2:~$ ip a

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:2f:c9:94 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.70.71/24 brd 192.168.70.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.70.20/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::be24:11ff:fe2f:c994/64 scope link 
       valid_lft forever preferred_lft forever
```

