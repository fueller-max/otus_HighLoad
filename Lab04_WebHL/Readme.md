# Настройка конфигурации веб приложения под высокую нагрузку

## Цель

Научиться развертыванию серверов веб-приложения, способного выдерживать высокие нагрузки и обеспечивать отказоустойчивость, используя Terraform и Ansible

## Задание

1. Создать несколько инстансов с помощью терраформ (2 nginx, 2 backend, 1 db).
2. Развернуть Nginx и Keepalived на серверах nginx при помощи Ansible.
3. Развернуть бэкенд способный работать по Uwsgi/Unicorn/PHP-FPM и базой данных при помощи Ansible. Можно взять готовую CMS или проект на Django.
4. Развернуть GFS2 для бэкенд серверах, для хранения статики.
5. Развернуть СУБД для работы бэкенда при помощи Ansible.
6. Проверить отказоустойчивость системы при выходе из строя серверов backend или nginx.

## Решение


### Описание стенда 

Данную работу выполним в формате развития прошлого проекта, развернув стенд на базе СMS WordPress в количестве 8ми виртуальных машин. В составе:

* Балансировщик на базе Angie - 2 ВМ
* Бэкенд: WordPress + Nginx с использованием протокола fastcgi между ними- 3 ВМ
* База данных MySql - 1 ВМ
* Хранилище для общих файлов iSCSI - 1 ВМ
* Сервер мониторинга (Prometheus + Grafana) - 1ВМ

Для лучшего понимания графическая схема стенда представлена ниже:

![](/Lab04_WebHL/pics/Lab04_design.jpg)

Разворачивание машин осуществляется на локальном стенде Prоxomox с помощью Terraform, настройка машин с использованием Ansible. 

Главный Ansible-плейбук представлен ниже:

<details>
  <summary>main.yaml</summary>

```bash
  ## ---------Provision Distributed File Storage ----------------

- name: Manage iSCSI target node
  hosts: fileservers
  become: true
  roles:
       - role: iscsi-target

- name: Manage iSCSI initiator nodes 
  hosts: backends
  become: true
  gather_facts: true
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
            target: "{{ target_iqn }}"
            portal: "{{ target_portal }}"
            login: true
       
  roles:
        - role: ricsanfre.iscsi_initiator

- name: Manage DNS hosts for iSCSI clients (for Corosync and GFS2)
  hosts: backends
  become: true
  roles:
       - dns-hosts     

- name: Manage neccessary package infrastructure(GFS2, Corosync, DLM) for iSCSI initiators 
  hosts: backends
  become: true
  roles:
       - gfs2-infra 

##-----------------------------------------------------------------------------

##  ------Provision DataBase --------------------------------------------------

- name: Provision database machine
  hosts: databases
  become: true
  roles:
        - role: mysql-wordpress

##-----------------------------------------------------------------------------


## -----Provision Backends ----------------------------------------------------

- name: Provision backend machines
  hosts: backends
  become: true
  roles:
        - role: wordpress  

##-----------------------------------------------------------------------------

## -------Provision Load Balancers --------------------------------------------

- name: Provision loadbalancers machines
  hosts: loadbalancers
  become: true
  roles:
        - role: angie-lb-ha  

##-----------------------------------------------------------------------------


## ------------Provision Monitoring service ----------------------------------
- name: Provision Monitoring machine (Prometheus&Grafana)
  hosts: lab04_monitoring
  become: true
  roles:
          - monitoring

- name: Install Node Exporter on all hosts
  hosts: all
  become: true
  roles:
          - node-exporter
  tags: 
       - node-exp           
##----------------------------------------------------------------------------
```
</details>

### Настройка VRRP (keepalived) 

Основной особенностью является реализация отказоустойчивого балансировщика нагрузки на базе Angie. Отказоустойчивость обеспечивается за счет использования двух независимых узлов со своим инстансом Angie работающих с режиме Master/Backup. Переключение между узлами обеспечивается протоколом VRRP, реализующим механизм плавающего IP между нодами. При падении сервиса IP назначается Slave ноде, которая и будет воспринимать нагрузку. Реализация VRRP обеспечивается демоном keepalived.

