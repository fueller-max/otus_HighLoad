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


Развернем кластер PostgreSQL из трех нод с использованием Patroni, а в качестве DCS(хранилише данных состояния кластерной системы) системы будем использовать etcd. В качестве proxy сервера будем использовать HAProxy, которые будут работать в связке с keepalived для повышения отказоустойчивости и доступности системы.

Общая схема стенда представлена на рисунке:
![pg_cluster](/Lab06_PostgreSQL_Cluster/pics/Postgesql_cluster.jpg)
Для развертывания используем Terraform с локальным стендом Proxmox. 

В данной системе выход из строя любой одной машины не приводит к отказу системы- работоспобность системы полностью сохраняется.

### 1. Разворачиваем кластер PostgreSQL с использованием Patroni

#### 1.1 Разворачивание etcd
Как было сказано в качестве DCS будем использовать кластер etcd, ноды которого развернем на машинах с postgresql

Плейбуки для установки и настройки представлены ниже:

<details>
  <summary>install.yaml</summary>
  
  ```bash
  - name: Get latest etcd release version
  ansible.builtin.uri:
    url: https://api.github.com/repos/etcd-io/etcd/releases/latest
    return_content: yes
    status_code: 200
  register: etcd_api_response
  when: etcd_version == "latest"
  failed_when: etcd_api_response.status != 200
  tags: always

- name: Parse latest etcd version from API response
  ansible.builtin.set_fact:
    etcd_release: "{{ (etcd_api_response.json.tag_name | regex_replace('^v', '')) }}"
  when:
    - etcd_version == "latest"
    - etcd_api_response is success  
  tags: always

- name: Debug etcd version
  ansible.builtin.debug:
    var: etcd_release
  when: etcd_version == "latest"    
  tags: always

- name: Download && unpack && move to bin folder Etcd
  ansible.builtin.shell: |
        curl -L "{{ download_url }}"/v"{{ etcd_release }}"/etcd-v"{{ etcd_release }}"-linux-amd64.tar.gz -o /tmp/etcd-v"{{ etcd_release }}"-linux-amd64.tar.gz
        tar -xzvf /tmp/etcd-v"{{ etcd_release }}"-linux-amd64.tar.gz -C /tmp 
        mv /tmp/etcd-v"{{ etcd_release }}"-linux-amd64/etcd* /usr/local/bin/
  tags: always

- name: Get installed etcd version
  ansible.builtin.command: etcd --version
  register: etcd_version_output
  changed_when: false
  tags: always

- name: Extract version number
  ansible.builtin.set_fact:
    installed_etcd_version: "{{ etcd_version_output.stdout.split('\n')[0].split()[2] }}"
  tags: always

- name: Compare versions
  ansible.builtin.fail:
    msg: "Installed etcd version {{ installed_etcd_version }} does not match required {{ etcd_release }}"
  when: installed_etcd_version != etcd_release
  tags: always
  ```
</details>  

<details>
  <summary>provision.yaml</summary>
 
 ```bash
 - name: Build etcd initial-cluster string using cluster_net_addr
  ansible.builtin.set_fact:
        etcd_cluster_string: >-
         {%- set parts = [] -%}
         {%- for host in groups['postgres'] -%}
         {%- set _ = parts.append(host ~ '=http://' ~
              hostvars[host]['cluster_net_addr'] ~ ':' ~ etcd_peer_port) -%}
         {%- endfor -%}
         {{ parts | join(',') }}
  delegate_to: localhost
  run_once: yes
  tags: always

- name: Debug the generated cluster string
  ansible.builtin.debug:
        var: etcd_cluster_string
  delegate_to: localhost
  run_once: yes
  tags: always

- name: Ensure the etcd group exists
  ansible.builtin.group:
        name: etcd
        state: present

- name: Ensure etcd user and group exist
  ansible.builtin.user:
        name: etcd
        group: etcd
        system: yes
        shell: /usr/sbin/nologin
        home: /var/lib/etcd

- name: Create etcd data directory
  ansible.builtin.file:
        path: /var/lib/etcd
        state: directory
        owner: etcd
        group: etcd
        mode: '0700'

- name: Render etcd systemd unit with dynamic cluster configuration
  ansible.builtin.template:
        src: etcd.service.j2
        dest: /etc/systemd/system/etcd.service
       
- name: Force systemd to reread configs
  ansible.builtin.systemd_service:
    daemon_reload: true   

- name: Enable and start etcd service
  ansible.builtin.systemd:
        name: etcd
        state: started
        enabled: yes
  register: etcd_service_status
 ```
