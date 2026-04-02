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

deploy@lab06-pg-node2:~$ etcdctl endpoint status -w table
+----------------+------------------+---------+-----------------+---------+--------+-----------------------+--------+-----------+------------+-----------+------------+--------------------+--------+--------------------------+-------------------+
|    ENDPOINT    |        ID        | VERSION | STORAGE VERSION | DB SIZE | IN USE | PERCENTAGE NOT IN USE | QUOTA  | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS | DOWNGRADE TARGET VERSION | DOWNGRADE ENABLED |
+----------------+------------------+---------+-----------------+---------+--------+-----------------------+--------+-----------+------------+-----------+------------+--------------------+--------+--------------------------+-------------------+
| 127.0.0.1:2379 | e070309dc3b2d3e7 |   3.6.9 |           3.6.0 |   20 kB |  16 kB |                   20% | 2.1 GB |     false |      false |         2 |         11 |                 11 |        |                          |             false |
+----------------+------------------+---------+-----------------+---------+--------+-----------------------+--------+-----------+------------+-----------+------------+--------------------+--------+--------------------------+-------------------+

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