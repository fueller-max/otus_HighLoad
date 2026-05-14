# Salt: конфигурация на несколько серверов

## Цель

Salt: конфигурация на несколько серверов

## Задание

1. Разверните Salt master.
2. Установите Salt minion на каждый сервер проекта.
3. Настройте управление конфигурацией nginx и iptables через Salt.

## Решение


### 1. Подготовка виртуальных машин

Для работы развернем два виртуальные машины в Proxmox с использованием Terraform. Одна из машин будет выполнять роль Salt-мастера, другая Salt-миниона.

### 2. Установка SaltStack

Для установки и настройки Salt Stack будем использовать официальную документацию Salt Project, доступную по ссылке:
https://docs.saltproject.io/salt/install-guide/en/latest/index.html

#### 2.1.1 Установка Salt Master

Обновляем ключи/репозитории:

```bash
# Ensure keyrings dir exists
mkdir -m 755 -p /etc/apt/keyrings
# Download public key
curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | gpg --dearmor | sudo tee /etc/apt/keyrings/salt-archive-keyring.pgp > /dev/null
# Create apt repo target configuration
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee /etc/apt/sources.list.d/salt.sources
```

Выбираем актуальную на сегодня LTS версию 3006: 

```bash
sudo cat /etc/apt/preferences.d/salt-pin-1001
Package: salt-*
Pin: version 3006.*
Pin-Priority: 1001
```

Выполняем установку Salt - master:

```bash
deploy@lab11-salt-master:~$ sudo apt update
deploy@lab11-salt-master:~$ sudo apt-get install salt-master

deploy@lab11-salt-master:~$ salt-master --version
salt-master 3006.24 (Sulfur)
```

Запускаем Salt - master:

```bash
deploy@lab11-salt-master:~$ sudo systemctl enable salt-master && sudo systemctl start salt-master
```

#### 2.1.2 Установка Salt Minion

Установка аналогична установке Salt - master. После обновления репозиториев выполняем установку Salt - minion

```bash
deploy@lab11-salt-minion:~$ sudo apt update
deploy@lab11-salt-minion:~$ sudo apt-get install salt-minion

deploy@lab11-salt-minion:~$ salt-minion --version
salt-minion 3006.24 (Sulfur)
```

```bash
deploy@lab11-salt-minion:~$ sudo systemctl enable salt-minion && sudo systemctl start salt-minion

```

### 2.2 Post-config 

После установки делаем базовую пост-конфигурацию Salt stack 

#### 2.2.1 Salt Master

В файле network.conf настраиваем интерфейс, на котором будет Salt мастер будет прослушивать.

```bash
/etc/salt/master.d/network.conf

# The network interface to bind to
interface: 192.168.70.110
```
Проверяем, что Salt мастер запустился и слушает на стандартных Salt-стека портах 4505/4506:

```bash
deploy@lab11-salt-master:~$ ss -tulpn
Netid        State         Recv-Q        Send-Q                Local Address:Port               Peer Address:Port        Process        
                    
tcp          LISTEN        0             1000                 192.168.70.110:4506                    0.0.0.0:*                          
tcp          LISTEN        0             1000                 192.168.70.110:4505                    0.0.0.0:*                           
```

#### 2.2.2 Salt Minion

В файле master.conf настраиваем IP адрес мастера. По дефолту, минионы используют DNS для обращения к мастеру, однако можем также задать непосредственно IP адрес.  

```bash
/etc/salt/minion.d/master.conf

master: 192.168.70.110
```

Задаем ID нашего миниона:

```bash
/etc/salt/minion.d/id.conf
id: rebel_1
```

#### 2.3 Акцептирование RSA ключа

После того, как ноды настроены, необходимо провести процедуру акцептирования RSA -ключа миниона на мастере. Без этого шага невозможен обмен данными между мастером и минионом.

Делаем запрос на мастере текущего состояния ключей: 

```bash
deploy@lab11-salt-master:~$ sudo salt-key
Accepted Keys:
Denied Keys:
Unaccepted Keys:
rebel_1
Rejected Keys:
```
Видим, что наш минион "rebel_1" был определен мастером, однако ключ пока не акцептирован.

Делаем акцептирование ключа:

```bash
deploy@lab11-salt-master:~$ sudo salt-key -a rebel_1
The following keys are going to be accepted:
Unaccepted Keys:
rebel_1
Proceed? [n/Y] y
Key for minion rebel_1 accepted.
```
Также возможен вариант автоматического акцептирования ключей минионов с использованием настройки ав конфигурации мастера auto*accept: True. 

### 2.4 Верификация установки и работы

