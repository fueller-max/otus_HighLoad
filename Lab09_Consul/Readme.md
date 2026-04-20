# Consul cluster для service discovery и DNS

## Цель

1. Настроить Consul cluster для управления DNS-записями веб-портала;
2. Реализовать отказоустойчивую балансировку нагрузки через DNS вместо плавающего IP

## Задание

1. Разверните кластер Consul (минимум 3 сервера и 1 клиент).
2. Зарегистрируйте веб-портал, реализованный в предыдущем задании, как сервис в Consul.
3. Настройте DNS через Consul так, чтобы доменное имя веб-портала разрешалось в IP-адреса его работающих инстансов.
4. Отключите использование плавающего IP — используйте DNS Consul для балансировки трафика.
5. Проверьте, что при падении одного из веб-серверов его IP больше не выдается в DNS-ответе.


## Решение

### 0. Схема стенда, описание работы.

Соберем стенд с использованием Consul Cluster в качестве Service Discovery для сервисов балансировщиков и бэкендов.

![](/Lab09_Consul/pics/Consul_lab.jpg)

Стенд включает в себя:

1. Кластер Consul - 3 ноды
2. Балансировщики трафика 2 ноды
3. Бэкенды - 3 ноды

На каждой из нод балансировщиков и бекендов установлен Сonsul Agent для обнаружения сервиса и его регистрации в общей системе Сonsul. Целью на балансировщиках является распределение входящего трафика на них посредством выдачи DNS ответов с их IP адресами (схема со статическим IP с использованием VRRP упраздняется). Сервис-дискавери на бэкендах работает с целью определения актуальных живых бекендов и динамической генерации upstream конфига для балансировщиков.

### 1. Разворачиваем Consul кластер.

Развернем отказоустойчивый кластер Consul на трех нодах.

Для установки воспользуемся зеркалом Яндекс:


<details>
  <summary>install.yaml</summary>

  ```bash
  - name: Update repo && install unzip
  ansible.builtin.apt:
    name: unzip
    state: present
    update_cache: yes
  tags: [always]  
  
- name: Download from Yandex Mirror
  ansible.builtin.shell: |
    cd /tmp
    wget https://hashicorp-releases.yandexcloud.net/consul/"{{ cousul_ver }}"/consul_"{{ cousul_ver }}"_linux_amd64.zip
  args:
    creates: consul_"{{ cousul_ver}}"_linux_amd64.zip 
  tags: [always] 

- name: Unpack Consul  
  ansible.builtin.shell: |
    cd /tmp
    unzip consul_"{{ cousul_ver}}"_linux_amd64.zip -d /usr/bin
  tags: [always]  

- name: Check installation
  command: consul --version
  register: consul_check
  changed_when: false
  tags: [always]

- name: Fail if consul is not installed
  fail:
    msg: "Consul is not installed"
  when: consul_check.rc != 0
  tags: [always]
  
  ```
</details> 

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
  tags: [always]

- name: Ensure that file hosts not get overwritten by cloud init anymore
  ansible.builtin.lineinfile:
    path: /etc/cloud/cloud.cfg
    regexp: '.*?update_etc_hosts' 
    line: '# - update_etc_hosts' # The desired line
    backup: true # Create a backup of the original file  
  tags: [always]

- name: Create a directoriy for TLS infra
  ansible.builtin.file:
    path: "{{ tls_dir }}"
    state: directory
    mode: '0755'
    owner: root
    group: root  
  tags: [always] 

- name: Generate encryption key
  ansible.builtin.shell: |
    cd "{{ tls_dir }}"
    consul keygen | tee encryption.key
  args:
    creates: encryption.key
  run_once: true    
  delegate_to:  "{{ groups.consul_servers | first }}"  
  tags: [always]  

- name: Generate Certificate Authority
  ansible.builtin.shell: |
    cd "{{ tls_dir }}"
    consul tls ca create
  args:
    creates: consul-agent-ca.pem
  run_once: true    
  delegate_to:  "{{ groups.consul_servers | first }}"  
  tags: [always]  

- name: Generate certificates for each node
  ansible.builtin.shell: |
    cd "{{ tls_dir }}"
    consul tls cert create -server -dc "{{ data_center }}"
  args:
    creates: "{{ tls_dir }}/server-{{ item }}.crt"
  loop: "{{ groups.consul_servers }}"    
  delegate_to:  "{{ groups.consul_servers | first }}"
  run_once: true 
  tags: [always]  