</details>  

Сервис для systemd для запуска etcd:

<details>
  <summary>etcd.service.j2</summary>

  ```bash

  [Unit]
Description=etcd
After=network.target

[Service]
Type=notify
User=etcd
Group=etcd
PermissionsStartOnly=true

ExecStart=/usr/local/bin/etcd \
  --name {{ inventory_hostname }} \
  --initial-advertise-peer-urls http://{{ cluster_net_addr }}:{{ etcd_peer_port }} \
  --listen-peer-urls http://{{ cluster_net_addr }}:{{ etcd_peer_port }} \
  --listen-client-urls http://{{ cluster_net_addr }}:{{ etcd_client_port }},http://127.0.0.1:{{ etcd_client_port }} \
  --advertise-client-urls http://{{ cluster_net_addr }}:{{ etcd_client_port }} \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster {{ etcd_cluster_string }}\
  --initial-cluster-state new \
  --data-dir /var/lib/etcd

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```
</details>  

По результату имеем запущенный кластер etcd из трех нод, готовый к работе: 

```bash
deploy@lab06-pg-node2:~$ etcdctl member list
70f0c6f79d03049d, started, lab06-pg-node3, http://10.10.70.74:2380, http://10.10.70.74:2379, false
8cd541aa2731c522, started, lab06-pg-node1, http://10.10.70.72:2380, http://10.10.70.72:2379, false
e070309dc3b2d3e7, started, lab06-pg-node2, http://10.10.70.73:2380, http://10.10.70.73:2379, false

```

```bash
deploy@lab06-pg-node2:~$ etcdctl endpoint health --cluster
http://10.10.70.72:2379 is healthy: successfully committed proposal: took = 1.631279ms
http://10.10.70.73:2379 is healthy: successfully committed proposal: took = 1.908909ms
http://10.10.70.74:2379 is healthy: successfully committed proposal: took = 2.097764ms

```


#### 1.2 Разворачивание PostgeSQL + Patroni

Устанавливаем PostgeSQL на трех нодах. Установка стандартная, настроек и запуска PostgeSQL на данном этапе не предусмотрено, т.к. весь менеджмент настройки и запуска берет на себя Patroni.

<details>
  <summary>install.yaml</summary>

```bash
- name: Update package cache
  apt:
    update_cache: yes
  tags: always

- name: Install required packages for apt repository management
  ansible.builtin.apt:
      name:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg
      state: present    
  tags: always

- name: Get pgdg key
  apt_key:
    data: "{{ lookup('file', 'pgapt-key.ACCC4CF8.asc') }}"
    id: ACCC4CF8
    state: present
  tags: always

- name: Setup pgdg repository
  apt_repository:
    repo: "deb http://apt.postgresql.org/pub/repos/apt/ {{ ansible_distribution_release }}-{{ pgdg_repo | default('pgdg') }} main {{ postgresql_major_version}}"
    filename: 'pgdg'
    update_cache: true
  tags: always

- name: Install postgresql-common
  package:
    name: postgresql-common
    default_release: "{{ ansible_distribution_release }}-{{ pgdg_repo | default('pgdg') }}"
    state: present
  tags: always

- name: Disable auto creation of PostgreSQL clusters
  lineinfile:
    dest: "/etc/postgresql-common/createcluster.conf"
    line: "create_main_cluster = false" 
    regexp: ".*create_main_cluster.*"
  tags: always

- name: Install PostgreSQL Server
  package:
    name:
      - "postgresql-{{ postgresql_major_version }}"
      - "postgresql-contrib-{{ postgresql_major_version }}"
      - "postgresql-client-{{ postgresql_major_version }}"
    default_release: "{{ ansible_lsb.codename }}-{{ pgdg_repo | default('pgdg') }}"
    state: present
  tags: always  
```
</details>  

