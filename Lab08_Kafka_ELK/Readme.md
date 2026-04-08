
# Очередь логов: Kafka между logstash и Elasticsearch

## Цель

1. Настроить сбор логов с веб-портала, реализованного ранее;
2. Использовать Kafka как промежуточную очередь между logstash и Elasticsearch;

Это задание моделирует реальный сценарий в продакшене: логирование микросервисов и системных компонентов с использованием брокера сообщений. Такой подход повышает отказоустойчивость, масштабируемость и позволяет централизованно управлять логами.

## Задание

1. Разверните Kafka и ELK в кластерном режиме.
2. Создайте два топика — nginx и wordpress, каждый с 2 партициями и 2 репликами.
3. Установите на каждой ноде по одному агенту на выбор: Filebeat, Fluentd или Vector.
4. Настройте сбор логов от nginx и wordpress и отправляйте их в соответствующие топики Kafka.
5. Разверните стек ELK (Elasticsearch, Logstash, Kibana) на одной ноде.
6. Настройте Logstash для чтения данных из Kafka и записи в два отдельных индекса.
7. Создайте index patterns в Kibana и убедитесь, что логи корректно отображаются.
8. Разверните Kafka и ELK в кластерном режиме.


## Решение

В данном задании развернем стек Kafka + ELK, где Kafka будет выполнять промежуточное звено между Logstash(чтение из топиков Kafka) и сборщиками логов Filebeats(запись логов в топики Kafka)

Общая схема представлена на рисунке

![](/Lab08_Kafka_ELK/pics/Kafka_ELK%20_infra.jpg)

ElasticSearch развернем сразу в кластерном режиме (используя существующие плейбуки с прошлой работы), также развернем Kafka в кластерном режиме на трех нодах. 

Будем использовать Kafka актуальной версии 4.2.0 в режиме работы с кластерным менеджера KRaft (не Zookeeper как указано на рисунке), т.к. KRaft - единственный доступный менеджер кластера для Kafka современных версий(начиная с 4.х.х).

### 1. Разворачиваем кластер Kafka

Развернем кластер Kafka, состоящим из трех нод.

Плейбук для установки Kafka представлен ниже:

<details>
  <summary>install.yaml</summary>
  
  ```bash
  - name: Install OpenJDK of requried version
  ansible.builtin.apt:
    name: openjdk-"{{ java_version }}"-jdk
    state: present
    update_cache: yes
  tags: always  

- name: Ensure group "kafka" exists
  ansible.builtin.group:
    name: kafka
    state: present
  tags: always

- name: Create user "kafka"  
  ansible.builtin.user:
    name: kafka
    shell: /bin/bash
    create_home: no
  tags: always 

- name: Create a directory for Kafka
  ansible.builtin.file:
    path: /opt/kafka
    state: directory
    owner: kafka
    group: kafka
    mode: '770'
  tags: always   

- name: Download and unpack Kafka
  ansible.builtin.shell: |
    cd /tmp
    wget https://downloads.apache.org/kafka/"{{ kafka_ver }}"/kafka_2.13-"{{ kafka_ver }}".tgz
    tar -xzf kafka_2.13-"{{ kafka_ver }}".tgz
    mv kafka_2.13-"{{ kafka_ver }}"/* /opt/kafka
    chown -R kafka:kafka /opt/kafka
  tags: [always]   

  ```
</details>  

Устанавливаем JDK актуальной версии (мин. 17), скачиваем пакет файлов Kafka, распаковываем их в рабочую директорию Kafka.

Установка и настройка Kafka:


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

- name: Create a directory for data
  ansible.builtin.file:
    path: /var/lib/kafka-logs
    state: directory
    owner: kafka
    group: kafka
    mode: '770'
  tags: always  

- name: Create a directory for logs
  ansible.builtin.file:
    path: /var/log/kafka
    state: directory
    owner: kafka
    group: kafka
    mode: '770'
  tags: always 

- name: Generate cluster ID 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh random-uuid
  register: cluster_ID
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"
  tags: [always] 

- name: Ensure cluster ID was generated
  assert:
    that: cluster_ID is defined and cluster_ID.rc == 0
    fail_msg: "Cluster_ID generation failed"
    success_msg: "cluster_ID generated successfully"
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"  
  tags: [always] 

- name: Print cluster ID 
  ansible.builtin.debug:
    var: cluster_ID.stdout
  run_once: true    
  delegate_to:  "{{ groups.kafka  | first }}" 
  tags: [always]  

