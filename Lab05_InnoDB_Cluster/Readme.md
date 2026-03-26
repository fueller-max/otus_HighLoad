# Развернуть InnoDB или  PXC кластер

## Цель

Перевести базу веб-проекта на один из вариантов кластера MySQL: Percona XtraDB Cluster или InnoDB Cluster.

## Задание

1. Развернуть отказоустойчивый кластер MySQL(Percona XtraDB Cluster или InnoDB Cluster)
2. Перевести базу данных веб-проекта на кластер


## Решение

### 1. Разворачивание отказоустойчивого кластера MySQL на базе InnoDB Cluster


Выполним разворачивание отказоустойчивого кластера MySQL на базе InnoDB Cluster с использованием 3-ех нод. 

Общая схема данного кластера представлена на рисунке:

![innoDB_cluster](/Lab05_InnoDB_Cluster/pics/InnoDB_cluster.jpg)

Кластер состоит из 3 нод, между которыми осуществляется репликация. Мастер(текущая на данный момент) принимает данные как на запись так и на чтение(режим 'RW'). Остальные только на чтение(режим 'RO'). При выходе из строя Мастер ноды, одна из оставшихся берет статус Мастер-ноды. Доступ кластеру осуществляется через MySQL Router, который устанавливается на целевой системе (бекенд) и обеспечивает доступ к базе через локальный адрес на целевой ноде.


Развертывание 3 нод дял кластера выполним средствами Terraform на стенде Proxmox. Проект Terraform представлен в папке данной работы.

Настройку узлов кластера осуществим с использованием Ansible. Основной плейбук настройки представлен ниже:

<details>
  <summary>provision.yaml</summary>

  ```bash
- name: Replace the whole content of /etc/hosts
  ansible.builtin.template:
      src:  templates/hosts.j2          
      dest: /etc/hosts      
      owner: root                           
      group: root                           
      mode: '0644'

- name: Ensure that file hosts not get overwritten by cloud init anymore
  ansible.builtin.lineinfile:
    path: /etc/cloud/cloud.cfg
    regexp: '.*?update_etc_hosts' 
    line: '# - update_etc_hosts' # The desired line
    create: true # Create file if it does not exist
    backup: true # Create a backup of the original file     

- name: Set MySQL basic config
  ansible.builtin.template:
      src:  templates/mysqld.cnf.j2         
      dest: /etc/mysql/mysql.conf.d/mysqld.cnf     
      owner: root                           
      group: root                           
      mode: '0644'
  notify:  Restart MySQL

- name: Ensure MySQL service is running
  systemd:
      name: mysql
      state: started
      enabled: yes   

- name: Create .my.cnf with MySQL credentials
  copy:
    content: |
      [client]
      user=root
      password={{ mysql_root_password }}
    dest: /root/.my.cnf
    mode: '0600'

- name: Set MySQL root password 
  community.mysql.mysql_user:
      name: root
      password: "{{ mysql_root_password }}"
      priv: "*.*:ALL,GRANT"
      host: "%"
      login_unix_socket: /var/run/mysqld/mysqld.sock
  vars:
    ansible_python_interpreter: /opt/mysql-venv/bin/python3     
      
- name: Create cluster admin user
  community.mysql.mysql_user:
      login_user: root
      login_password: "{{ mysql_root_password }}"
      name: "{{ admin_user }}"
      password: "{{ admin_password }}"
      priv: "*.*:ALL,GRANT"
      host: "%"
  vars:
    ansible_python_interpreter: /opt/mysql-venv/bin/python3


- name: Configure MySQL instances for InnoDB Cluster
  ansible.builtin.shell: |
     yes | mysqlsh --user={{ admin_user }} --password={{ admin_password }} --host={{ cluster_node }} --py \
     --execute="dba.configure_instance()"
    
- name: Create InnoDB Cluster on node1
  shell: |
    mysqlsh --user={{ admin_user }} --password={{ admin_password }} --host={{ cluster_node }} --py \
    --execute='dba.create_cluster("{{ cluster_name }}");'
  args:
    executable: /bin/bash
  run_once: true  
  register: cluster_output
  delegate_to: "{{ groups.databases | first }}"


- name: Add 2nd node to cluster. Create temporary  script
  copy:
    content: |
      cluster = dba.get_cluster()
      cluster.add_instance('{{ hostvars[groups.databases[1]]['cluster_node'] }}')
    dest: /tmp/add_instance.py
  no_log: true

- name: Add 2nd node to cluster
  shell: |
     echo C | mysqlsh --user={{ admin_user }} --password={{ admin_password }} --host={{ cluster_node }} --file=/tmp/add_instance.py
  args:
    executable: /bin/bash
  run_once: true    
  delegate_to:  "{{ groups.databases | first }}"

- name: Add 3nd node to cluster.Clean up temporary script
  file:
    path: /tmp/add_instance.py
    state: absent

- name: Add 3rd node to cluster. Create temporary  script
  copy:
    content: |
      cluster = dba.get_cluster()
      cluster.add_instance('{{ hostvars[groups.databases[2]]['cluster_node'] }}')
    dest: /tmp/add_instance.py
  no_log: true

- name: Add 3rd node to cluster
  shell: |
     echo C | mysqlsh --user={{ admin_user }} --password={{ admin_password }} --host={{ cluster_node }} --file=/tmp/add_instance.py
  args:
    executable: /bin/bash
  run_once: true    
  delegate_to:  "{{ groups.databases | first }}"

- name: Add 3rd node to cluster.Clean up temporary script
  file:
    path: /tmp/add_instance.py
    state: absent

- name: Create MySQL user for MySQL Router
  community.mysql.mysql_user:
    login_host: "{{ cluster_node }}"
    login_user:  root 
    login_password: "{{ mysql_root_password }}"
    name: "{{ mysql_router_user }}"
    password: "{{ mysql_router_password }}"
    host: "%"
    priv:
      "mysql_innodb_cluster_metadata.*": SELECT
      "PERFORMANCE_SCHEMA.*": SELECT
    state: present
  no_log: true
  run_once: true    
  delegate_to:  "{{ groups.databases | first }}"
  vars:
      ansible_python_interpreter: /opt/mysql-venv/bin/python3

  ```