Отметим, что обмен VRRP сообщениями обеспечивается на отдельных интерфейсах/подсети (10.10.10.0/24 в данном случае), а назначение VIP на другом (192.168.70.0/24).

Рассмотрим работу VRRP (keepalived):

* Нормальный режим - мониторный сервис в UP на первой ноде, VIP (192.168.70.12) назначен интерфейсу eth0.

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
* Режим аварии - мониторный сервис в DOWN на первой ноде. Демон keepalived определяет сбой сервиса (Script `angie_check` now returning 7) и переводит первую ноду в состояние SLAVE. VIP (192.168.70.12) имеет назначение интерфейсу eth0, но уже теперь на второй ноде. 2-ая нода имеет состояние MASTER.

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

* При возобновлении работы первой ноды происходит обратный процесс с переходом первой ноды в MASTER состояние и назначения ей VIP. Теперь трафик снова идет через первую ноду. Данное поведение обеспечивается настройкой nopreempt, которая возвращает управление изначально заданной MASTER ноде. 


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

Настройки демона keepalived включают в себя скрипт-чек сервиса Angie и  настройки самого VRRP:

<details>
  <summary>keepalived.conf.j2</summary>

  ```bash
  global_defs {
    enable_script_security
}

vrrp_script angie_check {
    script "/usr/bin/curl -s --connect-timeout 5 -A 'angie_hcheck_script' --no-buffer -XGET --unix-socket /tmp/angie_hcheck.sock http://hcheck/"
    interval 5
    user root
}

vrrp_instance angie {

  {% if inventory_hostname == "lab04-load-balancer-1" %}
    state MASTER
  {% elif inventory_hostname == "lab04-load-balancer-2" %}
    state SLAVE
  {% endif %}
    interface eth1   
    virtual_router_id 254 
  {% if inventory_hostname == "lab04-load-balancer-1" %}
    priority 100
  {% elif inventory_hostname == "lab04-load-balancer-2" %}
    priority 99
  {% endif %}    
    
    advert_int 1 
 
  {% if inventory_hostname == "lab04-load-balancer-1" %}
    unicast_src_ip {{ vrrp_master_ip }}
    unicast_peer {
        {{ vrrp_slave_ip }}
    }
  {% elif inventory_hostname == "lab04-load-balancer-2" %}
    unicast_src_ip {{ vrrp_slave_ip }}
    unicast_peer {
        {{ vrrp_master_ip }}
    }
  {% endif %}
    

    virtual_ipaddress {
        {{ vip }} dev eth0
    } track_script {
        angie_check
    }
}
  ```
</details>

### Настройки балансировщика Angie

Проведем тест производительности с использованием базовой конфигурации по протоколу http с использованием утилиты wrk2:

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
Кол-во обрабатываемых запросов составило 112 з/c.

Проведем некоторую оптимизацию настроек Angie под большую нагрузку. Основное - это использование кеширования запросов, оптимизация настроек SSL (для https) и не большой тюнинг TCP  сетеых параметров Angie.

<details>
  <summary>angie.conf</summary>
    sendfile       on;
    tcp_nopush     on;
    tcp_nodelay    on;

    keepalive_timeout  120;
    keepalive_requests 2000;
    proxy_cache_path /var/www/cache levels=1:2 keys_zone=one:10m:file=/etc/angie/cache.state inactive=4h max_size=800m;
</details>  


<details>
  <summary>default.conf</summary>
       location / {
        
        proxy_cache one;
        proxy_cache_valid 200 302  10m;
        proxy_cache_valid 404      1h;
        proxy_cache_lock on;
        proxy_cache_background_update on;
    }

    # Protocols & Ciphers (Modern standard)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off; # Recommended for TLS 1.3

    # Performance & Optimization
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # About 40000 sessions
    ssl_session_tickets off;
</details>  

С использованием данных настроек на том же тесте виден значительный прирост производительности до 178 з/c:

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

И, что очень важно, осуществлено кардинальное снижение нагрузки на бэкенды, т.к. сейчас все запросы к статике выдаются самим балансировщиком из кэша без обращения к бэкенду.

![](/Lab04_WebHL/pics/Angie_CacheBackendsLoad.png)

![](/Lab04_WebHL/pics/Angie_Cache.png)

