# Веб-портал с централизованным хранилищем секретов в Kubernetes

## Цель

- развернуть веб-приложение в Kubernetes;
- централизовать хранение секретов с помощью Vault и реализовать автоматическое обновление паролей к БД

## Задание

1. Разверните кластер Vault 
2. Разверните кластер веб-приложения с использованием Kubernetes
3. Настройте интеграцию Vault с базой данных и реализацию динамической выдачи паролей, которые обновляются каждые 2 минуты
4. Обеспечьте доставку обновлённого пароля в приложение (например, через шаблоны Consul Template, Vault Agent или переменные окружения)

## Решение

#### 1. Деплой Vault в кластере Kuberenetes

Выполним Vault в кластере Kuberenetes, который был развернут в прошлом задании.

Для установки Vault из-за существующих ограничений Hashicorp вместо Helm`а установим  Vault вручную, с использованием манифестов.

* 1.1.1 Создаем отдельный namespace для vault

```bash
deploy@lab12-kub-master-1:~$ kubectl create namespace vault
namespace/vault created
```

* 1.1.2 Создаем ServiceAccount и Role-based access control (RBAC).
Vault требует ряд специальных прав к API Kubernetes (например к Kubernetes Authentication Method)

```yaml
#vault-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-server-binding
subjects:
- kind: ServiceAccount
  name: vault
  namespace: vault
roleRef:
  kind: ClusterRole
  name: system:auth-delegator
  apiGroup: rbac.authorization.k8s.io
```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl apply -f vault-rbac.yaml
serviceaccount/vault created
clusterrolebinding.rbac.authorization.k8s.io/vault-server-binding created
```

* 1.1.3 Создаем ConfigMap для Vault. Данный конфиг реализует поддержку HA кластера vault на базе алгоритма Raft. Также включена поддержка ui (графического интерфейса). 

```yaml
#vault-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  vault.hcl: |
    ui = true
    disable_mlock = true

    # TCP listener for clients and internal traffic
    listener "tcp" {
      address            = "0.0.0.0:8200"
      cluster_address    = "0.0.0.0:8201"
      tls_disable        = 1
    }

    # Raft Integrated Storage with dynamic naming
    storage "raft" {
      path = "/vault/data"
      node_id = "VAULT_RAFT_NODE_ID"

      # Allows nodes to discover each other via the headless service DNS
      retry_join {
        leader_api_addr = "http://vault-0.vault-internal.vault.svc.cluster.local:8200"
      }
      retry_join {
        leader_api_addr = "http://vault-1.vault-internal.vault.svc.cluster.local:8200"
      }
      retry_join {
        leader_api_addr = "http://vault-2.vault-internal.vault.svc.cluster.local:8200"
      }
    }

```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl apply -f vault-config.yaml
configmap/vault-config created
```

* 1.1.4 Создем Service для получения стабильного сетевого end-point для внуренней коммуникации и ui.

```yaml
#vault-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: vault-internal
  namespace: vault
  labels:
    app: vault
spec:
  clusterIP: None
  ports:
  - name: http
    port: 8200
    targetPort: 8200
  - name: server
    port: 8201
    targetPort: 8201
  selector:
    app: vault
---
apiVersion: v1
kind: Service
metadata:
  name: vault-ui
  namespace: vault
  labels:
    app: vault
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 8200
    targetPort: 8200
  selector:
    app: vault
```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl apply -f vault-service.yaml
service/vault-internal created
service/vault-ui created
```

* 1.1.5 Создаем Persistance Volumes для трех нод

```yaml
#vault-pvs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vault-pv-0
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: vault-pv
  hostPath:
    path: /mnt/vault/data-0
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vault-pv-1
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: vault-pv
  hostPath:
    path: /mnt/vault/data-1
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vault-pv-2
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: vault-pv
  hostPath:
    path: /mnt/vault/data-2
```

