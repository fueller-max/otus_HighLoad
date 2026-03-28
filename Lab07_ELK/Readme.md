

```bash
 deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-kUBfs2aj27A2EP7q https://localhost:9200/_cat/nodes
10.10.50.51 61 94 13 0.18 0.25 0.10 cdfhilmrstw * lab07-es-node1
10.10.50.52 26 95 10 0.25 0.23 0.11 cdfhilmrstw - lab07-es-node2
10.10.50.53 23 96 13 0.25 0.18 0.08 cdfhilmrstw - lab07-es-node3
```

```bash
deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-kUBfs2aj27A2EP7q https://localhost:9200/_cat/nodes
10.10.50.51 31 52  7 0.05 0.09 0.04 cdfhilmrstw - lab07-es-node1
10.10.50.53 25 50 20 0.41 0.14 0.05 cdfhilmrstw - lab07-es-node3
10.10.50.52 31 66 14 0.23 0.14 0.05 cdfhilmrstw * lab07-es-node2

```


MuY-kUBfs2aj27A2EP7q


eyJ2ZXIiOiI4LjE0LjAiLCJhZHIiOlsiMTAuMTAuNTAuNTE6OTIwMCJdLCJmZ3IiOiIzMGNhNWExMjcxZTVmZGY4YTVmMWYxYWE1ZWVhZGYzMDEzZTQ5Zjk2NmIzMzdkNzZmMjhjMGJiMjRlNmE4MDE0Iiwia2V5IjoiT05DV001MEJpZXJCZlVKR0RLSnk6OFJTalhoZXNEZklwTEk2dHktOUdMZyJ9

539 422


```bash
 logstash.service - logstash
     Loaded: loaded (/usr/lib/systemd/system/logstash.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-03-28 13:40:22 UTC; 11min ago
   Main PID: 685 (java)
      Tasks: 40 (limit: 4653)
     Memory: 743.8M (peak: 744.3M)
        CPU: 35.033s
     CGroup: /system.slice/logstash.service
             └─685 /usr/share/logstash/jdk/bin/java -Xms1g -Xmx1g -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djruby.compile.invokedynamic=true -XX:+HeapDumpOnOutOfMemoryError -Djava.se>

Mar 28 13:40:37 lab07-node-logstash logstash[685]: [2026-03-28T13:40:37,191][INFO ][logstash.outputs.elasticsearch][main] Using a default mapping template {:es_version=>8, :ecs_compatibilit>
Mar 28 13:40:37 lab07-node-logstash logstash[685]: [2026-03-28T13:40:37,298][WARN ][logstash.filters.geoip   ][main] ECS expect `target` value `geoip` in ["client", "destination", "host", ">
Mar 28 13:40:37 lab07-node-logstash logstash[685]: [2026-03-28T13:40:37,856][INFO ][logstash.filters.geoip.databasemanager][main] By not manually configuring a database path with `database >
Mar 28 13:40:37 lab07-node-logstash logstash[685]: [2026-03-28T13:40:37,856][INFO ][logstash.filters.geoip   ][main] Using geoip database {:path=>"/var/lib/logstash/geoip_database_managemen>
Mar 28 13:40:37 lab07-node-logstash logstash[685]: [2026-03-28T13:40:37,888][INFO ][logstash.javapipeline    ][main] Starting pipeline {:pipeline_id=>"main", "pipeline.workers"=>2, "pipelin>
Mar 28 13:40:38 lab07-node-logstash logstash[685]: [2026-03-28T13:40:38,436][INFO ][logstash.javapipeline    ][main] Pipeline Java execution initialization time {"seconds"=>0.55}
Mar 28 13:40:38 lab07-node-logstash logstash[685]: [2026-03-28T13:40:38,441][INFO ][logstash.inputs.beats    ][main] Starting input listener {:address=>"0.0.0.0:5044"}
Mar 28 13:40:38 lab07-node-logstash logstash[685]: [2026-03-28T13:40:38,464][INFO ][logstash.javapipeline    ][main] Pipeline started {"pipeline.id"=>"main"}
Mar 28 13:40:38 lab07-node-logstash logstash[685]: [2026-03-28T13:40:38,475][INFO ][logstash.agent           ] Pipelines running {:count=>1, :running_pipelines=>[:main], :non_running_pipeli>
Mar 28 13:40:38 lab07-node-logstash logstash[685]: [2026-03-28T13:40:38,542][INFO ][org.logstash.beats.Server][main][2df36cca65242b459014b016737d7c0e7fb4fc83dcb47c85287b8f1000f951bd
```


```bash
deploy@lab07-es-node1:~$ curl -k -u elastic:MuY-kUBfs2aj27A2EP7q https://localhost:9200/_cat/indices?v
health status index                                                              uuid                   pri rep docs.count docs.deleted store.size pri.store.size dataset.size
green  open   websrv-2026.03                                                     DVYAjWVJTlWOmqJbFzDh0g   1   1         39            0    559.4kb        349.2kb      349.2kb
green  open   .internal.alerts-observability.slo.alerts-default-000001           mBzqnhtbQfWsw93QZbgBMQ   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-security.alerts-default-000001                    2xM7mxCoToChfjDF6aqbsQ   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-observability.metrics.alerts-default-000001       6dRf9oQCSVaZOxWBYJ4cqQ   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-observability.apm.alerts-default-000001           R8mRupCxR3uJL0uhuWK6rw   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-security.attack.discovery.alerts-default-000001   beWXwW9fSNifnW2ZbQ45Ag   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-observability.logs.alerts-default-000001          cgfzPy0TR3ioKsIiGzoR7A   1   1          0            0       498b           249b         249b
green  open   lab04-backend2-2026.03                                             tAw2O392RQKt2VF1yMQyxA   1   1       7649            0        7mb          3.5mb        3.5mb
green  open   lab04-backend3-2026.03                                             MeKVBSzYRbaF4BOq-BD58A   1   1       6639            0      6.7mb          3.2mb        3.2mb
green  open   .internal.alerts-ml.anomaly-detection-health.alerts-default-000001 VsXDYKCGRbaoovPByjrnVA   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-transform.health.alerts-default-000001            c-OOoa7uRG6sVyYBzY2ZVg   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-streams.alerts-default-000001                     maCjpCFkQOqgjrVDxuS0Lg   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-stack.alerts-default-000001                       coSm38ogQ-iuaJPYvkliqw   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-dataset.quality.alerts-default-000001             hNY_Ua1BRPe0pACi0JeAjw   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-observability.threshold.alerts-default-000001     47viOr1gTNCyFPpFMvPglQ   1   1          0            0       498b           249b         249b
green  open   lab04-load-balancer-1-2026.03                                      w2h34eb2TeK8ExI_ypFfrA   1   1         24            0    482.2kb        241.1kb      241.1kb
green  open   .internal.alerts-default.alerts-default-000001                     Y6sdBZRLT_mjnTNo-arBmQ   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-observability.uptime.alerts-default-000001        s6zliCrGQJ62J1J98G0B5g   1   1          0            0       498b           249b         249b
green  open   .internal.alerts-ml.anomaly-detection.alerts-default-000001        PS5x5Kr8QT6Q4GNSC6Syeg   1   1          0            0       498b           249b         249b
green  open   lab04-backend1-2026.03                                             HgYBDDm7TV6UTEGn-Q_ZhQ   1   1       7324            0      7.5mb          3.5mb        3.5mb

```