</details>

Основные шаги следующие:

1. Настройка DNS - обязателен, т.к. общение в кластере между нодами основано на именах хостов
2. Базовая настройка MySQL инстанса - bind-адресов и пр.
3. Настройка базовых пользователей для кластера
4. Запуск конфигурирования инстанса для работы к кластере InnoDB (через mysqlsh)
5. Запуск кластера на 1-ой ноде (будет принята за мастер-ноду) (через mysqlsh)
6. Последовательное добавление 2 и 3 ноды к кластеру (через mysqlsh)

После запуска настройки получаем следующее состояние кластера:

```bash
MySQL  cluster-node-db1:3306 ssl  Py > cluster.status()
{
    "clusterName": "MyInnoDBCluster", 
    "defaultReplicaSet": {
        "name": "default", 
        "primary": "cluster-node-db1:3306", 
        "ssl": "REQUIRED", 
        "status": "OK", 
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.", 
        "topology": {
            "cluster-node-db1:3306": {
                "address": "cluster-node-db1:3306", 
                "memberRole": "PRIMARY", 
                "mode": "R/W", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }, 
            "cluster-node-db2:3306": {
                "address": "cluster-node-db2:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }, 
            "cluster-node-db3:3306": {
                "address": "cluster-node-db3:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }
        }, 
        "topologyMode": "Single-Primary"
    }, 
    "groupInformationSourceMember": "cluster-node-db1:3306"

```
Видим, что сам кластер собрался, находится в отказоустойчивом состоянии с возможностью выпадания из работы одной ноды. Мастер нода - 1ая, 2 и 3 в состоянии "SECONDARY".

На этом кластер готов к работе настройка самого кластера закончена.

#### 2. Интеграция кластерной базы данных в веб-проект

Осуществим интеграцию созданного кластера в существующий веб-проект из прошлой работы.

Добавим плей Ansible для установки Mysql router на все три хоста бекенда. Данный плей осуществит установку и базовую настройку роутера. Сам bootsrap роутера выполним в ручную.