- name: Create a directoriy for data
  ansible.builtin.file:
    path: "{{ data_dir }}"
    state: directory
    mode: '0755'
    owner: root
    group: root   
  tags: [always] 

- name: Read encryption key 
  ansible.builtin.shell:  'cat {{ tls_dir }}/encryption.key'
  register: ENCRYPTION_KEY
  run_once: true    
  delegate_to:  "{{ groups.consul_servers | first }}"
  tags: [always]  

- name: Render server config
  ansible.builtin.template:
    src: templates/consul.json.j2
    dest: /etc/consul.d/consul.json   
  tags: [always] 
 
- name: Fetch CA from 1st node host to control node
  fetch:
    src: "{{ tls_dir }}/consul-agent-ca.pem"
    dest: /tmp/fetched_files/
    flat: no
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true    
  tags: [always]

- name: Copy CA to nodes 
  copy:
    src: /tmp/fetched_files/{{ inventory_hostname }}/{{ tls_dir}}/consul-agent-ca.pem
    dest: "{{ tls_dir }}/consul-agent-ca.pem"
    owner: root   
    group: root   
    mode: '0755'  
  when: inventory_hostname !=  groups['consul_servers'][0]       
  tags: [always]   

- name: Find TLS certificate files on 1st node
  ansible.builtin.find:
    paths: "{{ tls_dir }}"
    patterns: "{{ data_center }}-server-consul-*"
  register: cert_files
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true  
  tags: [always]

- name: Fetch found TLS certificates
  ansible.builtin.fetch:
    src: "{{ item.path }}"
    dest: "/tmp/fetched_files/"
    flat: no
  loop: "{{ cert_files.files }}"
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true
  tags: [always]