- name: Generate CONTROLLER 1 UUID 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh random-uuid
  register: controller_1_uuid
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"
  tags: [always]  

- name: Generate CONTROLLER 2 UUID 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh random-uuid
  register: controller_2_uuid
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"
  tags: [always] 

- name: Generate CONTROLLER 3 UUID 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh random-uuid
  register: controller_3_uuid
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"
  tags: [always]  

- name: Render server.properties
  ansible.builtin.template:
      src:  templates/server.properties.j2     
      dest: /opt/kafka/config/server.properties 
      owner: kafka                          
      group: kafka                           
      mode: '0644'      
  tags: [always] 

- name: Bootstrap the first node 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh format --cluster-id "{{ cluster_ID.stdout }}" --initial-controllers \
     "1@{{ hostvars[groups.kafka[0]]['inventory_hostname'] }}:9093:{{ controller_1_uuid.stdout }}, \
     2@{{ hostvars[groups.kafka[1]]['inventory_hostname'] }}:9093:{{ controller_2_uuid.stdout }}, \
     3@{{ hostvars[groups.kafka[2]]['inventory_hostname'] }}:9093:{{ controller_3_uuid.stdout }}" \
     --config /opt/kafka/config/server.properties
  run_once: true    
  delegate_to:  "{{ groups.kafka | first }}"
  tags: [always]  

- name: Bootstrap the second node 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh format --cluster-id "{{ cluster_ID.stdout }}" --initial-controllers \
     "1@{{ hostvars[groups.kafka[0]]['inventory_hostname'] }}:9093:{{ controller_1_uuid.stdout }}, \
     2@{{ hostvars[groups.kafka[1]]['inventory_hostname'] }}:9093:{{ controller_2_uuid.stdout }}, \
     3@{{ hostvars[groups.kafka[2]]['inventory_hostname'] }}:9093:{{ controller_3_uuid.stdout }}" \
     --config /opt/kafka/config/server.properties
  run_once: true    
  delegate_to:  "{{ groups.kafka[1] }}"
  tags: [always]   

- name: Bootstrap the third node 
  ansible.builtin.shell: |
     /opt/kafka/bin/kafka-storage.sh format --cluster-id "{{ cluster_ID.stdout }}" --initial-controllers \
     "1@{{ hostvars[groups.kafka[0]]['inventory_hostname'] }}:9093:{{ controller_1_uuid.stdout }}, \
     2@{{ hostvars[groups.kafka[1]]['inventory_hostname'] }}:9093:{{ controller_2_uuid.stdout }}, \
     3@{{ hostvars[groups.kafka[2]]['inventory_hostname'] }}:9093:{{ controller_3_uuid.stdout }}" \
     --config /opt/kafka/config/server.properties
  run_once: true    
  delegate_to:  "{{ groups.kafka[2] }}"
  tags: [always]    

- name: Set user/group for storage content
  ansible.builtin.shell: |
      sudo chown -R kafka:kafka /var/lib/kafka-logs   
  tags: [always] 

- name: Render kafka systemd unit 
  ansible.builtin.template:
        src: templates/kafka.service.j2
        dest: /etc/systemd/system/kafka.service
  tags: always

- name: Force systemd to reread configs
  ansible.builtin.systemd_service:
    daemon_reload: true
  tags: always

- name: Enable and start kafka service
  ansible.builtin.systemd:
    name: kafka
    state: restarted
    enabled: yes
  register: kafka_service_status
  tags: always  

- name: Render custom health-checking script
  ansible.builtin.template:
      src:  templates/kafka-health-check.j2         
      dest: /opt/kafka/bin/kafka-health-check.sh
      owner: root                           
      group: root                           
      mode: '0770'
  tags: [always]
 
- name: Render custom bulk topic creation script
  ansible.builtin.template:
      src:  templates/create-topics.sh.j2        
      dest: /opt/kafka/bin/create-topics.sh
      owner: root                           
      group: root                           
      mode: '0770'
  tags: [always] 
  ```
</details>


В плейбуке последовательно запускаем каждый инстанс Kafka c использованием скрипта kafka-storage.sh:

```bash
/opt/kafka/bin/kafka-storage.sh format --cluster-id "{{ cluster_ID.stdout }}" --initial-controllers \
     "1@{{ hostvars[groups.kafka[0]]['inventory_hostname'] }}:9093:{{ controller_1_uuid.stdout }}, \
     2@{{ hostvars[groups.kafka[1]]['inventory_hostname'] }}:9093:{{ controller_2_uuid.stdout }}, \
     3@{{ hostvars[groups.kafka[2]]['inventory_hostname'] }}:9093:{{ controller_3_uuid.stdout }}" \
     --config /opt/kafka/config/server.properties

