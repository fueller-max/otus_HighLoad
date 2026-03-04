



```bash
maksim@maksim-asus-tuf:~$ wrk2 -t5 -c15 -d30s -R120 http://lab04.dev.net/
Running 30s test @ http://lab04.dev.net/
  5 threads and 15 connections
  Thread calibration: mean lat.: 896.612ms, rate sampling interval: 2531ms
  Thread calibration: mean lat.: 725.807ms, rate sampling interval: 2682ms
  Thread calibration: mean lat.: 404.053ms, rate sampling interval: 1346ms
  Thread calibration: mean lat.: 621.231ms, rate sampling interval: 1640ms
  Thread calibration: mean lat.: 545.777ms, rate sampling interval: 1549ms
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.36s   636.37ms   3.07s    65.07%
    Req/Sec    22.23      1.20    25.00     88.46%
  3384 requests in 30.02s, 212.24MB read
Requests/sec:    112.74
Transfer/sec:      7.07MB
```

```bash
maksim@maksim-asus-tuf:~$ wrk2 -t5 -c5 -d3s -R200 http://lab04.dev.net/
Running 3s test @ http://lab04.dev.net/
  5 threads and 5 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   163.35ms  210.14ms 863.23ms   80.15%
    Req/Sec       -nan      -nan   0.00      0.00%
  539 requests in 3.02s, 33.77MB read
Requests/sec:    178.26
Transfer/sec:     11.17MB
```



```bash
deploy@lab04-load-balancer-1:~$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:da:f5:20 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.70.41/24 brd 192.168.70.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.70.12/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::be24:11ff:feda:f520/64 scope link 

```


```bash
deploy@lab04-load-balancer-1:~$ sudo systemctl stop angie

deploy@lab04-load-balancer-1:~$ sudo systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-03-04 14:11:11 UTC; 57s ago
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 1522 (keepalived)
      Tasks: 2 (limit: 2315)
     Memory: 1.8M (peak: 3.7M)
        CPU: 70ms
     CGroup: /system.slice/keepalived.service
             ├─1522 /usr/sbin/keepalived --dont-fork
             └─1525 /usr/sbin/keepalived --dont-fork

Mar 04 14:11:11 lab04-load-balancer-1 Keepalived_vrrp[1525]: VRRP_Script(angie_check) succeeded
Mar 04 14:11:11 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering BACKUP STATE
Mar 04 14:11:12 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:11:13 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:11:14 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:11:15 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:11:15 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering MASTER STATE
Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: Script `angie_check` now returning 7
Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: VRRP_Script(angie_check) failed (exited with status 7)
Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering FAULT STATE

```


```bash
deploy@lab04-load-balancer-2:~$ sudo systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-03-04 11:56:58 UTC; 2h 15min ago
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 661 (keepalived)
      Tasks: 2 (limit: 2315)
     Memory: 5.0M (peak: 5.3M)
        CPU: 303ms
     CGroup: /system.slice/keepalived.service
             ├─661 /usr/sbin/keepalived --dont-fork
             └─675 /usr/sbin/keepalived --dont-fork

Mar 04 11:56:58 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering BACKUP STATE (init)
Mar 04 11:56:58 lab04-load-balancer-2 Keepalived[661]: Startup complete
Mar 04 11:56:58 lab04-load-balancer-2 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Mar 04 13:56:47 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering MASTER STATE
Mar 04 13:56:51 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Master received advert from 10.10.10.41 with higher priority 100, ours 99
Mar 04 13:56:51 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering BACKUP STATE
Mar 04 14:02:48 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering MASTER STATE
Mar 04 14:11:15 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Master received advert from 10.10.10.41 with higher priority 100, ours 99
Mar 04 14:11:15 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering BACKUP STATE
Mar 04 14:12:02 lab04-load-balancer-2 Keepalived_vrrp[675]: (angie) Entering MASTER STATE

```

```bash
deploy@lab04-load-balancer-2:~$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:e3:37:a0 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.70.42/24 brd 192.168.70.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.70.12/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::be24:11ff:fee3:37a0/64 scope link 
       valid_lft forever preferred_lft forever

```



```bash
deploy@lab04-load-balancer-1:~$ sudo systemctl start angie

deploy@lab04-load-balancer-1:~$ sudo systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-03-04 14:11:11 UTC; 4min 53s ago
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 1522 (keepalived)
      Tasks: 2 (limit: 2315)
     Memory: 1.8M (peak: 3.9M)
        CPU: 324ms
     CGroup: /system.slice/keepalived.service
             ├─1522 /usr/sbin/keepalived --dont-fork
             └─1525 /usr/sbin/keepalived --dont-fork

Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: Script `angie_check` now returning 7
Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: VRRP_Script(angie_check) failed (exited with status 7)
Mar 04 14:12:01 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering FAULT STATE
Mar 04 14:15:56 lab04-load-balancer-1 Keepalived_vrrp[1525]: Script `angie_check` now returning 0
Mar 04 14:15:56 lab04-load-balancer-1 Keepalived_vrrp[1525]: VRRP_Script(angie_check) succeeded
Mar 04 14:15:56 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering BACKUP STATE
Mar 04 14:15:57 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:15:58 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:15:59 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) received lower priority (99) advert from 10.10.10.42 - discarding
Mar 04 14:16:00 lab04-load-balancer-1 Keepalived_vrrp[1525]: (angie) Entering MASTER STATE

```

```bash
deploy@lab04-load-balancer-1:~$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether bc:24:11:da:f5:20 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.70.41/24 brd 192.168.70.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.70.12/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::be24:11ff:feda:f520/64 scope link 
       valid_lft forever preferred_lft forever

```