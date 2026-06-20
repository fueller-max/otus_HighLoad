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
  persistentVolumeReclaimPolicy: Delete
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
deploy@lab12-kub-master-1:~/vault$ deploy@lab12-kub-master-1:~/vault$ kubectl apply -f vault-pvs.yaml
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
        command: ["vault", "server", "-config=/vault/config/vault.hcl"]
        env:
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        # 1. Fetch the real pod IP from the Kubernetes Cluster
        - name: INSTANCE_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP  
        # 2. Tell Vault explicitly to use these IPs for HA clustering
        - name: VAULT_CLUSTER_ADDR
          value: "https://$(INSTANCE_POD_IP):8201"
        - name: VAULT_API_ADDR
          value: "http://$(INSTANCE_POD_IP):8200"
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

Verify cluster status:

```bash
# Login
kubectl exec -it vault-0 -n vault -- vault login <YOUR_ROOT_TOKEN>

# Check Raft peer list
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers

```

```bash
deploy@lab12-kub-master-1:~/vault$ kubectl exec -it vault-0 -n vault -- vault operator raft list-peers
Node       Address             State       Voter
----       -------             -----       -----
vault-0    10.244.4.38:8201    leader      true
vault-1    10.244.3.23:8201    follower    true
vault-2    10.244.4.39:8201    follower    true
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