<details>
  <summary>mysql-router.yaml</summary>

  ```bash
  - name: Install MySQL Router
  apt:
    name: mysql-router
    state: present
  when: ansible_os_family == "Debian"


- name: Create a user mysql no login shell
  ansible.builtin.user:
    name: mysql
    shell: /usr/sbin/nologin
    state: present
    createhome: false 

- name: Create MySQL Router directories
  file:
    path: "{{ item }}"
    state: directory
    owner: mysql
    group: mysql
    mode: '0777'
  loop:
    - "{{ router_config_dir }}"
    - "{{ router_log_dir }}"
    - "{{ router_data_dir }}"


# - name: Bootstrap MySQL Router configuration (non-interactive)
#   command: >
#     mysqlrouter --bootstrap {{ mysql_cluster_user }}@{{ cluster_nodes[0].ip }}:{{ mysql_port }}
#     --directory {{ router_data_dir }}
#     --user mysql
#     --connect-timeout 30
#   environment:
#     MYSQL_PWD: "{{ mysql_cluster_password }}"
#   args:
#     creates: "{{ router_data_dir }}/mysqlrouter.conf"
#   register: bootstrap_result
#   failed_when: bootstrap_result.rc != 0 and "already exists" not in bootstrap_result.stderr

# - name: Bootstrap MySQL Router configuration
#   command: >
#     mysqlrouter --bootstrap {{ mysql_cluster_user }}@{{ cluster_nodes[0].ip }}:{{ mysql_port }}
#     --directory {{ router_data_dir }}
#     --user mysql
#   environment:
#     MYSQL_PWD: "{{ mysql_cluster_password }}"
#   args:
#     creates: "{{ router_data_dir }}/mysqlrouter.conf"
#   no_log: true

- name: Copy custom MySQL Router configuration template
  template:
    src: mysqlrouter.conf.j2
    dest: "{{ router_data_dir }}/mysqlrouter.conf"
    owner: mysql
    group: mysql
    mode: '0644'

- name: Ensure MySQL Router service is started and enabled
  systemd:
    name: mysqlrouter
    state: started
    enabled: yes
  ```

</details>

После установки запускаем команду bootstrap и получаем следующий вывод:

```bash
# Bootstrapping MySQL Router 8.0.45 ((Ubuntu)) instance at '/opt/mysql-router/data'...

- Creating account(s) (only those that are needed, if any)
- Verifying account (using it to run SQL queries that would be run by Router)
- Storing account in keyring
- Adjusting permissions of generated files
- Creating configuration /opt/mysql-router/data/mysqlrouter.conf

# MySQL Router configured for the InnoDB Cluster 'MyInnoDBCluster'

After this MySQL Router has been started with the generated configuration

    $ mysqlrouter -c /opt/mysql-router/data/mysqlrouter.conf

InnoDB Cluster 'MyInnoDBCluster' can be reached by connecting to:

## MySQL Classic protocol

- Read/Write Connections: localhost:6446
- Read/Only Connections:  localhost:6447

## MySQL X protocol

- Read/Write Connections: localhost:6448
- Read/Only Connections:  localhost:6449

```

Видим, что конфиг роутера сгенерирован и готов к запуску. Предоставляет сервис доступа к БД на localhost:6446 и localhost:6447 для сессий чтение/запись и чтение соответственно.

В логах роутера после запуска видим, что созданный кластер 'MyInnoDBCluster' определился и перечислены три его ноды с указанием режима - RW или RO.

```bash
2026-03-25 17:57:31 routing INFO [79e0deffd6c0] [routing:bootstrap_ro] started: routing strategy = round-robin-with-fallback
2026-03-25 17:57:31 routing INFO [79e0deffd6c0] Start accepting connections for routing routing:bootstrap_ro listening on '0.0.0.0:6447'
2026-03-25 17:57:31 routing INFO [79e0ddffb6c0] [routing:bootstrap_x_ro] started: routing strategy = round-robin-with-fallback
2026-03-25 17:57:31 routing INFO [79e0ddffb6c0] Start accepting connections for routing routing:bootstrap_x_ro listening on '0.0.0.0:6449'
2026-03-25 17:57:31 routing INFO [79e0de7fc6c0] [routing:bootstrap_rw] started: routing strategy = first-available
2026-03-25 17:57:31 routing INFO [79e0de7fc6c0] Start accepting connections for routing routing:bootstrap_rw listening on '0.0.0.0:6446'
2026-03-25 17:57:31 routing INFO [79e0dd7fa6c0] [routing:bootstrap_x_rw] started: routing strategy = first-available
2026-03-25 17:57:31 routing INFO [79e0dd7fa6c0] Start accepting connections for routing routing:bootstrap_x_rw listening on '0.0.0.0:6448'
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0] Connected with metadata server running on cluster-node-db1:3306
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0] Potential changes detected in cluster after metadata refresh (view_id=0)
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0] Metadata for cluster 'MyInnoDBCluster' has 3 member(s), single-primary: 
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0]     cluster-node-db1:3306 / 33060 - mode=RW 
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0]     cluster-node-db2:3306 / 33060 - mode=RO 
2026-03-25 17:57:31 metadata_cache INFO [79e1207fd6c0]     cluster-node-db3:3306 / 33060 - mode=RO
```