Далее устанавливаем и настраиваем Patroni:

<details>
  <summary>install.yaml</summary>

```bash
- name: Update package cache
  apt:
    update_cache: yes
  tags: always

- name: Install Patroni and dependencies
  ansible.builtin.apt:
      name:
        - patroni
        - python3-psycopg2
      state: present    
  tags: always
```
</details>  


<details>
  <summary>provision.yaml</summary>

  ```bash
  - name: Disable and stop the Postgresql service
  ansible.builtin.systemd_service:
    name: postgresql
    state: stopped
    enabled: false
  tags: always

- name: Create directory for log files
  ansible.builtin.file:
        path: /var/log/patroni
        state: directory
        owner: postgres
        group: postgres
        mode: '0755'
  tags: always

- name: Create directory for postgres in home
  ansible.builtin.file:
        path: /home/postgres/
        state: directory
        owner: postgres
        group: postgres
        mode: '0755'
  tags: always

- name: Render .pgpass_patroni template
  ansible.builtin.template:
    src: templates/.pgpass_patroni.j2
    dest: /home/postgres/.pgpass_patroni
    mode: 0600
    owner: "postgres"
    group: "postgres"    
  tags: always  


- name: Render patroni config.yml templates
  ansible.builtin.template:
    src: templates/config.yml.in.j2
    dest: /etc/patroni/config.yml.in
    mode: 0640
    owner: "postgres"
    group: "postgres"    
  tags: always  

- name: Render patroni dcs.yml templates
  ansible.builtin.template:
    src: templates/dcs.yml.j2
    dest: /etc/patroni/dcs.yml
    mode: 0640
    owner: "postgres"
    group: "postgres"    
  tags: always  

- name: Validate Patroni configuration with error details
  ansible.builtin.command: patroni --validate-config /etc/patroni/config.yml.in
  register: patroni_validation
  failed_when: patroni_validation.rc != 0
  ignore_errors: yes
  tags: always 

- name: Fail the playbook with error message
  ansible.builtin.fail:
    msg: "Patroni config validation failed: {{ patroni_validation.stderr }}"
  when: patroni_validation is failed
  tags: always

- name: Render patroni systemd unit with dynamic cluster configuration
  ansible.builtin.template:
        src: templates/patroni.service.j2
        dest: /etc/systemd/system/patroni.service
  tags: always

- name: Force systemd to reread configs
  ansible.builtin.systemd_service:
    daemon_reload: true
  tags: always

- name: Enable and start patroni service
  ansible.builtin.systemd:
        name: patroni
        state: restarted
        enabled: yes
  register: patroni_service_status
  tags: always 
  ```
</details>  