```
Здесь используем подход со статическим заданием контроллеров кластера в момент его запуска. KRaft в общем случае поддерживает и динамическое введение контроллеров в кластер.

Основная часть конфига каждого инстанса Кafka:

```bash
############################# Server Basics #############################

# The role of this server. Setting this puts us in KRaft mode
process.roles=broker,controller

# The node id associated with this instance's roles
node.id= {{ node_id }}

# List of controller endpoints used connect to the controller cluster
controller.quorum.bootstrap.servers={{ hostvars[groups.kafka[0]]['inventory_hostname'] }}:9093,{{ hostvars[groups.kafka[1]]['inventory_hostname'] }}:9093,{{ hostvars[groups.kafka[2]]['inventory_hostname'] }}:9093
```

Каждая нода выполняет две функции: Контроллер и Брокер. В продакш условиях рекомендуется разделять функции(отдельно контроллер, отдельно брокер) для повышения надежности работы(естественно, что общее количество нод кластера кратно увеличится). Но для тестовых условий такое совмещение более чем допустимо.

Для KRaft вводится настройка controller.quorum.bootstrap.servers, замещающая controller.quorum.voters для кластеров на базе ZooKeeper. Controller.quorum.bootstrap.server в целом отвечает за динамический кворум.

После запуска кластера проводим проверку и диагностику его состояния/работы: 

Смотрим состояние метаданных кворума:

```bash
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 10.10.50.80:9092 describe --status
ClusterId:              Vfxwe2wORh6EZOXk82vldA
LeaderId:               2
LeaderEpoch:            1
HighWatermark:          215
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   383
CurrentVoters:          [{"id": 1, "directoryId": "Xi2HjB3JTHuM7MhIr-YqsA", "endpoints": ["CONTROLLER://lab08-kafka-node1:9093"]}, {"id": 2, "directoryId": "GuTv8Uj-QbG8IqU4batIEQ", "endpoints": ["CONTROLLER://lab08-kafka-node2:9093"]}, {"id": 3, "directoryId": "gyMyCwpGQn6lrk3fHqVmsw", "endpoints": ["CONTROLLER://lab08-kafka-node3:9093"]}]
CurrentObservers:       []
```
Видим, что в разделе CurrentVoters присутствуют наши три ноды, что мы и ожидаем - все три ноды участвуют в голосовании кворума и выпадение любой одной ноды не сломает кластер:

При выключении второй ноды лидерство перешло ко третьей (LeaderId: 3):

```bash
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 10.10.50.80:9092 describe --status
ClusterId:              Vfxwe2wORh6EZOXk82vldA
LeaderId:               3
LeaderEpoch:            2
HighWatermark:          362
MaxFollowerLag:         363
MaxFollowerLagTimeMs:   -1
CurrentVoters:          [{"id": 1, "directoryId": "Xi2HjB3JTHuM7MhIr-YqsA", "endpoints": ["CONTROLLER://lab08-kafka-node1:9093"]}, {"id": 2, "directoryId": "GuTv8Uj-QbG8IqU4batIEQ", "endpoints": ["CONTROLLER://lab08-kafka-node2:9093"]}, {"id": 3, "directoryId": "gyMyCwpGQn6lrk3fHqVmsw", "endpoints": ["CONTROLLER://lab08-kafka-node3:9093"]}]
CurrentObservers:       []

```

Дополнительно создадим кастомный скрипт для проверки "здоровья" кластера, включающий в себя проверку доступности кластера и проверку на корректность репликации партиций:

```bash
#!/bin/bash
# kafka-health-check.sh
# Script for Kafka health checking

KAFKA_HOME="/opt/kafka"
BOOTSTRAP_SERVER="{{ inventory_hostname }}:9092"

# Check broker availability
echo "Checking broker availability..."
$KAFKA_HOME/bin/kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_SERVER >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Brokers are accessible"
else
    echo "✗ Brokers are not accessible"
    exit 1
fi

# check under-replicated partitions
echo "Checking under-replicated partitions..."
UNDER_REPLICATED=$($KAFKA_HOME/bin/kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --under-replicated-partitions 2>/dev/null | wc -l)
if [ $UNDER_REPLICATED -eq 0 ]; then
    echo "✓ All partitions are properly replicated"