```bash
deploy@lab12-kub-master-1:~/vault$  kubectl apply -f vault-pvs.yaml
persistentvolume/vault-pv-0 created
persistentvolume/vault-pv-1 created
persistentvolume/vault-pv-2 created
```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
task-pv-volume   500Mi      RWO            Retain           Released    default/task-pv-claim   manual         <unset>                          22h
vault-pv-0       500Mi      RWO            Retain           Available                           vault-pv       <unset>                          34s
vault-pv-1       500Mi      RWO            Retain           Available                           vault-pv       <unset>                          34s
vault-pv-2       500Mi      RWO            Retain           Available                           vault-pv       <unset>                          34s
```

* 1.1.6 Выполняем деплой StatefulSet для запуска подов vault. 
Устанавливаем кол-во подов равным 3, также включаем podAntiAffinity, чтобы избежать ситуации, когды все поды будут размещены на одной воркер-ноде. Используем настройку preferredDuringSchedulingIgnoredDuringExecution, которая по возможности раскидает поды по доступным воркер нодам. В нашем случае (т.к. воркер-ноды 2) два пода займут одну ноду. 

```yaml
#vault-ha-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault
  labels:
    app: vault
spec:
  serviceName: vault-internal
  replicas: 3
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      # Spreads pods across different physical nodes using Soft anti-affinity rules
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["vault"]
              topologyKey: "kubernetes.io/hostname"    
      containers:
      - name: vault
        image: hashicorp/vault:1.21.0
        command: ["/bin/sh", "-c"]
        args:
        - >
          export VAULT_CLUSTER_ADDR="http://${POD_NAME}.vault-internal.vault.svc.cluster.local:8201" &&
          export VAULT_API_ADDR="http://${POD_NAME}.vault-internal.vault.svc.cluster.local:8200" &&
          exec vault server -config=/vault/config/vault.hcl
        env:
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: VAULT_RAFT_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name       
        ports:
        - name: http
          containerPort: 8200
        - name: server
          containerPort: 8201
        volumeMounts:
        - name: vault-config
          mountPath: /vault/config
        - name: vault-data
          mountPath: /vault/data
        securityContext:
          capabilities:
            add: ["IPC_LOCK"]
      volumes:
      - name: vault-config
        configMap:
          name: vault-config
  volumeClaimTemplates:
  - metadata:
      name: vault-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "vault-pv"
      resources:
        requests:
          storage: 500Mi
```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl apply -f vault-ha-statefulset.yaml
statefulset.apps/vault created
```


* 1.1.7 Проверяем работоспособность подов

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl get pods -n vault -o wide
NAME      READY   STATUS    RESTARTS   AGE   IP            NODE                 NOMINATED NODE   READINESS GATES
vault-0   1/1     Running   0          32s   10.244.4.23   lab12-kub-worker-2   <none>           <none>
vault-1   1/1     Running   0          27s   10.244.3.16   lab12-kub-worker-1   <none>           <none>
vault-2   1/1     Running   0          22s   10.244.4.24   lab12-kub-worker-2   <none>           <none>
```


* 1.2 Инициализация и сборка HA кластера Vault.

* 1.2.1 Инициализация первой ноды и получание мастер-ключей

```bash

deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-0 -n vault -- vault operator init
Unseal Key 1: KC+7FF**************************************
Unseal Key 2: HSRhSi**************************************
Unseal Key 3: PZGfLW**************************************
Unseal Key 4: 2nrY9e**************************************
Unseal Key 5: N21PZB**************************************

Initial Root Token: hvs.SO**********************

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.

```

* 1.2.2 Выполняем Unseal кластер-лидера


Выполняем 3 раза с ключами 1,2,3 команду unseal
```bash
deploy@lab12-kub-master-1:~$ kubectl exec -it vault-0 -n vault -- vault operator unseal
Unseal Key (will be hidden):
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  true
Total Shares            5
Threshold               3
Unseal Progress         1/3
Unseal Nonce            468db492-6a4d-f8d4-104e-456abf1c8d0e
Version                 1.21.1
Build Date              2025-11-18T13:04:32Z
Storage Type            raft
Removed From Cluster    false
HA Enabled              true
```

* 1.2.3 Выполняем команду присоединения 2 и 3 ноды к лидеру кластера:

```bash
deploy@lab12-kub-master-1:~$ kubectl exec -it vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal.vault.svc.cluster.local:8200
Key       Value
---       -----
Joined    true
```

```bash
deploy@lab12-kub-master-1:~$ kubectl exec -it vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal.vault.svc.cluster.local:
8200
Key       Value
---       -----
Joined    true
```

* 1.2.4 Выполняем команды unseal для 2 и 3 ноды.
```bash
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-1 -n vault -- vault operator unseal
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-2 -n vault -- vault operator unseal
```

* 1.2.4 Проверяем статус кластера

```bash
# Login
kubectl exec -it vault-0 -n vault -- vault login <YOUR_ROOT_TOKEN>