Основной конфиг Patroni представлен ниже:
<details>
  <summary>provision.yaml</summary>

  ```bash
  # --- REQUIRED CORE ---
scope: patroni_cluster
name: {{ inventory_hostname }}
namespace: "/postgresql-common/" 

# --- REST API ---
restapi:
  listen: 0.0.0.0:8008
  connect_address: {{ cluster_net_addr }}:8008 
  verify_client: optional
#  cafile: /opt/patroni/.tls/ca.crt
#  certfile: /opt/patroni/.tls/node01.crt # Не забыть изменить сертификаты на 2 ноде
#  keyfile: /opt/patroni/.tls/node01.key

#ctl:
#  cacert: /opt/patroni/.tls/ca.crt # Не забыть изменить сертификаты на 2 ноде
#  certfile: /opt/patroni/.tls/node01.crt
#  keyfile: /opt/patroni/.tls/node01.key

# --- DCS (e.g., etcd or consul) ---
etcd3:
  hosts: ["{{ hostvars[groups.postgres[0]]['cluster_net_addr']}}:2379", "{{ hostvars[groups.postgres[0]]['cluster_net_addr']}}:2379", "{{ hostvars[groups.postgres[0]]['cluster_net_addr']}}:2379"]
  protocol: http
  scope: postgresql-common/patroni_cluster

## -- Bootstrap -------------  
{% set pg_nodes = groups['postgres'] %}
{% set is_first_node = inventory_hostname == pg_nodes[0] %}

{% if is_first_node %}
bootstrap:
  dcs:
    #failsafe_mode: true
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    synchronous_mode: true
    synchronous_mode_strict: true
    synchronous_mode_count: 1
    master_start_timeout: 30
    slots:
      prod_replica1:
        type: physical
  postgresql:
    use_pg_rewind: true
    use_slots: true
    parameters:
      shared_buffers: '512MB'
      wal_level: 'replica'
      wal_keep_size: '512MB'
      max_connections: 100
      effective_cache_size: '1GB'
      maintenance_work_mem: '256MB'
      max_wal_senders: 3
      max_replication_slots: 10
      checkpoint_completion_target: 0.7
      log_timezone: 'Europe/Moscow'
      timezone: 'Europe/Moscow'
      lc_messages: 'C.UTF-8'
      password_encryption: 'scram-sha-256'
      superuser_reserved_connections: 3
      synchronous_commit: 'on'
      synchronous_standby_names: 'ANY 1 (...)'
      hot_standby: 'on'
      compute_query_id: 'on'
  initdb:
    - encoding: UTF8
    - data-checksums
    - username: postgres
    - auth: scram-sha-256
    - auth-host: scram-sha-256  # connect from host
    - auth-local: peer  # local coonection via socket 
{% endif %}

# --- PostgreSQL Configuration ---      
postgresql:
  listen: '*'
  connect_address: {{ cluster_net_addr }}:5432 
  use_unix_socket: true
  data_dir: /var/lib/postgresql/{{ postgresql_major_version }}
  config_dir: /var/lib/postgresql/{{ postgresql_major_version }}/
  bin_dir: /usr/lib/postgresql/{{ postgresql_major_version }}/bin
  pgpass: /home/postgres/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: {{ replicator_password }}
    superuser:
      username: postgres
    rewind:
      username: postgres
  pg_hba:
    - local all all peer
    - host all all 127.0.0.1/32 scram-sha-256
    - host all all {{cluster_net}} scram-sha-256
    - host replication replicator 127.0.0.1/32 scram-sha-256
    - host replication replicator ::1/128 scram-sha-256
    - host replication replicator {{cluster_net}} scram-sha-256    
  parameters:
    unix_socket_directories: "/var/run/postgresql/"
    logging_collector: 'on'
    log_directory: '/var/log/patroni'
    log_filename: 'postgresql-{{ postgresql_major_version }}.log'
  create_replica_methods: ["basebackup"]
  basebackup:
    max-rate: 100M
    checkpoint: fas
  ```
</details>  

В данном конфиге идут настройки самого кластера Patroni, параметры для подключения к etcd, а также bootstrap Postgreql(первичная настройка),который выполянется только на одной ноде и настройки postgresql (pg_hba, пользователи, репликация..)

После запуска проверяем состояние кластера.

Состояние ключей в хранилище etcd:

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

Состояние Patroni на мастер-ноде(второй ноде):

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
Состояние Patroni на slave-ноде(первой ноде):

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
Также выведем состояние кластера с использованием утилиты patronictl:

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
Видим, что все три ноды собраны в кластер, lab06-pg-node2 является master нодой, lab06-pg-node3 находится в режиме Sync Standby, что указывает на первого кандитата на занятие позиции  master нодой в случае отказа текущей. lab06-pg-node1 явялется Replica - нодой. Опрераци записи можно делать на мастер ноду, чтение с любой.

Таким образом, на данном этапе собран отказоустойчивый Postgresql кластер на трех нода. В данном кластере происходит автоматический failover при потере мастера с переключением мастера другую ноду. Все узлы имеют стриминговую репликацию, что обеспечивает согласованность данных. В данной настройке также установлена синхронная репликация, что обеспечивает 100% согласованность данных в любой момент времени, однако за счет некоторого снижения общей производительности. 