После акцептирования ключей  можно проверить работоспособность Salt Stack путем выполнения некоторых команд.

На мастере сделаем запрос версии Salt минионе:

```bash
deploy@lab11-salt-master:~$ sudo salt '*' test.version
rebel_1:
    3006.24
```
Видим, что актуальная версия отобразилась.

Проверим выполнение команды с мастера на минионе:

```bash
deploy@lab11-salt-master:~$ sudo salt '*' cmd.run 'hostname'
rebel_1:
    lab11-salt-minion
```
Видим, что команда успешно выполнилась и было возвращено имя хоста миниона


На данном этапе установка и конфигурация Salt Stack в рамках системы  двухнодовой схемы Master <-> Minion завершена и можно приступать к работе по управлению конфигурацией.

### 3. Настройка управления конфигурацией nginx и iptables через Salt

Проверим сбор фактов(Grains),например,Ю запросом на тип ОС

```bash
deploy@lab11-salt-master:~$ sudo salt '*' grains.item os
rebel_1:
    ----------
    os:
        Ubuntu
``` 
Grains — это статические данные, которые описывают свойства миньонов. Эти данные автоматом собираются Salt.

Создадим проект на мастере для управления конфигурацией миниона, используя типовую структуру проекта Salt:

```bash
deploy@lab11-salt-master:/srv$ tree
.
├── pillar
│   ├── rebel_1_firewall.sls
│   └── top.sls
└── salt
    ├── firewall
    │   ├── init.sls
    │   └── iptables.rules.jinja
    ├── nginx
    │   ├── init.sls
    │   └── nginx.conf.jinja
    └── top.sls

```

В данном проекте будут использованы два состояния nginx и firewall, каждое из которых содержит:
 1. Файл top.sls, у котором описывается само состояние и необходимые действия 
 2. Темплейт-файл .jinja, в котором содержаться конфигурации сервисов 

Настройки состояния Nginx:

```bash
#/srv/salt/nginx/init.sls

nginx:
  pkg.installed:
    - name: nginx

nginx_config:
  file.managed:
    - name: /etc/nginx/nginx.conf
    - source: salt://nginx/nginx.conf.jinja
    - template: jinja
    - context:
        port: 8080  # dynamic port
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: nginx

nginx_service:
  service.running:
    - name: nginx
    - enable: True
    - watch:
      - file: nginx_config
```

В данном состоянии описываем установку пакета Nginx, шаблонизацию его конфигурации (/nginx.conf) и запуск/перезапуск сервиса, в т.ч. после изменения конфигурации.

Сам nginx.conf представлен ниже. В данном случае выполняем динамическое изменение номера порта ("{{ port }}"), на котором слушает Nginx:

```bash
#srv/salt/nginx/nginx.conf.jinja

user  www-data;
worker_processes  auto;
error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Includes site-specific configs from conf.d
    include /etc/nginx/conf.d/*.conf;

    server {
        listen {{ port }} default_server;
        server_name  localhost;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
    }
}

```

Настройки состояния Firewall:

```bash
#/srv/salt/firewall/init.sls

iptables_persistent:
  pkg.installed:
    - name: iptables-persistent

firewall_dir:
  file.directory:
    - name: /etc/iptables
    - user: root
    - group: root
    - mode: 755

firewall_rules:
  file.managed:
    - name: /etc/iptables/rules.v4
    - source: salt://firewall/iptables.rules.jinja
    - template: jinja
    - context:
        allowed_ports: {{ pillar['firewall']['allowed_ports'] | default([80, 443]) }}
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: firewall_dir

apply_firewall:
  cmd.run:
    - name: |
        iptables-restore < /etc/iptables/rules.v4
        netfilter-persistent save
    - unless: iptables-restore -t < /etc/iptables/rules.v4
    - watch:
      - file: firewall_rules
    - require:
      - file: firewall_rules
      - pkg: iptables_persistent
```

Требуем установки iptables-persistent для сохранения правил файрвола, выполняем шаблонизацию правил и запускаем команду применения/сохранения правил.

Правила iptables. Закрываем доступ в цепи INPUT за исключением ssh и порта nginx.

```bash
#/srv/salt/firewall/iptables.rules.jinja

# Generated by SaltStack - DO NOT EDIT
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (critical for remote access)
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Salt Master communication
-A INPUT -p tcp --dport 4505 -j ACCEPT  
-A INPUT -p tcp --dport 4506 -j ACCEPT 

# Dynamic allowed ports
{% for port in allowed_ports %}
-A INPUT -p tcp --dport {{ port }} -j ACCEPT
{% endfor %}

# Log and drop everything else
-A INPUT -j LOG --log-prefix "FIREWALL-DROPPED: "
-A INPUT -j DROP

COMMIT

```
Для состояния Firewall будем также использовать Pillar. Pillar - это данные, которые генерируются мастером и передаются миниону, где они могут использоваться в качестве конфигурационных данных

