


Filebeat yml file format:

```bash
filebeat.inputs
- type: log
  enabled: true
  paths:
    - /path/to/log/file1.log
    - /path/to/log/file2.log
  fields:
    key1: value1
    key2: value2


# Additional configuration settings go here

output.elasticsearch:
  hosts: ["http://elasticsearch-host:9200"]
  index: "filebeat-%{+yyyy.MM.dd}"
  # Optional Elasticsearch username and password
  username: "your_username"
  password: "your_password"


# Alternatively, you can use Logstash as the output
# Uncomment the following lines and specify Logstash host and port
#output.logstash:
#  hosts: ["logstash-host:5044"]

```


Logstash conf file format:

```bash

input {
  kafka {
    bootstrap_servers => "kafka-broker1:9092,kafka-broker2:9092" # List of Kafka brokers
    topics => ["your_topic_name"] # Name of the Kafka topic to consume data from
    group_id => "logstash-consumer-group" # Consumer group ID
    consumer_threads => 1 # Number of consumer threads
    codec => "json" # Codec used to parse the message (assuming it's in JSON format)
  }
}


filter {
  # Add any filter operations as needed based on the format of the incoming messages
}


output {
  stdout { codec => rubydebug } # Output logs to the console for debugging
  elasticsearch {
    hosts => ["http://elasticsearch-host:9200"]
    index => "mylogs-%{+YYYY.MM.dd}"
  }
}

```


Kafka cluster state:

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

```bash
deploy@lab08-kafka-node1:~$ sudo  /opt/kafka/bin/kafka-health-check.sh
Checking broker availability...
✓ Brokers are accessible
Checking under-replicated partitions...
✓ All partitions are properly replicated
Health check completed
```

```bash
 deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-topics.sh  --create  --topic test-topic  --bootstrap-server 10.10.50.80:9092 --partitions 3 --replication-factor 3
deploy@lab08-kafka-node1:~$ echo "Hello Kafka!" | sudo /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server 10.10.50.80:9092
deploy@lab08-kafka-node1:~$ sudo /opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --from-beginning --bootstrap-server 10.10.50.80:9092
Hello Kafka!
```



Create topics

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

Logstash in Kafka:

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


Index in ES:

```bash
deploy@lab08-es-node1:~$ curl -k -u elastic:5Fha8Wmu9yKTyGbdmA+q  https://localhost:9200/_cat/indices?v
health status index                                                              uuid                   pri rep docs.count docs.deleted store.size pri.store.size dataset.size

green  open   lab04-backend1-2026.04                                             mvDPMP5wTEiNaQNQPP9pTQ   1   1       8122            0     29.6mb         16.3mb       16.3mb
green  open   lab04-backend3-2026.04                                             AZP0wUCNQ46yVwursaga-Q   1   1       7758            0     30.8mb         20.4mb       20.4mb
green  open   lab04-backend2-2026.04                                             tMP_RbfeRSmGFBiaV3OA7A   1   1       7799            0     35.1mb         17.4mb       17.4mb
green  open   lab04-load-balancer-1-2026.04                                      S_Bt2oOtQ3a934mdwunkwQ   1   1         12            0    337.8kb        186.1kb      186.1kb

```