else
    echo "⚠ Found $UNDER_REPLICATED under-replicated partitions"
fi

echo "Health check completed"
```

```bash
deploy@lab08-kafka-node1:~$ sudo  /opt/kafka/bin/kafka-health-check.sh
Checking broker availability...
✓ Brokers are accessible
Checking under-replicated partitions...
✓ All partitions are properly replicated
Health check completed
```

Также пробуем создать тестовый топик "test-topic", записать и прочитать туда одно сообщение:

```bash
 deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-topics.sh  --create  --topic test-topic  --bootstrap-server 10.10.50.80:9092 --partitions 3 --replication-factor 3
deploy@lab08-kafka-node1:~$ echo "Hello Kafka!" | sudo /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server 10.10.50.80:9092
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --from-beginning --bootstrap-server 10.10.50.80:9092
Hello Kafka!
```
Видим, что отправка и прием сообщений в брокер работает корректно.

### 2. Создаем топики в брокере Kafka

Создадим топики, соответствующим именам нод веб-портала для отправки и чтением в них логов. Для массового создания топиков воспользуемся кастомным скриптом:

```bash
#!/bin/bash
# create-topics.sh
# Bulk topic creation

KAFKA_HOME="/opt/kafka"
BOOTSTRAP_SERVER="{{ inventory_hostname }}:9092"

# List of topics
declare -A TOPICS=(
    ["lab04-load-balancer-1"]="partitions=3,replication-factor=3"
    ["lab04-load-balancer-2"]="partitions=3,replication-factor=3"
    ["lab04-backend1"]="partitions=3,replication-factor=3"
    ["lab04-backend2"]="partitions=3,replication-factor=3"
    ["lab04-backend3"]="partitions=3,replication-factor=3"
    
)

for topic in "${!TOPICS[@]}"; do
    echo "Creating topic: $topic"
    IFS=',' read -ra PARAMS <<< "${TOPICS[$topic]}"
    
    PARTITIONS=""
    REPLICATION=""
    
    for param in "${PARAMS[@]}"; do
        if [[ $param == partitions=* ]]; then
            PARTITIONS="${param#*=}"
        elif [[ $param == replication-factor=* ]]; then
            REPLICATION="${param#*=}"
        fi
    done
    
    $KAFKA_HOME/bin/kafka-topics.sh --create \
        --topic "$topic" \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --partitions $PARTITIONS \
        --replication-factor $REPLICATION \
        --if-not-exists
    
    echo "✓ Topic $topic created"
done
```

Выполняем скрипт с добавлением топиков:

```bash
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/create-topics.sh
Creating topic: lab04-load-balancer-1
Created topic lab04-load-balancer-1.
✓ Topic lab04-load-balancer-1 created
Creating topic: lab04-load-balancer-2
Created topic lab04-load-balancer-2.
✓ Topic lab04-load-balancer-2 created
Creating topic: lab04-backend3
Created topic lab04-backend3.
✓ Topic lab04-backend3 created
Creating topic: lab04-backend2
Created topic lab04-backend2.
✓ Topic lab04-backend2 created
Creating topic: lab04-backend1
Created topic lab04-backend1.
✓ Topic lab04-backend1 created
```
Видим, что скрипт выполнился успешно, однако убедимся, что топики действительно создались в брокере:

```bash
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-topics.sh --list  --bootstrap-server 10.10.50.80:9092
__consumer_offsets
lab04-backend1
lab04-backend2
lab04-backend3
lab04-load-balancer-1
lab04-load-balancer-2
test-topic
```
Видим, что все топики существуют в Kafka. Также проверим описание некоторых из них:

```bash
eploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-topics.sh --describe  --bootstrap-server 10.10.50.80:9092
Topic: lab04-backend2	TopicId: Vp9HewlWQU6xqQpE3GCMag	PartitionCount: 3	ReplicationFactor: 3	Configs: min.insync.replicas=1,segment.bytes=1073741824
	Topic: lab04-backend2	Partition: 0	Leader: 1	Replicas: 1,2,3	Isr: 1,2,3	Elr: 	LastKnownElr: 
	Topic: lab04-backend2	Partition: 1	Leader: 2	Replicas: 2,3,1	Isr: 2,3,1	Elr: 	LastKnownElr: 
	Topic: lab04-backend2	Partition: 2	Leader: 3	Replicas: 3,1,2	Isr: 3,1,2	Elr: 	LastKnownElr: 