Настройки Pillar (данные) для модуля Firewall:

```bash
#/srv/pillar/rebel_1_firewall.sls

firewall:
  allowed_ports:
    - 8080  # nginx port
```
В качестве Pillar передадим номер порта, на котором работает nginx. В последствии данный Pillar будет использоваться в конфигурации файрвола.


```bash
#srv/pillar/top.sls
base:
  'rebel_1':
    - rebel_1_firewall
```
```bash
deploy@lab11-salt-master:/srv/pillar$ sudo salt '*' saltutil.refresh_pillar
rebel_1:
    True

```

В проекте в top.sls верхнего уровня прописываем два созданных состояния для нашего миниона:

```bash
#/srv/salt/top.sls

base:
  'rebel_1':
    - nginx
    - firewall
```

И запускаем команду state.apply для применения данного состояния:

```bash
deploy@lab11-salt-master:/srv/pillar$ sudo salt 'rebel_1' state.apply
rebel_1:
----------
          ID: nginx
    Function: pkg.installed
      Result: True
     Comment: All specified packages are already installed
     Started: 17:03:40.122127
    Duration: 21.657 ms
     Changes:   
----------
          ID: nginx_config
    Function: file.managed
        Name: /etc/nginx/nginx.conf
      Result: True
     Comment: The file /etc/nginx/nginx.conf is in the correct state
     Started: 17:03:40.144907
    Duration: 11.67 ms
     Changes:   
----------
          ID: nginx_service
    Function: service.running
        Name: nginx
      Result: True
     Comment: The service nginx is already running
     Started: 17:03:40.157326
    Duration: 23.381 ms
     Changes:   
----------
          ID: iptables_persistent
    Function: pkg.installed
        Name: iptables-persistent
      Result: True
     Comment: All specified packages are already installed
     Started: 17:03:40.180789
    Duration: 6.273 ms
     Changes:   
----------
          ID: firewall_dir
    Function: file.directory
        Name: /etc/iptables
      Result: True
     Comment: The directory /etc/iptables is in the correct state
     Started: 17:03:40.187121
    Duration: 0.574 ms
     Changes:   
----------
          ID: firewall_rules
    Function: file.managed
        Name: /etc/iptables/rules.v4
      Result: True
     Comment: The file /etc/iptables/rules.v4 is in the correct state
     Started: 17:03:40.187886
    Duration: 11.867 ms
     Changes:   
----------
          ID: apply_firewall
    Function: cmd.run
        Name: iptables-restore < /etc/iptables/rules.v4
netfilter-persistent save

      Result: True
     Comment: unless condition is true
     Started: 17:03:40.200582
    Duration: 275.008 ms
     Changes:   

Summary for rebel_1
------------
Succeeded: 7
Failed:    0
------------
Total states run:     7
Total run time: 350.430 ms
```


Проверка работы:

```bash
deploy@lab11-salt-minion:~$ sudo iptables -L -v -n
Chain INPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   52  4752 ACCEPT     0    --  lo     *       0.0.0.0/0            0.0.0.0/0           
 2640  272K ACCEPT     0    --  *      *       0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    2   120 ACCEPT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:22
    0     0 ACCEPT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:4505
    0     0 ACCEPT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:4506
    1    60 ACCEPT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080
  136 79288 LOG        0    --  *      *       0.0.0.0/0            0.0.0.0/0            LOG flags 0 level 4 prefix "FIREWALL-DROPPED: "
  136 79288 DROP       0    --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 2871 packets, 393K bytes)
 pkts bytes target     prot opt in     out     source               destination 
```

```bash
deploy@lab11-salt-minion:~$ sudo systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-05-08 16:42:27 UTC; 23min ago
       Docs: man:nginx(8)
    Process: 670 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 721 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 725 (nginx)
      Tasks: 3 (limit: 2315)
     Memory: 3.9M (peak: 4.1M)
        CPU: 9ms
     CGroup: /system.slice/nginx.service
             ├─725 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─726 "nginx: worker process"
             └─727 "nginx: worker process"

May 08 16:42:26 lab11-salt-minion systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
May 08 16:42:27 lab11-salt-minion systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

```

![](/Lab11_Salt/pics/Nginx_minion.png)

Видим, что наши состояния успешно отработали - пакет nginx установился, правила файрвола применились, nginx доступен на порту 8080.



