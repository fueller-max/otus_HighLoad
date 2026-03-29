
# Настройка централизованного сбора логов в кластер Elasticsearch

## Цель

1. Развернуть отказоустойчивый кластер Elasticsearch;
2. Централизованно собирать логи с серверов проекта;
3. Обеспечить визуализацию логов для мониторинга и диагностики;

## Задание

1. Разверните кластер Elasticsearch из минимум трёх узлов.
2. Обеспечьте корректную настройку параметров discovery.seed_hosts, cluster.initial_master_nodes и сетевого взаимодействия между узлами.
3. Выберите и настройте инструмент сбора логов (например, Filebeat или Logstash). Установите его на веб-серверы, базы данных и балансировщики.
4. Настройте отправку логов в Elasticsearch.
5. Настройте шаблоны индексов и правила для обработки логов.
6. Проверьте, что логи успешно поступают в Elasticsearch и отображаются.
7. (Опционально) Подключите Kibana для визуализации логов и настройки дешбордов.

## Решение

В данной работе произведем развертывание стека ELK, состоящего из 5 узлов:

* 3 ВМ - кластер Elasticsearch
* 1 ВМ - визуализация Kibana
* 1 ВМ - приемник и обработчик логов Logstash

### 1. Развертывание и настройка Elasticsearch из трёх узлов

Выполним установку и настройку кластера Elasticsearch на трех узлах. Для установки будем использовать зеркало Яндекса.

<details>
  <summary>install.yaml</summary>

  ```bash
  - name: Add Elastic Search Repo from Yandex
  ansible.builtin.shell: |
         echo "deb [trusted=yes] {{ es_yandex_mirror }} stable main" | sudo tee /etc/apt/sources.list.d/elastic-{{ es_version }}.x.list
  tags: always       

- name: Update repo indexes  
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 0  
  tags: always    

- name: Install Elastic Search
  ansible.builtin.apt:
    name: 
         - elasticsearch  
  tags: always  
  ```

</details>

Далее выполним настройку и запуск кластера Elasticsearch:

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

- name: Render JVM options for es
  ansible.builtin.template:
      src:  templates/jvm.options.j2       
      dest: /etc/elasticsearch/jvm.options  
      owner: root                           
      group: elasticsearch                           
      mode: '0644'      
  tags: [always] 

- name: Render config for es for initial start. First node only
  vars:
      initial_master_nodes: true
  ansible.builtin.template:
      src:  templates/elasticsearch.yml.j2       
      dest: /etc/elasticsearch/elasticsearch.yml  
      owner: root                           
      group: elasticsearch                           
      mode: '0644'      
  tags: [always]  
  run_once: true    
  delegate_to:  "{{ groups.es | first }}" 

- name: Start and enable es. First node only
  ansible.builtin.systemd:
    name: elasticsearch
    state: started
    enabled: yes 
  run_once: true    
  delegate_to:  "{{ groups.es | first }}" 
  tags: [always]

- name: Render config for es for normal operation. All nodes 
  vars:
      initial_master_nodes: false
  ansible.builtin.template:
      src:  templates/elasticsearch.yml.j2       
      dest: /etc/elasticsearch/elasticsearch.yml  
      owner: root                           
      group: elasticsearch                           
      mode: '0644'      
  tags: [always]  

- name: Reset elastic password 
  ansible.builtin.shell:  '/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s -a'
  register: elastic_pass
  run_once: true    
  delegate_to:  "{{ groups.es | first }}"
  tags: [always] 

- name: Print elastic password 
  ansible.builtin.debug:
    var: elastic_pass.stdout
  run_once: true    
  delegate_to:  "{{ groups.es | first }}" 
  tags: [always] 
 
- name: Generate enrollment token for additional nodes to connect to the cluster  
  ansible.builtin.shell: |
     /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node
  register: enroll_token
  run_once: true    
  delegate_to:  "{{ groups.es | first }}"
  tags: [always] 

- name: Ensure enrollment token was generated
  assert:
    that: enroll_token is defined and enroll_token.rc == 0
    fail_msg: "Enrollment token generation failed"
    success_msg: "Enrollment token generated successfully"
  run_once: true    
  delegate_to:  "{{ groups.es | first }}"  
  tags: [always] 

- name: Print enrollment token
  ansible.builtin.debug:
    var: enroll_token.stdout
  run_once: true    
  delegate_to:  "{{ groups.es | first }}" 
  tags: [always]   

- name: Reconfigure other nodes using enrollment-token
  ansible.builtin.shell: |
    echo "y" | /usr/share/elasticsearch/bin/elasticsearch-reconfigure-node --enrollment-token {{ enroll_token.stdout }} --silent
  when: inventory_hostname != groups.es | first
  tags: [always] 