### 2. Разворачиваем балансировщик HAProxy с keepalived

#### 2.1 Установка и настройка HAProxy

Установочные и настрочные плейбуки, а также конфигруация HAProxy:

<details>
  <summary>install.yaml</summary>

  ```bash
  - name: Update package cache
  apt:
    update_cache: yes
  tags: always

- name: Install Haproxy
  ansible.builtin.apt:
      name:
        - haproxy
      state: present    
  tags: always
  ```
</details>  

<details>
  <summary>provision.yaml</summary>

  ```bash
- name: Render config
  ansible.builtin.template:
      src:  templates/haproxy.cfg.j2      
      dest: /etc/haproxy/haproxy.cfg
      owner: root                           
      group: root                           
      mode: '0644'
  notify: Restart haproxy    
  tags: [always] 
  ```
</details>

<details>
  <summary>haproxy.cfg.j2</summary>

  ```bash
  global
    maxconn 100

defaults
    log    global
    mode    tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /

listen primary
    bind *:{{ ha_proxy_postgres_port_rw }}
    option httpchk OPTIONS /master
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    {% for host in groups['postgres'] %}       
    server node{{ loop.index }} {{ hostvars[host]['cluster_net_addr'] }}:5432 maxconn 100 check port 8008
    {% endfor %}

listen standbys
    balance roundrobin
    bind *:{{ ha_proxy_postgres_port_ro }}
    option httpchk OPTIONS /replica
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    {% for host in groups['postgres'] %}       
    server node{{ loop.index }} {{ hostvars[host]['cluster_net_addr'] }}:5432 maxconn 100 check port 8008
    {% endfor %}
  ```
</details>  

Задача HAProxy прокисровать запросы с клиентов на ноды Postgresql кластера. Также задачей является определение мастер-ноды, к которой направляются запросы на запись. Для разных режимов работы предусмотрено два порта - один для режима RW(чтение + запись), другой RO(read-only). 

#### 2.2 Установка и настройка keepalived

Установочные и настрочные плейбуки, а также конфигруация keepalived:

<details>
  <summary>install.yaml</summary>

  ```bash
  - name: Update package cache
  apt:
    update_cache: yes
  tags: always

- name: Install Keepalived
  ansible.builtin.apt:
      name:
        - keepalived
      state: present    
  tags: always
  ```
</details>  

<details>
  <summary>provision.yaml</summary>

  ```bash
  - name: Enable kernel interface binding
  ansible.builtin.shell: |
      sysctl -w net.ipv4.ip_nonlocal_bind=1

- name: Render checking script
  ansible.builtin.template:
      src:  templates/check_haproxy.sh.j2      
      dest: /etc/keepalived/check_haproxy.sh  
      owner: root                           
      group: root                           
      mode: '0755'  
  tags: [always]        
 
- name: Render config
  ansible.builtin.template:
      src:  templates/keepalived.conf.j2       
      dest: /etc/keepalived/keepalived.conf  
      owner: root                           
      group: root                           
      mode: '0644'
  notify: Restart keepalived    
  tags: [always]  
  ```
</details>

<details>
  <summary>keepalived.conf.j2</summary>

  ```bash
  global_defs {
    enable_script_security
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy""
    interval 2      
    weight 2        
    fall 2          
    rise 2 
    user root         
}

vrrp_instance ha_proxy {

  {% if  vrrp_role == "master" %}
    state MASTER
  {% elif vrrp_role == "slave" %}
    state BACKUP
  {% endif %}
    interface eth1   
    virtual_router_id 254 
  {% if vrrp_role == "master" %}
    priority 100
  {% elif vrrp_role == "slave" %}
    priority 99
  {% endif %}    
    
    advert_int 1 
 
  {% if vrrp_role == "master" %}
    unicast_src_ip {{ vrrp_net_addr }}
    unicast_peer {
        {{ hostvars[groups.balancers[1]]['vrrp_net_addr'] }}
    }
  {% elif vrrp_role == "slave"  %}
    unicast_src_ip {{ vrrp_net_addr  }}
    unicast_peer {
        {{ hostvars[groups.balancers[0]]['vrrp_net_addr'] }}
    }
  {% endif %}
    

    virtual_ipaddress {
        {{ vip }} dev eth0
    } track_script {
        chk_haproxy
    }
}

  ```