### 4. Возможности настройки управления конфигурацией с использованием  pull c миниона

Важной особенностью Salt является возможность инициирования запроса конфигурации от ведомого узла, т.е миниона. Минион сам может запросить актуальную конфигурацию с мастера с использованием команды salt-call

Pull c миниона:

```bash
deploy@lab11-salt-minion:~$ sudo salt-call state.apply

local:
----------
          ID: nginx
    Function: pkg.installed
      Result: True
     Comment: All specified packages are already installed
     Started: 14:50:28.846475
    Duration: 21.196 ms
     Changes:   
----------
          ID: nginx_config
    Function: file.managed
        Name: /etc/nginx/nginx.conf
      Result: True
     Comment: File /etc/nginx/nginx.conf is in the correct state
     Started: 14:50:28.880754
    Duration: 17.919 ms
     Changes:   
----------
          ID: nginx_service
    Function: service.running
        Name: nginx
      Result: True
     Comment: The service nginx is already running
     Started: 14:50:28.911638
    Duration: 23.263 ms
     Changes:   
----------
          ID: iptables_persistent
    Function: pkg.installed
        Name: iptables-persistent
      Result: True
     Comment: All specified packages are already installed
     Started: 14:50:28.934979
    Duration: 6.247 ms
     Changes:   
----------
          ID: firewall_dir
    Function: file.directory
        Name: /etc/iptables
      Result: True
     Comment: The directory /etc/iptables is in the correct state
     Started: 14:50:28.941285
    Duration: 0.577 ms
     Changes:   
----------
          ID: firewall_rules
    Function: file.managed
        Name: /etc/iptables/rules.v4
      Result: True
     Comment: File /etc/iptables/rules.v4 is in the correct state
     Started: 14:50:28.942048
    Duration: 139.242 ms
     Changes:   
----------
          ID: apply_firewall
    Function: cmd.run
        Name: iptables-restore < /etc/iptables/rules.v4
netfilter-persistent save

      Result: True
     Comment: unless condition is true
     Started: 14:50:29.097818
    Duration: 576.391 ms
     Changes:   

Summary for local
------------
Succeeded: 7
Failed:    0
------------
Total states run:     7
Total run time: 784.835 ms
```

Видим, что вывод абсолютно аналогичен тому, что бы было если запуск конфигурации проводился с самого мастера.

Также есть возможность автоматизации процесса заданием шедулера, который будет выполнять запросы конфигурации к мастеру через определенные промежутки времени: 

Автоматический пул

```bash
#/etc/salt/minion.d/_schedule.conf
schedule:
  __mine_interval: {enabled: true, function: mine.update, jid_include: true, maxrunning: 2,
    minutes: 60, return_job: false, run_on_start: true}
  pull_highstate: {function: state.apply, minutes: 30, splay: 3}
```

```bash
deploy@lab11-salt-minion:~$ sudo salt-call schedule.list
local:
    schedule:
      pull_highstate:
        enabled: true
        function: state.apply
        minutes: 30
        name: pull_highstate
        saved: true
        splay: 3
```

Изменив конфигурацию на мастере для nginx (порт 8080 -> 8081), но не запуская apply на самом мастере, минион получил и обновил конфигурацию самостоятельно: 

```bash
deploy@lab11-salt-minion:~$ ss -tulpn
Netid        State         Recv-Q        Send-Q               Local Address:Port                Peer Address:Port        Process        
udp          UNCONN        0             0                       127.0.0.54:53                       0.0.0.0:*                          
udp          UNCONN        0             0                    127.0.0.53%lo:53                       0.0.0.0:*                          
tcp          LISTEN        0             4096                       0.0.0.0:22                       0.0.0.0:*                          
tcp          LISTEN        0             4096                 127.0.0.53%lo:53                       0.0.0.0:*                          
tcp          LISTEN        0             511                        0.0.0.0:8081                     0.0.0.0:*                          
tcp          LISTEN        0             4096                    127.0.0.54:53                       0.0.0.0:*                          
tcp          LISTEN        0             4096                          [::]:22                          [::]:*  
```

Выводы:

В данной работе было выполнен тестовый запуск Salt Stack в минималистичном конфиге для демонстрации возможностей системы. Важной особенностью системы по сравнению с Ansible является использование отдельного протокола для обмена данными мастер - минион.
Это дает, во-первых, увеличение скорости работы (что важно при большом количестве управляемых нод), а также имеет очень важное преимущество в виде возможности миниона самостоятельно вытягивать состояние из мастера. Это может быть полезно в ряде случаев, в т.ч. при использовании схем, где управляемые ноды стоят за NAT или имеют жесткие правила файрвола.