Далее изменим настройки WordPress для обращения локальному адресу, предоставляемым ротуером для доступа к базе:

```bash
<?php
// ** MySQL settings
define('DB_NAME', 'wordpress_db');
define('DB_USER', 'wp_user');
define('DB_PASSWORD', 'strong_password');
#define('DB_HOST', '10.10.30.41');
define('DB_HOST', '127.0.0.1:6446');
#Settings to use without doman name allowing access using just IP address.
#define( 'WP_HOME', 'http://' . $_SERVER['HTTP_HOST'] );
#define( 'WP_SITEURL', 'http://' . $_SERVER['HTTP_HOST'] );
define('WP_HOME', 'http://lab04.dev.net');
define('WP_SITEURL', 'http://lab04.dev.net');

```

Проверям работу и убеждаемся, что веб-сервис работает:

![](/Lab05_InnoDB_Cluster/pics/Lab05_page1.png)

Далее имитируем выход из строя одной ноды кластера. Погасим первую ноду, которая выполняет роль мастера и находится в режиме RW.

Смотрим на состояние кластера на 2-ой ноде: 

```bash
 MySQL  cluster-node-db2:3306 ssl  Py > cluster.status()
{
    "clusterName": "MyInnoDBCluster", 
    "defaultReplicaSet": {
        "name": "default", 
        "primary": "cluster-node-db3:3306", 
        "ssl": "REQUIRED", 
        "status": "OK_NO_TOLERANCE_PARTIAL", 
        "statusText": "Cluster is NOT tolerant to any failures. 1 member is not active.", 
        "topology": {
            "cluster-node-db1:3306": {
                "address": "cluster-node-db1:3306", 
                "memberRole": "SECONDARY", 
                "mode": "n/a", 
                "readReplicas": {}, 
                "role": "HA", 
                "shellConnectError": "MySQL Error 2003: Could not open connection to 'cluster-node-db1:3306': Can't connect to MySQL server on 'cluster-node-db1:3306' (110)", 
                "status": "(MISSING)"
            }, 
            "cluster-node-db2:3306": {
                "address": "cluster-node-db2:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }, 
            "cluster-node-db3:3306": {
                "address": "cluster-node-db3:3306", 
                "memberRole": "PRIMARY", 
                "mode": "R/W", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }
        }, 
        "topologyMode": "Single-Primary"
    }, 
    "groupInformationSourceMember": "cluster-node-db3:3306"
```

Видим, что первая-нода стала для кластера недоступной и роль мастера перешла к 3-ей ноде, и она также перешла в режим RW. Т.е. теперь запросы на запись будет принимать она. Сам кластер находится в рабочем но теперь уже не в отказоустойчивом состоянии - выход из строя еще одной ноды его остановит. 

Проверим, что веб сервис продолжает работать без сбоев:

![](/Lab05_InnoDB_Cluster/pics/Lab05_after_db1_failure.png)

После включения первой ноды обратно она встает автоматически в кластер, но уже в роли  "SECONDARY", а сам кластер переходит в свое нормальное отказоустойчивое состояние.

```bash
MySQL  cluster-node-db2:3306 ssl  Py > cluster.status()
{
    "clusterName": "MyInnoDBCluster", 
    "defaultReplicaSet": {
        "name": "default", 
        "primary": "cluster-node-db3:3306", 
        "ssl": "REQUIRED", 
        "status": "OK", 
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.", 
        "topology": {
            "cluster-node-db1:3306": {
                "address": "cluster-node-db1:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }, 
            "cluster-node-db2:3306": {
                "address": "cluster-node-db2:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }, 
            "cluster-node-db3:3306": {
                "address": "cluster-node-db3:3306", 
                "memberRole": "PRIMARY", 
                "mode": "R/W", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.45"
            }
        }, 
        "topologyMode": "Single-Primary"
    }, 
    "groupInformationSourceMember": "cluster-node-db3:3306"
}
```


Выводы: 

В данной работе была рассмотрена работа отказоустойчивого кластера базы данных MySQL на основе InnoDB кластера и его последующая интеграция в веб-проект. Была выполнена автоматизированная настройка самого кластера. Далее выполнена его интеграция в существующий веб-проект с использованием MySQL роутера и проверен сценарий сбоя одной ноды кластера. 