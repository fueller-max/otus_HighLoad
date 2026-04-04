


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