- name: Start and enable es on the enrolled nodes 
  ansible.builtin.systemd:
    name: elasticsearch
    state: started
    enabled: yes 
  delegate_to:  "{{ groups.es[1] }}"
  run_once: true
  tags: [always]  

- name: Start and enable es on the enrolled nodes 
  ansible.builtin.systemd:
    name: elasticsearch
    state: started
    enabled: yes 
  delegate_to:  "{{ groups.es[2] }}"
  run_once: true
  tags: [always]  

- name: Setup Discovery seed host in es config
  ansible.builtin.lineinfile:
    path: /etc/elasticsearch/elasticsearch.yml
    regexp: 'discovery.seed_hosts:.*' 
    line:  ""
  tags: [always]

- name: Setup Discovery seed host in es config
  ansible.builtin.lineinfile:
    path: /etc/elasticsearch/elasticsearch.yml
    regexp: '.discovery.seed_hosts:.*' 
    line:  "discovery.seed_hosts: [\"{{ hostvars[groups.es[0]]['cluster_net_addr']}}\", \"{{ hostvars[groups.es[1]]['cluster_net_addr']}}\", \"{{ hostvars[groups.es[2]]['cluster_net_addr']}}\"]" 
  tags: [always]

  ```

</details>

Приведенный плейбук настройки включает в себя:

1. Настройку DNS для резолвинга имен нод
2. Настройку параметров JVM для ES
3. Настройка конфига для первой ноды ее запуск -> инициализация однокластерной системы
4. Настройка рабочего конфига для всех нод
5. Генерация токена для подключения остальных нод к кластеру
6. Введние нод в кластер
7. Добавление в конфиг seed_hosts для нормального рестара кластера в случае отключения всех нод

В результате получаем рабочий кластер ES, состоящий из трех нод. Проверим его состояние:

```bash
 deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-*********** https://localhost:9200/_cat/nodes
10.10.50.51 61 94 13 0.18 0.25 0.10 cdfhilmrstw * lab07-es-node1
10.10.50.52 26 95 10 0.25 0.23 0.11 cdfhilmrstw - lab07-es-node2
10.10.50.53 23 96 13 0.25 0.18 0.08 cdfhilmrstw - lab07-es-node3
```

Видим, что кластер собран - все три ноды присутствуют, мастером является 1-ая нода - как и должно быть при первичном развертывании кластера.

Проверим работоспособность кластера выключив мастер-ноду и включив обратно. Нода вернулась в кластер, при этом мастер-маркер перешел на 3-ю ноду:

```bash
deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-************ https://localhost:9200/_cat/nodes
10.10.50.51 31 52  7 0.05 0.09 0.04 cdfhilmrstw - lab07-es-node1
10.10.50.53 25 50 20 0.41 0.14 0.05 cdfhilmrstw - lab07-es-node3
10.10.50.52 31 66 14 0.23 0.14 0.05 cdfhilmrstw * lab07-es-node2
```

Таким образом, рабочий кластер ES развернут и находится в рабочем состоянии.

### 2. Равертывание и настройка Kibana (визулизация)

По аналогии устаналиваем Kibana из зеркала Yandex:

<details>
  <summary>install.yaml</summary>
  
  ```bash
  - name: Add Elastic Search Repo from Yandex
  ansible.builtin.shell: |
         echo "deb [trusted=yes] {{ es_yandex_mirror }} stable main" | sudo tee /etc/apt/sources.list.d/elastic-{{ es_version }}.x.list
  tags: always       

- name: Update repo indexes  
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 0  
  tags: always    

- name: Install Kibana
  ansible.builtin.apt:
    name: 
         - kibana 
  tags: always
 
 ```

 </details>  

Проведем первичную настройку и запуск Kibana c запросм токенов для подключения у ноды кластера ES:

<details>
  <summary>provision.yaml</summary>

  ```bash
  - name: Render Kibana config 
  vars:
      no_nginx: true
  ansible.builtin.template:
      src:  templates/kibana.yml.j2       
      dest: /etc/kibana/kibana.yml  
      owner: kibana                           
      group: kibana                           
      mode: '0644'      
  tags: [always]  

- name: Generate enrollment token for Kibana on es cluster node
  ansible.builtin.shell: |
     /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
  register: enroll_token_kibana
  run_once: true    
  delegate_to:  "{{ groups.es | first }}"
  tags: [always] 

- name: Ensure enrollment token was generated
  assert:
    that: enroll_token_kibana is defined and enroll_token_kibana.rc == 0
    fail_msg: "Enrollment token generation failed"
    success_msg: "Enrollment token generated successfully"
  run_once: true    
  delegate_to:  "{{ groups.es | first }}"  
  tags: [always] 