Также проверям, что доступ по https работает:

![](/Lab04_WebHL/pics/Lab04_https.png)


После также добавим настройки ограничения трафика с одного IP для предотвращения DoS атак.

<details>
  <summary>angie.conf</summary>

  ```bash
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=50r/s; # Limit rate 50 request/s from one IP
```  
</details>  


<details>
  <summary>default.conf</summary>

  ```bash
      location / {
        
        limit_conn addr 5; # Not more than 5 connections from one IP
        limit_req zone=req_limit_per_ip burst=5 nodelay; 
  }
```  
</details>  

Проверим работу с включением ограничения запросов. Максимальное число запросов в сек 50. 

Видим, что при тесте 45 з/с все запросы обрабатываются. При скорости 80 з/с примерно 30% запросов отклонятся, а при 100 з/с примерно 50% отклоняются. 

```bash
maksim@maksim-asus-tuf:~$ wrk2 -t5 -c5 -d30s -R45 http://lab04.dev.net/
Running 30s test @ http://lab04.dev.net/
  5 threads and 5 connections
  Thread calibration: mean lat.: 27.565ms, rate sampling interval: 58ms
  Thread calibration: mean lat.: 26.895ms, rate sampling interval: 58ms
  Thread calibration: mean lat.: 28.720ms, rate sampling interval: 59ms
  Thread calibration: mean lat.: 23.297ms, rate sampling interval: 54ms
  Thread calibration: mean lat.: 17.427ms, rate sampling interval: 50ms
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    24.18ms    6.64ms  61.76ms   84.44%
    Req/Sec     8.86      8.88    20.00     89.96%
  1350 requests in 30.01s, 84.62MB read
Requests/sec:     44.99
Transfer/sec:      2.82MB

maksim@maksim-asus-tuf:~$ wrk2 -t5 -c5 -d30s -R80 http://lab04.dev.net/
Running 30s test @ http://lab04.dev.net/
  5 threads and 5 connections
  Thread calibration: mean lat.: 13.995ms, rate sampling interval: 37ms
  Thread calibration: mean lat.: 11.193ms, rate sampling interval: 31ms
  Thread calibration: mean lat.: 19.542ms, rate sampling interval: 37ms
  Thread calibration: mean lat.: 29.193ms, rate sampling interval: 71ms
  Thread calibration: mean lat.: 24.053ms, rate sampling interval: 46ms
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    17.12ms   17.33ms 224.38ms   97.88%
    Req/Sec    16.00     13.67   129.00     49.92%
  2400 requests in 30.01s, 94.74MB read
  Non-2xx or 3xx responses: 898
Requests/sec:     79.98
Transfer/sec:      3.16MB

maksim@maksim-asus-tuf:~$ wrk2 -t5 -c5 -d30s -R110 http://lab04.dev.net/
Running 30s test @ http://lab04.dev.net/
  5 threads and 5 connections
  Thread calibration: mean lat.: 10.672ms, rate sampling interval: 30ms
  Thread calibration: mean lat.: 12.850ms, rate sampling interval: 35ms
  Thread calibration: mean lat.: 12.532ms, rate sampling interval: 35ms
  Thread calibration: mean lat.: 12.986ms, rate sampling interval: 35ms
  Thread calibration: mean lat.: 12.133ms, rate sampling interval: 34ms
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    12.27ms    3.14ms  19.06ms   67.95%
    Req/Sec    21.98     13.01    34.00     74.37%
  3300 requests in 30.01s, 95.39MB read
  Non-2xx or 3xx responses: 1797
Requests/sec:    109.96
Transfer/sec:      3.18MB
```
Данный механзим защищает бэкенд инфраструктуру от аномальных нагрузок, часто вызыванных целенаправленными атаками. 

В рамках настройки инфрастурктры также был реализован мониторинг на базе стека Prometheus + Grafana: 

![](/Lab04_WebHL/pics/Grafana_angie.jpg)


Выводы:

В данной работе рассмотрен вопрос создания устойчивого веб-приложения, ориентированного на высокие нагрузки и устойчивость к базовой DoS атаке. Реализован отказоустойчивый балансировщик на базе Angie + keepalived. 