# Check Raft peer list
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers

```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-0 -n vault -- vault operator raft list-peers
Node       Address                                                State       Voter
----       -------                                                -----       -----
vault-0    vault-0.vault-internal.vault.svc.cluster.local:8201    leader      true
vault-1    vault-1.vault-internal.vault.svc.cluster.local:8201    follower    true
vault-2    vault-2.vault-internal.vault.svc.cluster.local:8201    follower    true
```

*1.3 Установка Ingress контроллера

Для свободного доступа к UI кластера добавим Ingress контроллер.

```yaml
#vault-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ingress
  namespace: vault
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx  
  rules:
  - host: vault.lab.local  # <--- preferred lab domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault-ui
            port:
              number: 8200
```


### 2. Деплой веб сервиса (Wordpress)

Создаем отдельный namespace 

```bash
deploy@lab12-kub-master-1:~/wordpress$ kubectl create namespace wordpress
namespace/wordpress created
```

2.1 Деплой MySQL

```yaml
#wordpress-mysql.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  namespace: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 3306
  selector:
    app: wordpress
    tier: mysql
  clusterIP: None
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  namespace: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: mysql
  template:
    metadata:
      labels:
        app: wordpress
        tier: mysql
    spec:
      containers:
        - image: mariadb:10.6
          name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "super-secure-password"
            - name: MYSQL_DATABASE
              value: wordpress
            - name: MYSQL_USER
              value: wordpress
            - name: MYSQL_PASSWORD
              value: "super-secure-password"
          ports:
            - containerPort: 3306
              name: mysql
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"    
```

2.2 Configure the Dynamic Rotation Role in Vault


```bash
# 1. Enable the database secrets engine (if you haven't already)
vault secrets enable database

# 2. Configure Vault with root connection details to MariaDB across namespaces
vault write database/config/wordpress-db \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(wordpress-mysql.wordpress.svc.cluster.local:3306)/" \
    allowed_roles="wordpress-role" \
    username="root" \
    password="super-secure-password"

# 3. Create the role with a 5-minute Time-To-Live (300 seconds)
vault write database/roles/wordpress-role \
    db_name=wordpress-db \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT ALL PRIVILEGES ON wordpress.* TO '{{name}}'@'%';" \
    default_ttl="5m" \
    max_ttl="5m"

# 4. Bind the policy to the wordpress ServiceAccount inside the 'wordpress' namespace
vault write auth/kubernetes/role/wordpress-role \
    bound_service_account_names=wordpress-sa \
    bound_service_account_namespaces=wordpress \
    policies=wordpress-policy \
    ttl=24h
```

Проверим работу связки Vault -> DB

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-0 -n vault -- /bin/sh
/ # vault read database/creds/wordpress-role
Key                Value
---                -----
lease_id           database/creds/wordpress-role/bZGxHXDHbMrJdDYZVnJaApge
lease_duration     4m59s
lease_renewable    true
password           1T-BIuHohtR7vB2KPb3u
username           v-root-wordpress--0ohb7PfqY2XrT9
```

 Run a temporary client pod to connect to your MariaDB service

```bash
deploy@lab12-kub-master-1:~/vault$ 
kubectl run mariadb-client --rm -it --image=mariadb:10.6 -n wordpress -- \
  mysql -h wordpress-mysql -u root -p"super-secure-password" -e "SELECT User, Host FROM mysql.user;"