- name: Copy fetched certs to nodes - cert
  copy:
    src: /tmp/fetched_files/{{ groups['consul_servers'][0] }}/{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem
    dest: "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem"
    owner: root   
    group: root   
    mode: '0755'  
  when: inventory_hostname !=  groups['consul_servers'][0]       
  tags: [always] 

- name: Copy fetched certs to nodes - key
  copy:
    src: /tmp/fetched_files/{{ groups['consul_servers'][0] }}/{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem
    dest: "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem"
    owner: root   
    group: root   
    mode: '0755'  
  when: inventory_hostname !=  groups['consul_servers'][0]       
  tags: [always]   

  ```
</details>  

Consul запускаем в виде systemd сервиса:

```bash
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=consul
Group=consul
PIDFile=/var/run/consul/consul.pid
ExecStart=/usr/bin/consul agent -config-file=/etc/consul.d/consul.json -pid-file=/var/run/consul/consul.pid
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target
```

Конфигурация нод Consul кластера:

```bash
{
  "node_name": "{{ inventory_hostname }}", 
  "server": true,
  "bootstrap_expect": 3,
  "data_dir": "{{ data_dir }}",
  "client_addr": "0.0.0.0",
  "ui": true,
  "bind_addr": "{{ cluster_net_addr }}",
  "disable_update_check": true,
  {% set host_list = groups['consul_servers'] %}
  {%- set current_host = inventory_hostname -%}
  {%- set other_hosts = host_list | reject('equalto', current_host) | list -%}

  "retry_join": [{{ other_hosts | join('","') | regex_replace('^', '"') | regex_replace('$', '"') }}],
  "encrypt": "{{ ENCRYPTION_KEY.stdout }}",
  "addresses": {
    "http": "0.0.0.0"
  },
  "ports": {
    "http": 8500
  },
  "tls": {
    "defaults": {
       "verify_incoming": true,
       "verify_outgoing": true,
       "ca_file": "{{ tls_dir }}/consul-agent-ca.pem",
       "cert_file": "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem",
       "key_file": "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem"
    },
    "internal_rpc": {
      "verify_server_hostname": true
    }
  }
}
```

Используем TLS, включаем UI(web-диагностику).

После разворачивания проверяем состояние кластера:

```bash
deploy@lab09-consul-srv1:/etc/consul.d$ sudo consul members
Node               Address           Status  Type    Build   Protocol  DC   Partition  Segment
lab09-consul-srv1  10.10.20.91:8301  alive   server  1.22.6  2         dc1  default    <all>
lab09-consul-srv2  10.10.20.92:8301  alive   server  1.22.6  2         dc1  default    <all>
lab09-consul-srv3  10.10.20.93:8301  alive   server  1.22.6  2         dc1  default    <all>

deploy@lab09-consul-srv1:/etc/consul.d$ sudo consul operator raft list-peers
Node               ID                                    Address           State     Voter  RaftProtocol  Commit Index  Trails Leader By
lab09-consul-srv1  8eb7b3b5-1574-156e-3696-8a93822473d3  10.10.20.91:8300  leader    true   3             108           -
lab09-consul-srv3  ae3a20d8-5196-003d-f192-54724f85fe2b  10.10.20.93:8300  follower  true   3             108           0 commits
lab09-consul-srv2  3ef46df0-53a8-d226-f026-1da7d77b9a35  10.10.20.92:8300  follower  true   3             108           0 commits
deploy@lab09-consul-srv1:/etc/consul.d$ curl http://127.0.0.1:8500/v1/status/leader
"10.10.20.91:8300"
```

Также состояние кластера через UI:

![](/Lab09_Consul/pics/Consul_cluster_initial.png)

Видим, что кластер собран, все три ноды присутствуют и участвуют в кластерном голосовании.  

### 2. Установка Consul клиентов на ноды.

Установка клиентов аналогична описанной выше для нод кластера. 

Для клиентов используем следующий конфиг:

```bash
{
  "node_name": "{{ inventory_hostname }}", 
  "data_dir": "{{ data_dir }}",
  "client_addr": "0.0.0.0",
  "bind_addr": "{{ cluster_net_addr }}",
  "disable_update_check": true,
  {%- set server_list = groups['consul_servers'] -%}
  
  "retry_join": [{{ server_list | join('","') | regex_replace('^', '"') | regex_replace('$', '"') }}],
  "encrypt": "{{ ENCRYPTION_KEY.stdout }}",
  "addresses": {
    "http": "0.0.0.0"
  },
  "ports": {
    "http": 8500
  },
  "tls": {
    "defaults": {
       "verify_incoming": true,
       "verify_outgoing": true,
       "ca_file": "{{ tls_dir }}/consul-agent-ca.pem",
       "cert_file": "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem",
       "key_file": "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem"
    },
    "internal_rpc": {
      "verify_server_hostname": true
    }
  }
}
```
Здесь отключен режим "server, а также UI. Поскольку используется TLS, то предусмотрен шаг генерации сертификатов и их дистрибуцию по хостам группы.

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
  tags: [always]

- name: Ensure that file hosts not get overwritten by cloud init anymore
  ansible.builtin.lineinfile:
    path: /etc/cloud/cloud.cfg
    regexp: '.*?update_etc_hosts' 
    line: '# - update_etc_hosts' # The desired line
    backup: true # Create a backup of the original file  
  tags: [always]

- name: Create a directoriy for TLS infra
  ansible.builtin.file:
    path: "{{ tls_dir }}"
    state: directory
    mode: '0755'
    owner: root
    group: root  
  tags: [always] 

- name: Create a directoriy for data
  ansible.builtin.file:
    path: "{{ data_dir }}"
    state: directory
    mode: '0755'
    owner: root
    group: root   
  tags: [always]  
  
- name: Generate certificates for each node
  ansible.builtin.shell: |
    cd "{{ tls_dir }}"
    consul tls cert create -server -dc "{{ data_center }}"
  args:
    creates: "{{ tls_dir }}/server-{{ item }}.crt"
  loop: "{{ groups[client_group_name] | default([]) }}"    
  delegate_to:  "{{ groups.consul_servers | first }}"
  run_once: true 
  tags: [always]  

- name: Read encryption key 
  ansible.builtin.shell:  'cat {{ tls_dir }}/encryption.key'
  register: ENCRYPTION_KEY
  run_once: true    
  delegate_to:  "{{ groups.consul_servers | first }}"
  tags: [always]  

- name: Render client config
  ansible.builtin.template:
    src: templates/consul.json.j2
    dest: /etc/consul.d/consul.json   
  tags: [always] 
 
- name: Fetch CA from 1st node host to control node
  fetch:
    src: "{{ tls_dir }}/consul-agent-ca.pem"
    dest: /tmp/fetched_files/
    flat: yes
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true    
  tags: [always]

- name: Copy CA to nodes 
  copy:
    src: /tmp/fetched_files/consul-agent-ca.pem
    dest: "{{ tls_dir }}/consul-agent-ca.pem"
    owner: root   
    group: root   
    mode: '0755'        
  tags: [always]   

- name: Find TLS certificate files on 1st node
  ansible.builtin.find:
    paths: "{{ tls_dir }}"
    patterns: "{{ data_center }}-server-consul-*"
  register: cert_files
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true  
  tags: [always]

- name: Fetch found TLS certificates
  ansible.builtin.fetch:
    src: "{{ item.path }}"
    dest: "/tmp/fetched_files/"
    flat: true
  loop: "{{ cert_files.files }}"
  delegate_to: "{{ groups.consul_servers | first }}"
  run_once: true
  tags: [always]

- name: Copy fetched certs to nodes - cert
  copy:
    src: /tmp/fetched_files/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem
    dest: "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}.pem"
    owner: root   
    group: root   
    mode: '0755'         
  tags: [always] 

- name: Copy fetched certs to nodes - key
  copy:
    src: /tmp/fetched_files/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem
    dest: "{{ tls_dir }}/{{ data_center }}-server-{{ domain }}-{{ node_id }}-key.pem"
    owner: root   
    group: root   
    mode: '0755'       
  tags: [always]  

  ```
</details>  

Consul клиенты также запускаются как сервисы systemd.

После установки клиентов имеем следующую картину:

![](/Lab09_Consul/pics/Consul_cluster_clients.png)

Видим, что все интересующие ноды появились, но пока нет зарегистрированных сервисов.


### 3. Регистрация сервисов в Consul


<details>
  <summary>install.yaml</summary>

  ```bash
  
  ```
</details> 

<details>
  <summary>provision.yaml</summary>

  ```bash

  ```
</details>  

```bash
deploy@lab09-consul-srv1:~$ consul catalog services
backend
consul
load_balancer
deploy@lab09-consul-srv1:~$ dig @127.0.0.1 -p 8600 load_balancer.service.consul A +short
192.168.70.41
192.168.70.42
deploy@lab09-consul-srv1:~$ dig @127.0.0.1 -p 8600 backend.service.consul A +short
10.10.20.44
10.10.20.45
10.10.20.43

```

```bash
// ------- consul zone ---------------------------
// Forward to Consul cluster
zone "consul" IN {
    type forward;
    forward only;
    forwarders {
        192.168.70.91 port 8600;  # serv_1 Consul
        192.168.70.92 port 8600;  # serv_2 Consul
        192.168.70.93 port 8600;  # serv_3 Consul
    };
};
// ---------------------------------------------

```

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64989
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.42
load_balancer.service.consul. 0	IN	A	192.168.70.41

;; Query time: 5 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:45:25 MSK 2026
;; MSG SIZE  rcvd: 89

```

Тест отключание балансировщика 

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49459
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.41

;; Query time: 8 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:50:33 MSK 2026
;; MSG SIZE  rcvd: 73

```

```bash
deploy@lab04-load-balancer-2:~$ sudo systemctl stop angie

```

Включение 

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1361
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.41
load_balancer.service.consul. 0	IN	A	192.168.70.42

;; Query time: 6 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:53:10 MSK 2026
;; MSG SIZE  rcvd: 89

```

Template:

```bash

```


```bash
deploy@lab04-backend3:~$ sudo systemctl stop nginx

```

``` bash
upstream backend {
    zone backend 1m;

    server  10.10.20.43:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.44:8080 max_fails=3 fail_timeout=30s;

}

```

```bash
deploy@lab04-backend3:~$ sudo systemctl start nginx

```

```bash
upstream backend {
    zone backend 1m;

    server  10.10.20.43:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.44:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.45:8080 max_fails=3 fail_timeout=30s;

}


```

```bash


angie: the configuration file /etc/angie/angie.conf syntax is ok
angie: configuration file /etc/angie/angie.conf test is successful
angie: the configuration file /etc/angie/angie.conf syntax is ok
angie: configuration file /etc/angie/angie.conf test is successful

```