Topic: lab04-backend3	TopicId: yHOTkqmJT5ODrZU-oLhLbA	PartitionCount: 3	ReplicationFactor: 3	Configs: min.insync.replicas=1,segment.bytes=1073741824
	Topic: lab04-backend3	Partition: 0	Leader: 3	Replicas: 3,1,2	Isr: 3,1,2	Elr: 	LastKnownElr: 
	Topic: lab04-backend3	Partition: 1	Leader: 1	Replicas: 1,2,3	Isr: 1,2,3	Elr: 	LastKnownElr: 
	Topic: lab04-backend3	Partition: 2	Leader: 2	Replicas: 2,3,1	Isr: 2,3,1	Elr: 	LastKnownElr: 

 *** 
```

Видим, что как и задавалось при создании топиков, каждый из них имеет 3 партиции и 3 репликации. Т.е. данные будут равномерно распределены между тремя нодами кластера (3 партиции), а также защищены от сбоя ноды кластера за счет репликации каждой партиции.


### 2. Разворачиваем стек ELK, интегрируем Kafka. 

В целом, разворачивание стека ELK полностью аналогично тому, что было проделано ранее в работе по ELK. Здесь будут использоваться те же плейбуки. Основной особенностью в данном случае являются настройки Logstash на чтение данных из топиков Kafka (а не прослушивание на порту как было ранее), и настройки Filebeat на отправку данных в топики Kafka(а не напрямую в Logstash как ранее).

Настройка Logstash в разделе inputs выглядит следующим образом:

```bash
input {
  kafka {
    bootstrap_servers => "{{ hostvars[groups.kafka[0]]['cluster_net_addr'] }}:9092,{{ hostvars[groups.kafka[1]]['cluster_net_addr'] }}:9092, {{ hostvars[groups.kafka[2]]['cluster_net_addr'] }}:9092" 
    topics => ["lab04-backend1", "lab04-backend2", "lab04-backend3", "lab04-load-balancer-1", "lab04-load-balancer-2"]
    group_id => "logstash-consumer-group"
    consumer_threads => 3
    codec => "json"
    auto_offset_reset => "latest"
    enable_auto_commit => true
    auto_commit_interval_ms => 5000
    decorate_events => true
    session_timeout_ms => 30000
    heartbeat_interval_ms => 10000
  }
}
```

В качестве input теперь используется kafka, где указываем три ноды нашего созданного кластера Kafka. Также указываем топики, из которых будем читать данные. И некоторые оптимизационные настройки. 

Настройка FileBeat выглядит следующим образом:

```bash
# ================================= Migration ==================================

# This allows to enable 6.7 migration aliases
#migration.6_to_7.enabled: true

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

#output.logstash:
#  hosts: ["{{logstash_host}}"]

output.kafka:
  hosts:
    - "10.10.50.80:9092"
    - "10.10.50.81:9092"
    - "10.10.50.82:9092"
  topic: "{{ inventory_hostname }}"
  required_acks: 1
  compression: gzip
  max_message_bytes: 1000000
```
Добавлена секция output.kafka, также с указанием хостов кластера Kafka. Ставим режим required_acks: 1 - запрашиваем подтверждения записи полученных данных основной партицией, но без ожидания подтверждения реплицирования. Баланс надежности скорости.  


После запуска проверим состояния Kafka на предмет состояние группы, заданной в Logstash ( group_id => "logstash-consumer-group"):

```bash
eploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-consumer-groups.sh   --bootstrap-server lab08-kafka-node3:9092   --group logstash-consumer-group   --describe