- name: Print enrollment token
  ansible.builtin.debug:
    var: enroll_token_kibana.stdout
  run_once: true    
  delegate_to:  "{{ groups.es | first }}" 
  tags: [always]


- name: Start and enable Kibana 
  ansible.builtin.systemd:
    name: kibana
    state: started
    enabled: yes 
  tags: [always]

- name: Check if kibana port 5601 has been started( Wait for 60 seconds)
  ansible.builtin.wait_for:
    port: 5601
    host: 127.0.0.1 
    state: started 
    delay: 15
    timeout: 60
  ignore_errors: yes  
  tags: [always]

- name: Generate verification code 
  ansible.builtin.shell: |
     /usr/share/kibana/bin/kibana-verification-code
  register: kibana_verification_code
  tags: [always] 

- name: Ensure kibana verification code was generated
  assert:
    that: kibana_verification_code is defined and kibana_verification_code.rc == 0
    fail_msg: "Enrollment token generation failed"
    success_msg: "Enrollment token generated successfully"
  tags: [always] 

- name: Print kibana verification code 
  ansible.builtin.debug:
    var: kibana_verification_code.stdout
  tags: [always]   

```

</details>

После первичного запуска вводим данные в Kibana, дожидаемся ее полного запуска и в Dev консоли проверяем доступность созданного кластера ES:

![](/Lab07_ELK/pics/Basic_Kibana.png)

На данном этапе развертывание Kibana завершено. Стоит отметить, что в данном стенде для упрощения не используется прокси-сервер для Kibana, что рекомендуется делать в production-средах, а обращение к интерфейсу Kibana идет напрямую по порту 5901. В конфигруации playbook предусмотрена установка опции использования прокси (nginx, angie...).

### 3. Равертывание и настройка Logstash

Развернем третий базовый компонент стека ELK - Logstash. Он принимает логи, форматирует их и записывает в ElasticSearch.

Также установим его из зеркала Yandex:

<details>
  <summary>install.yaml</summary>

```bash
- name: Add Elastic Search Repo from Yandex
  ansible.builtin.shell: |
         echo "deb [trusted=yes] {{ es_yandex_mirror }} stable main" | sudo tee /etc/apt/sources.list.d/elastic-{{ es_version }}.x.list
  tags: always       

- name: Update repo indexes  
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 0  
  tags: always    

- name: Install Logstash
  ansible.builtin.apt:
    name: 
         - logstash 
  tags: alway
```

</details>

<details>
  <summary>provision.yaml</summary>
  
  ```bash
   - name: Render Logstash main config 
  ansible.builtin.template:
      src:  templates/logstash.yml.j2       
      dest: /etc/logstash/logstash.yml  
      owner: logstash                           
      group: logstash                           
      mode: '0644'      
  tags: [always]  

- name: Copy config files 
  ansible.builtin.template:
      src: "templates/{{ item }}"
      dest: "/etc/logstash/conf.d/{{ item }}"
      owner: logstash                           
      group: logstash                           
      mode: '0644'
  loop:
      - filter.conf.j2
      - input.conf.j2
      - output.conf.j2
  tags: [always]   

- name: Fetch cert from es node host to control node
  fetch:
    src: /etc/elasticsearch/certs/http_ca.crt
    dest: /tmp/fetched_files/
    flat: no
  delegate_to: "{{ groups.es | first }}"   
  tags: [always]

- name: Ensure destination directory for certs exists
  ansible.builtin.file:
        path: /etc/logstash/certs/
        state: directory
        owner: logstash  
        group: logstash  
        mode: '0755'          
  tags: [always]

- name: Copy fetched cert to the folder
  copy:
    src: /tmp/fetched_files/{{ inventory_hostname }}/etc/elasticsearch/certs/http_ca.crt
    dest: /etc/logstash/certs/http_ca.crt
    owner: logstash   
    group: logstash   
    mode: '0755'          
  tags: [always]

- name: Start and enable Logstash 
  ansible.builtin.systemd:
    name: logstash
    state: started
    enabled: yes 
  tags: [always]
  
  ```

</details>

Здесь основная настройка заключается в конфигурировании трех файлов конфигруации input.conf, filter.conf, output.conf. Каждый из файлов выполняет свою функцию - прием данных(input), фильтрацию(filter) и запись в es (output). Настройки каждого из файлов приведены ниже:

```bash
## input.conf
input {
  beats {
    port => {{ input_listen_port }}
  }
}
```

```bash
## filter.conf
filter {
 if [type] == "angie_access" {
    grok {
        match => { "message" => "%{IPORHOST:remote_ip} - %{DATA:user} \[%{HTTPDATE:access_time}\] \"%{WORD:http_method} %{DATA:url} HTTP/%{NUMBER:http_version}\" %{NUMBER:response_code} %{NUMBER:body_sent_bytes} \"%{DATA:referrer}\" \"%{DATA:agent}\"" }
    }
  }
  date {
        match => [ "timestamp" , "dd/MMM/YYYY:HH:mm:ss Z" ]
  }
  geoip {
         source => "remote_ip"
         target => "geoip"
         add_tag => [ "nginx-geoip" ]
  }
}

