

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

mysqlrouter --bootstrap clusteradmin@10.10.30.42:3306 --directory /opt/mysql-router/data
sudo chmod -R 0777 /opt/mysql-router/


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

define('DB_HOST', 'localhost:6446');


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