GROUP                   TOPIC                 PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID                                     HOST            CLIENT-ID
logstash-consumer-group lab04-backend1        2          0               0               0               logstash-2-cfdc0991-08a6-4af6-809b-5ff82c0c4a74 /10.10.50.55    logstash-2
logstash-consumer-group lab04-backend2        2          0               0               0               logstash-2-cfdc0991-08a6-4af6-809b-5ff82c0c4a74 /10.10.50.55    logstash-2
logstash-consumer-group lab04-backend3        2          0               0               0               logstash-2-cfdc0991-08a6-4af6-809b-5ff82c0c4a74 /10.10.50.55    logstash-2
logstash-consumer-group lab04-load-balancer-1 2          0               0               0               logstash-2-cfdc0991-08a6-4af6-809b-5ff82c0c4a74 /10.10.50.55    logstash-2
logstash-consumer-group lab04-load-balancer-2 2          0               0               0               logstash-2-cfdc0991-08a6-4af6-809b-5ff82c0c4a74 /10.10.50.55    logstash-2
logstash-consumer-group lab04-backend1        0          0               0               0               logstash-0-65e9854f-fb89-466e-b8dc-47c9b242544d /10.10.50.55    logstash-0
logstash-consumer-group lab04-backend2        0          0               0               0               logstash-0-65e9854f-fb89-466e-b8dc-47c9b242544d /10.10.50.55    logstash-0
logstash-consumer-group lab04-backend3        0          0               0               0               logstash-0-65e9854f-fb89-466e-b8dc-47c9b242544d /10.10.50.55    logstash-0
logstash-consumer-group lab04-load-balancer-1 0          0               0               0               logstash-0-65e9854f-fb89-466e-b8dc-47c9b242544d /10.10.50.55    logstash-0
logstash-consumer-group lab04-load-balancer-2 0          0               0               0               logstash-0-65e9854f-fb89-466e-b8dc-47c9b242544d /10.10.50.55    logstash-0
logstash-consumer-group lab04-backend1        1          0               0               0               logstash-1-4cef4518-2df4-4589-a365-3aacbdec2f0b /10.10.50.55    logstash-1
logstash-consumer-group lab04-backend2        1          0               0               0               logstash-1-4cef4518-2df4-4589-a365-3aacbdec2f0b /10.10.50.55    logstash-1
logstash-consumer-group lab04-backend3        1          0               0               0               logstash-1-4cef4518-2df4-4589-a365-3aacbdec2f0b /10.10.50.55    logstash-1
logstash-consumer-group lab04-load-balancer-1 1          0               0               0               logstash-1-4cef4518-2df4-4589-a365-3aacbdec2f0b /10.10.50.55    logstash-1
logstash-consumer-group lab04-load-balancer-2 1          0               0               0               logstash-1-4cef4518-2df4-4589-a365-3aacbdec2f0b /10.10.50.55    logstash-1

```

Видим, что группа обслуживается, запросы приходят с одной ноды ( нода Logstash 10.10.50.55 ) в три воркера (как и было задано в конфиге: consumer_threads => 3). 

Теперь смотрим, появились ли индексы в базе ElasticSearch, что будут говорит о том, что созданная связка работает: 

Index in ES:

```bash
deploy@lab08-es-node1:~$ curl -k -u elastic:5Fha8Wmu9yKTyGbdmA+q  https://localhost:9200/_cat/indices?v
health status index                                                              uuid                   pri rep docs.count docs.deleted store.size pri.store.size dataset.size

green  open   lab04-backend1-2026.04                                             mvDPMP5wTEiNaQNQPP9pTQ   1   1       8122            0     29.6mb         16.3mb       16.3mb
green  open   lab04-backend3-2026.04                                             AZP0wUCNQ46yVwursaga-Q   1   1       7758            0     30.8mb         20.4mb       20.4mb
green  open   lab04-backend2-2026.04                                             tMP_RbfeRSmGFBiaV3OA7A   1   1       7799            0     35.1mb         17.4mb       17.4mb
green  open   lab04-load-balancer-1-2026.04                                      S_Bt2oOtQ3a934mdwunkwQ   1   1         12            0    337.8kb        186.1kb      186.1kb

```

Видим, что интересующие индексы появились в базе, имеют ненулевой размер, а значит могут быть визуализированы в Kibana после настроек индексирования:

![](/Lab08_Kafka_ELK/pics/Kibana_logs.png)

Видим, что логи успешно отображаются, а значит вся связка Kafka + ELK  работает.


Скрин стенда Proxmox, где выполнялось разворачивание стенда:

![](/Lab08_Kafka_ELK/pics/Lab08_proxmox.jpg)

Разворачивание машин осуществляется с использованием Terraform скриптов. Скрипты представлены в дереве проекта.

Выводы:

В данной работе рассмотрен вопрос создания отказоустойчивого кластерного ELK в сочетании с брокером сообщений Kafka. Брокер сообщений был внедрен между Logstash сборщиками логов Filebeat. Данная схема обладает лучшей нагрузочной способностью, т.к. ,брокер Kafka может "амортизировать" всплески нагрузки, сохраняя данные, которые не могут быть немедленно обработаны Logstash, но будут обработаны позже. Показано применение в реальной системе для сбора логов.  