+----------------------------------+-----------+
| User                             | Host      |
+----------------------------------+-----------+
| root                             | %         |
| v-root-wordpress--0ohb7PfqY2XrT9 | %         |
| wordpress                        | %         |
| healthcheck                      | 127.0.0.1 |
| healthcheck                      | ::1       |
| healthcheck                      | localhost |
| mariadb.sys                      | localhost |
| root                             | localhost |
```

После >5 пользователь в базе пропал:

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl run mariadb-client --rm -it --image=mariadb:10.6 -n wordpress --   mysql -h wordpress-mysql -u root -p"super-secure-password" -e "SELECT User, Host FROM mysql.user;"
+-------------+-----------+
| User        | Host      |
+-------------+-----------+
| root        | %         |
| wordpress   | %         |
| healthcheck | 127.0.0.1 |
| healthcheck | ::1       |
| healthcheck | localhost |
| mariadb.sys | localhost |
| root        | localhost |
+-------------+-----------+
```

Выполняем заново команды:

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-0 -n vault -- /bin/sh
/ # vault read database/creds/wordpress-role
Key                Value
---                -----
lease_id           database/creds/wordpress-role/Flmpd7BDwa5SdhUOpzSx5JWh
lease_duration     4m59s
lease_renewable    true
password           Wo6bzB6RKDSf-KsRRidf
username           v-root-wordpress--Jkit7xnB8ldPlS
```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl run mariadb-client --rm -it --image=mariadb:10.6 -n wordpress --   mysql -h wordpress-mysql -u root -p"super-secure-password" -e "SELECT User, Host FROM mysql.user;"
+----------------------------------+-----------+
| User                             | Host      |
+----------------------------------+-----------+
| root                             | %         |
| v-root-wordpress--Jkit7xnB8ldPlS | %         |
| wordpress                        | %         |
| healthcheck                      | 127.0.0.1 |
| healthcheck                      | ::1       |
| healthcheck                      | localhost |
| mariadb.sys                      | localhost |
| root                             | localhost |
+----------------------------------+-----------+
```


Deploy WordPress

```yaml
#wordpress-app.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wordpress-sa
  namespace: wordpress
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: wp-config-template
  namespace: wordpress
data:
  wp-vault-config.php: |
    <?php
    $vault_file = '/vault/secrets/db-creds';
    if (file_exists($vault_file)) {
        $lines = file($vault_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                define(trim($key), trim($value));
            }
        }
    }
    if (!defined('DB_USER')) define('DB_USER', 'fallback');
    if (!defined('DB_PASSWORD')) define('DB_PASSWORD', 'fallback');
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
      annotations:
        vault.hashicorp.com/agent-inject: "true"      # Tells Kubernetes to inject the Vault sidecar proxy container
        vault.hashicorp.com/role: "wordpress-role"    #  Binds the pod to your pre-configured Vault authorization role
        vault.hashicorp.com/auth-path: "auth/kubernetes" # Instructs the sidecar on where to find the Kubernetes auth engine path
        vault.hashicorp.com/proxy-address: "http://vault.vault.svc.cluster.local" #Maps the route out of the 'wordpress' namespace directly to the 'vault' cluster 
        vault.hashicorp.com/secret-db-creds: "database/creds/wordpress-role"
        vault.hashicorp.com/template-db-creds: |
          {{- with secret "database/creds/wordpress-role" -}}
          DB_USER={{ .Data.username }}
          DB_PASSWORD={{ .Data.password }}
          {{- end -}}
    spec:
      serviceAccountName: wordpress-sa
      containers:
        - image: wordpress:latest
          name: wordpress
          env:
            # Connect to MariaDB using FQDN across the namespace
            - name: WORDPRESS_DB_HOST
              value: wordpress-mysql.wordpress.svc.cluster.local
            - name: WORDPRESS_DB_NAME
              value: wordpress
          ports:
            - containerPort: 80
              name: wordpress
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          volumeMounts:
            - name: config-template
              mountPath: /var/www/html/wp-vault-config.php
              subPath: wp-vault-config.php
          command: ["/bin/sh", "-c"]
          args:
            - |
              docker-entrypoint.sh apache2-foreground &
              while [ ! -f /var/www/html/wp-config.php ]; do sleep 1; done
              if ! grep -q "wp-vault-config.php" /var/www/html/wp-config.php; then
                sed -i "2i include('/var/www/html/wp-vault-config.php');" /var/www/html/wp-config.php
                sed -i "/define( 'DB_USER'/d" /var/www/html/wp-config.php
                sed -i "/define( 'DB_PASSWORD'/d" /var/www/html/wp-config.php
              fi
              wait
      volumes:
        - name: config-template
          configMap:
            name: wp-config-template
```