```

```bash
## output.conf

output {
        elasticsearch {
            hosts => ["https://{{ hostvars[groups.es[0]]['cluster_net_addr']}}:9200","https://{{ hostvars[groups.es[1]]['cluster_net_addr']}}:9200", "https://{{ hostvars[groups.es[1]]['cluster_net_addr']}}:9200"]
            index => "%{[host][name]}-%{+YYYY.MM}"
            user => "elastic"
            password => "{{ es_pass }}"
            cacert => "/etc/logstash/certs/http_ca.crt"
        }
}

```

В output секции определяем index c привязкой к hostname. Необходимо для того, чтобы для каждой ноды создавался отдельный индекс в базе для лучшей организации/поиска, а также лучшей производительности самой es.

На этом разворачивание стека ELK завершено и теперь можно приступить к настройке и запуску непосредственно сборщиков логов на нодах.

### 4. Равертывание и настройка Filebeat. Проверка работы логгирования

Разворачивание сборщиков логов(Filebeat) выполним на нодах балансировщиков и бекендов. На балансировщиках будем собирать логи с файлов access. А на бекендах - системный лог.

Добавим роль "filebeat-log" к предыдущей лабе 4.

Также выполним установку Filebeat из зеркала Яндекса и запуск сервиса. Установка полностью аналогична приведенной выше.

Основной настройкой явялется определение filebeat.inputs в файле filebeat.yml где указываем что, откуда и куда писать:

```bash
filebeat.inputs:
{% for logset in filebeat_logset %}

- type: log
  enabled: true
  paths:
      - {{ logset.log_file_path }}
  fields:
    type: "{{ logset.type }}"
    log_source: {{ inventory_hostname }}
  fields_under_root: true
  scan_frequency: 5s
  
{% endfor %}

output.logstash:
  hosts: ["{{logstash_host}}"]
```

Переменные для балансировщиков выглядят следующим образом:

```bash
filebeat_logset:
   - name: access
     log_file_path: "/var/log/angie/host.access.log"
     type: "angie_access"
   - name: error
     log_file_path: "/var/log/angie/error.log"
     type: "angie_error"

logstash_host: "192.168.70.65:5044"
```

Определяем файл, тип (метка) и хост Logstash куда отправлять логи.

После настройки Filebeat проверяем, что логи идут в ElasticSearch:


```bash
deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-****** https://localhost:9200/_cat/indices?v
health status index                                                              uuid                   pri rep docs.count docs.deleted store.size pri.store.size dataset.size
****
green  open   .internal.alerts-observability.logs.alerts-default-000001          cgfzPy0TR3ioKsIiGzoR7A   1   1          0            0       498b           249b         249b
green  open   lab04-backend2-2026.03                                             tAw2O392RQKt2VF1yMQyxA   1   1       7649            0        7mb          3.5mb        3.5mb
green  open   lab04-backend3-2026.03                                             MeKVBSzYRbaF4BOq-BD58A   1   1       6639            0      6.7mb          3.2mb        3.2mb
****
green  open   lab04-load-balancer-1-2026.03                                      w2h34eb2TeK8ExI_ypFfrA   1   1         24            0    482.2kb        241.1kb      241.1kb
green  open   .internal.alerts-default.alerts-default-000001                     Y6sdBZRLT_mjnTNo-arBmQ   1   1          0            0       498b                   
****
green  open   lab04-backend1-2026.03                                             HgYBDDm7TV6UTEGn-Q_ZhQ   1   1       7324            0      7.5mb          3.5mb        3.5mb

```

Видим, что индексы, соответствующим именам нод, появилсь в базе ES.

И теперь проверим, что логи доступны в интерфейсе Kibana:

![kibana-loadbalancer](/Lab07_ELK/pics/Kibana_load-balancer-1.png)

![kibana-syslog](/Lab07_ELK/pics/Kibana_sys_log_be.png)

Видим, что все настроенные выше логи доступны через Kibana.

### Выводы

В данной работе был рассмотрен вопрос развертывания полноценного ELK стека, с использованием его для сбора логов с нод веб-портала. Был развернут отказоустойчивый кластер ElasticSearch на трех нодах, обработчик логов Logstash и визуализация Kibana - все основные компоненты ELK.
Далее была реализована сборка логов с нод с использованием Filebeat и проверена работа системы по отправке и визуализации логов.