</details>

Задача keepalived маршрутизация трафика к активной на данный момент ноде HAProxy за счет использования VRRP протокола и VIP, который "плавает" между нодами HAProxy. 


### 3. Тестируем полученную конфигруацию

#### 3.1 Тестирование отказоустойчивости кластера Postgresql

Пробуем проверить базовую работоспобность собранного стенда с использованием DBeaver.

![](/Lab06_PostgreSQL_Cluster/pics/Basic_pg-conn-test.png)

Мы подключаемся к кластеру с использованием VIP (192.168.70.20) по двум портам. Порт 5000 используется для режима RW, а порт 5001 для режима RO. Видим, что оба подключения работают. На первом делаем тестовое создание таблицы и также видим ее во втором подключении.

Протестируем вывод из работы мастер-ноды кластера Postgesql.

Используя утилиту patronictl, командой switchover переключим мастера на другую ноду и после чего ее полностью выключим:

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

deploy@lab06-pg-node2:~$ sudo patronictl -c /etc/patroni/config.yml.in list
+ Cluster: patroni_cluster (7624113203280740141) ---------+----+-------------+-----+------------+-----+
| Member         | Host        | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
| lab06-pg-node1 | 10.10.70.72 | Sync Standby | streaming |  3 |   0/64793D0 |   0 |  0/64793D0 |   0 |
| lab06-pg-node2 | 10.10.70.73 | Replica      | streaming |  3 |   0/64793D0 |   0 |  0/64793D0 |   0 |
| lab06-pg-node3 | 10.10.70.74 | Leader       | running   |  3 |             |     |            |     |
+----------------+-------------+--------------+-----------+----+-------------+-----+------------+-----+
```

Видим, что мастер нода ушла к lab06-pg-node3 и бывшая мастер lab06-pg-node2 находится в состоянии unknown (будучи полностью выключенной). На работоспособность кластера это не оказало влияния - оба соединения остались доступны:

![](/Lab06_PostgreSQL_Cluster/pics/Test_master_is_dead.png)

 Также работоспобность кластера сохраняется и при "внеплановых" выключениях нод (аварийных). При потере ноды она выводится из кластера и ее роль переходит соседней(если она была мастер-нодой). Однако при таких выключениях обычно необходим редеплой ноды, т.к. при аварийном завершении нарушается нормальная wal-репликация и нода уже не может самостоятельно вернуться в кластер. 

#### 3.1 Тестирование отказоустойчивости балансировщика HAProxy

Проверим состояние HAProxy на мастер ноде (в данный момент). Можно также отметить в логах определение состояния нод postgesql-кластера при тестах выше. Видно, что HAProxy определяло выход из строя мастер-ноды и корректировало трафик.

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

Выключаем HAProxy на мастере и смотрим работу на второй ноде HAProxy:

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

Видим, что вторая нода перешла в состояние "MASTER", VRRP протокол назначил VIP(192.168.70.20) интерфейсу. В данный момент происходит выборс ARP сообщения для обновления ARP-записей и клиенты начнут обращаться к уже второй ноде по прежнему IP.

Проверям работу и убеждаемся, что все продолжаем работать и "Бубликов" на месте:)

![](/Lab06_PostgreSQL_Cluster/pics/Test_haproxy_shut.png)


Выводы:

В данной работе был рассмотрен вопрос создания отказоустойчивого кластера Postgresql + Patroni  в сочетании с отказоустойчивым балансировщиком на базе HAPproxy + keeplaived. Задачей было создание отказустойчивой системы, способную сохранять штатную работоспобность при выходе из строя любой одной ноды (или двух, если они в разных логических частях: кластере или балансировщике). Проверена работоспобность при различных сценариях отказов и показана высокая доступность системы.  