Ingress

```yaml
#wordpress-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: wordpress
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: wordpress.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wordpress
                port:
                  number: 80
```

альтернативный вариант деплоя.

```yaml
#wordpress-app.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wordpress-sa
  namespace: wordpress
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: wp-config-template
  namespace: wordpress
data:
  wp-vault-config.php: |
    <?php
    // Dynamically read the file generated/rotated by the Vault agent sidecar
    $vault_file = '/vault/secrets/db-creds';
    if (file_exists($vault_file)) {
        $lines = file($vault_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                define(trim($key), trim($value));
            }
        }
    }
    if (!defined('DB_USER')) define('DB_USER', 'fallback');
    if (!defined('DB_PASSWORD')) define('DB_PASSWORD', 'fallback');
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      serviceAccountName: wordpress-sa
      containers:
        # --- CONTAINER 1: THE WORDPRESS APPLICATION ---
        - image: wordpress:latest
          name: wordpress
          env:
            - name: WORDPRESS_DB_HOST
              value: wordpress-mysql.wordpress.svc.cluster.local
            - name: WORDPRESS_DB_NAME
              value: wordpress
          ports:
            - containerPort: 80
              name: wordpress
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          volumeMounts:
            - name: config-template
              mountPath: /var/www/html/wp-vault-config.php
              subPath: wp-vault-config.php
            - name: vault-secrets
              mountPath: /vault/secrets
          command: ["/bin/sh", "-c"]
          args:
            - |
              # Block startup until the manual Vault sidecar creates the dynamic file
              while [ ! -f /vault/secrets/db-creds ]; do sleep 1; done
              docker-entrypoint.sh apache2-foreground &
              while [ ! -f /var/www/html/wp-config.php ]; do sleep 1; done
              if ! grep -q "wp-vault-config.php" /var/www/html/wp-config.php; then
                sed -i "2i include('/var/www/html/wp-vault-config.php');" /var/www/html/wp-config.php
                sed -i "/define( 'DB_USER'/d" /var/www/html/wp-config.php
                sed -i "/define( 'DB_PASSWORD'/d" /var/www/html/wp-config.php
              fi
              wait

        # --- CONTAINER 2: THE MANUAL VAULT AGENT SIDECAR ---
        - image: hashicorp/vault:latest
          name: vault-agent
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
            - name: agent-config
              mountPath: /etc/vault
            - name: k8s-sa-token
              mountPath: /var/run/secrets/kubernetes.io/serviceaccount
              readOnly: true  
          command: ["vault", "agent", "-config=/etc/vault/vault-agent-config.hcl"]
          resources:
            limits:
              memory: "128Mi"
              cpu: "100m"

      volumes:
        - name: config-template
          configMap:
            name: wp-config-template
        - name: vault-secrets
          emptyDir: {}
        - name: agent-config
          configMap:
            name: vault-agent-config
        - name: k8s-sa-token
          projected:
            sources:
              - serviceAccountToken:
                  path: token
                  expirationSeconds: 7200    
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-config
  namespace: wordpress
data:
  vault-agent-config.hcl: |
    exit_after_auth = false
    pid_file = "/home/vault/pid"

    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "wordpress-role"
          token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        }
      }
      sink "file" {
        config = {
          path = "/vault/secrets/token"
        }
      }
    }

    vault {
      # Uses the cross-namespace endpoint pointing to your Vault cluster
      address = "http://vault-internal.vault.svc.cluster.local:8200"
    }

    template {
      destination = "/vault/secrets/db-creds"
      contents = <<EOH
      {{- with secret "database/creds/wordpress-role" -}}
      DB_USER={{ .Data.username }}
      DB_PASSWORD={{ .Data.password }}
      EOH
    }
```

