# Деплой веб-проекта в Kubernetes

## Цель

- Установить Kubernetes и развернуть в нём веб-портал 
- Настроить бэкап конфигурации кластера

## Задание

1. Разверните кластер Kubernetes на виртуальных машинах (например, через kubeadm).
2. Создайте манифесты для автоматического деплоя веб-портала (nginx, wordpress и т.д.).
3. Настройте ConfigMap, Secret, Ingress и другие необходимые ресурсы.
4. Настройте бэкап конфигурации кластера (манифесты и данные etcd или kubectl get all --all-namespaces -o yaml).

## Решение

### 1. Разворачивание кластера Kubernetes на виртуальных машинах в Proxmox

#### 1.0 Описание архитектуры кластера 

В данной работе реализуем кластер Kubernetes в соответствии с представленной схемой

![Kub_cluster](/Lab12_Kubernetes/pics/Kubernetes_cluster.jpg)

В данной архитектуре предусматривается:

1. Три мастер-ноды (Control Plane) - ядро кластера
2. Две ноды отказоустойчивого балансировщика для API мастер-нод
3. Две воркер-ноды для размещения рабочих подов

Общение между воркер нодами и API Control Plane осуществляется через балансировщик (HA Proxy + keepalived).
Таким образом, реализуется полностью отказоустойчивый кластер Kubernetes, выдерживающий выход из строя любой одной ноды. 

#### 1.1 Развертывание VM для нод кластера в Proxmox

Для развертывания нод используется стенд с виртуализацией Prоxomox. Для автоматизированного развертывания машин используется Terraform . Параметры разворачиваемых машин: 

<details><summary>variables.tf</summary>

```yaml
default = {
    "lab12-kub-master-1" = { 
        vm_id       =  161
        name        =  "lab12-kub-master-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.48/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.48/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-master-2" = { 
        vm_id       =  162
        name        =  "lab12-kub-master-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.49/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.49/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-master-3" = { 
        vm_id       =  163
        name        =  "lab12-kub-master-3"
        clone       =  "Ubuntu2404-live-server"
        memory      =  4096
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.50/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.50/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-lb-1" = { 
        vm_id       =  164
        name        =  "lab12-kub-lb-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.51/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.51/24"
        network_tag1 =  0
        start_at_node_boot =  true
      } 
    "lab12-kub-lb-2" = { 
        vm_id       =  165
        name        =  "lab12-kub-lb-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.52/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.52/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }
    "lab12-kub-worker-1" = { 
        vm_id       =  166
        name        =  "lab12-kub-worker-1"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.53/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.53/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }  
    "lab12-kub-worker-2" = { 
        vm_id       =  167
        name        =  "lab12-kub-worker-2"
        clone       =  "Ubuntu2404-live-server"
        memory      =  2048
        cores       =  2
        sockets     =  2
        vm_state    =  "running" 
        bridge0     =  "vmbr0"
        ip_conf0    =  "ip=192.168.70.54/24,gw=192.168.70.1"
        network_tag0 =  0
        bridge1     =  "vmbr3"
        ip_conf1    =  "ip=10.10.30.54/24"
        network_tag1 =  0
        start_at_node_boot =  true
      }  
  }
   ```  
   </details>

#### 1.2 Установка и настройка Control Plane кластера

Для установки и настройки Control Plane кластера напишем Ansible-роль, которая будет выполнять:

- подготовку ВМ для работы с Kubernetes (отключение свапа, настройки netfilter, ip_forward и т.д. )
- установку container runtime (containerd)
- установку kubeadm, kubelet, kubectl. Будем использовать зеркало Яндекса.
- инициализация кластера на первой ноде
- добавление двух других нод в кластер в сontrol plane

Таски роли kube-cluster-master

<details><summary>pre_provision.yml</summary>

```yaml
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
    line: '# - update_etc_hosts'
    backup: true   
  tags: [always]

- name: Copy k8s.conf to load kernel modules
  ansible.builtin.copy:
    src: files/kernel/k8s.conf
    dest: /etc/modules-load.d/k8s.conf
    owner: root
    group: root
    mode: '0644'
  tags: [always]

- name: Copy k8s.conf for Kubernetes networking
  ansible.builtin.copy:
    src: files/networking/k8s.conf
    dest: /etc/sysctl.d/k8s.conf
    owner: root
    group: root
    mode: '0644' 
  tags: [always]

- name: Disable swap in etc/fstab
  ansible.builtin.lineinfile:
    path: /etc/fstab
    regexp: '\/swap.img.*' 
    line: '# /swap.img.    none    swap    sw      0       0'
    backup: true   
  tags: [always]  

- name: Reboot the server to load/apply all the changes 
  reboot:
    reboot_timeout: 3600 
  tags: [always]  
  ```
  </details>


<details><summary>install_containerd.yml</summary>

```yaml
- name: Update package cache
  apt:
    update_cache: yes
  tags: always

- name: Install containerd
  ansible.builtin.apt:
      name:
        - containerd
      state: present    
  tags: always

- name: Create directory for containerd config
  ansible.builtin.file:
    path: /etc/containerd/
    state: directory
    owner: root
    group: root
    mode: '0755'
  tags: always

- name: Create file for containerd config
  ansible.builtin.file:
    path: /etc/containerd/config.toml
    state: touch
    owner: root
    group: root
    mode: '0755'
  tags: always

- name: Create default containerd configuration
  ansible.builtin.shell: containerd config default > /etc/containerd/config.toml
  register: containerd_configuration
  failed_when: containerd_configuration.rc != 0
  ignore_errors: yes
  tags: always  

- name: Enable SystemdCgroup in containerd config (optimization for Kubernetes)
  ansible.builtin.lineinfile:
    path: /etc/containerd/config.toml
    regexp: '^SystemdCgroup\s*=\s*false$'
    line: 'SystemdCgroup = true'
    backup: yes
  tags: always 

- name: Enable and start containerd service
  ansible.builtin.systemd:
    name: containerd
    state: restarted
    enabled: yes
  register: containerd_status
  tags: always 

- name: Wait for containerd to be ready
  ansible.builtin.command: ctr version
  register: ctr_check
  retries: 5
  delay: 2
  until: ctr_check is success
  when: containerd_status is changed
  tags: always 
```

</details>


<details><summary>install_kubernetes_ya.yml</summary>

```yaml
- name: Download the public signing key 
  ansible.builtin.shell: curl -fsSL "{{kube_yandex_mirror}}"/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-yandex-keyring.gpg --yes
  register: kubernetes_sign
  failed_when: kubernetes_sign.rc != 0
  tags: always 

- name: Add Kubernetes apt repository
  ansible.builtin.shell: echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-yandex-keyring.gpg] {{kube_yandex_mirror}}  /' | tee /etc/apt/sources.list.d/kubernetes-yandex.list
  register: kubernetes_repo
  failed_when: kubernetes_repo.rc != 0
  tags: always     

- name: Update repo indexes  
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 0  
  tags: always    

- name: Install Kubernetes infra
  ansible.builtin.apt:
      name:
        - kubelet
        - kubeadm
        - kubectl
      state: present    
  tags: always  

- name: Hold packages for update
  ansible.builtin.dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubelet
    - kubeadm
    - kubectl
  tags: always  

- name: Enable and start kubelet
  ansible.builtin.systemd:
    name: kubelet
    state: started
    enabled: yes
  register: kubelet_status
  tags: always 
```

</details>


<details><summary>provision.yml</summary>

```yaml
- name: Initialize the First Control Plane Node 
  ansible.builtin.shell: |
     kubeadm init --control-plane-endpoint="{{ balancer_vip }}:6443" --pod-network-cidr="{{pod_network_cidr}}" --upload-certs
  register: enroll_token
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes | first }}"
  tags: [always] 

- name: Print enrollment token
  ansible.builtin.debug:
    var: enroll_token.stdout
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes  | first }}" 
  tags: [always]   

- name: Check if the configuration file for local admin access exists
  ansible.builtin.stat:
    path: /home/"{{ deploy_user }}"
  register: config_stat
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes | first }}"
  tags: [always] 

- name: Print enrollment token
  ansible.builtin.debug:
    var: config_stat
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes  | first }}" 
  tags: [always]   

- name: Configure local admin access for deploy user 
  ansible.builtin.shell: |
    mkdir -p /home/"{{ deploy_user }}"/.kube
    cp -i /etc/kubernetes/admin.conf /home/"{{ deploy_user }}"/.kube/config
    chown "{{ deploy_user }}":"{{ deploy_user }}" /home/"{{ deploy_user }}"/.kube/config
  when: not config_stat.stat.exists  
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes | first }}"
  tags: [always] 

- name: Apply the Flannel Network Plugin
  ansible.builtin.shell: |
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  run_once: true    
  delegate_to:  "{{ groups.kub_master_nodes | first }}"
  tags: [always]   

- name: Join the Other Two Control Plane Nodes
  ansible.builtin.shell: |
    kubeadm join "{{ balancer_vip }}":6443 --token "{{ token }}" --discovery-token-ca-cert-hash "{{ discovery_token_ca_cert_hash }}" --control-plane --certificate-key "{{ certificate_key }}"
  when: inventory_hostname != groups.kub_master_nodes | first
  tags: [always] 
    
```

</details>

#### 1.3 Установка и настройка LoadBalancer API кластера

Отказоустойчивый балансировщик API кластера развернем по схеме HAProxy + keepalived с плавающим IP (VIP).

Роль для разворачивания HAProxy + keepalived  уже использовалась в рамках данного курса, приведем лишь конфигурацию HAProxy

<details><summary>haproxy.cfg</summary>

```yaml
global
    log /dev/log local0 warning
    maxconn 4000
    user haproxy
    group haproxy
    daemon
    log-send-hostname
    spread-checks 3

defaults
    log global
    mode tcp
    # Set long timeouts for persistent connections (kubectl exec/logs)
    timeout connect 10s
    timeout client 86400s
    timeout server 86400s

frontend kubernetes-api
    bind *:6443
    mode tcp
    description "Kubernetes API Load Balancer"
    default_backend kubernetes-api-backend

backend kubernetes-api-backend
    mode tcp
    option tcp-check
    balance roundrobin
    {% set masters = groups['kub_master_nodes'] | map('extract', hostvars, 'cluster_net_addr') | list %}
    server master-node-1 {{ masters[0] }}:6443 check
    server master-node-2 {{ masters[1] }}:6443 check
    server master-node-3 {{ masters[2] }}:6443 check

listen stats
    bind :8443
    stats enable
    mode http
    stats uri /stats
    stats realm Haproxy\ Statistics
    stats auth admin:strongpassword
```
</details>

и keepalived

<details><summary>keepalived.conf</summary>

```yaml
global_defs {
    enable_script_security
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy""
    interval 2      
    weight 2        
    fall 2          
    rise 2 
    user root         
}

vrrp_instance ha_proxy {

  {% if vrrp_role == "master" %}
    state MASTER
  {% elif vrrp_role == "slave" %}
    state BACKUP
  {% endif %}
    interface eth1   
    virtual_router_id 254 
  {% if vrrp_role == "master" %}
    priority 100
  {% elif vrrp_role == "slave" %}
    priority 99
  {% endif %}    
    
    advert_int 1 
 
  {% if vrrp_role == "master" %}
    unicast_src_ip {{ vrrp_net_addr }}
    unicast_peer {
        {{ hostvars[groups.kub_loadbalancers_nodes[1]]['vrrp_net_addr'] }}
    }
  {% elif vrrp_role == "slave"  %}
    unicast_src_ip {{ vrrp_net_addr  }}
    unicast_peer {
        {{ hostvars[groups.kub_loadbalancers_nodes[0]]['vrrp_net_addr'] }}
    }
  {% endif %}
    

    virtual_ipaddress {
        {{ balancer_vip }} dev eth1
    } track_script {
        chk_haproxy
    }

```
</details>

#### 1.4 Установка и настройка Worker-нод кластера

В целом деплой воркер-нод аналогичен деплою control-plane нод кластера за исключением того, что на воркер ноды не устанавливается kubectl и отдельная процедура join`а к кластеру.
Содержание роли здесь приводить не будем, ознакомится можно в папке roles/kube-workers.

#### 1.4 Проверка состояния кластера

На первой control-plane ноде проверим состав нод нашего кластера:

```bash
deploy@lab12-kub-master-1:~$ kubectl get nodes
NAME                 STATUS   ROLES           AGE     VERSION
lab12-kub-master-1   Ready    control-plane   4h42m   v1.36.1
lab12-kub-master-2   Ready    control-plane   73m     v1.36.1
lab12-kub-master-3   Ready    control-plane   73m     v1.36.1
lab12-kub-worker-1   Ready    <none>          6m46s   v1.36.1
lab12-kub-worker-2   Ready    <none>          6m46s   v1.36.1
```
Убеждаемся, что все ноды кластера доступны и находятся в состоянии "Ready"

Также выполним мониторинг со стороны HA Proxy и видим, что все мастер-ноды доступны:

![](/Lab12_Kubernetes/pics/HAproxy_API_control_plane.png)


Таким образом, наш кластер развернут и готов к работе.

### 2. Тестовый деплой контейнера Nginx

Для проверки работы созданного кластера выполним тестовый деплой простого контейнера Nginx.

Для этого создадим простой манифест, содержащий:

 - Deployment для управления контейнерами приложения, где зададим тип контейнера и кол-во реплик (2 в данном случае) 
 - Service, задача которого выделить сетевой endpoint для сервиса. В данном случае используется ClusterIP и сервис будет изолирован в рамках внутреннего трафика кластера.


```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Применяем манифест:

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl apply -f nginx-test.yaml
deployment.apps/nginx-deployment created
service/nginx-service created
```

Проверим, что поды (2 шт) приложения запустились:

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE     IP           NODE                 NOMINATED NODE   READINESS GATES
nginx-deployment-cd54446c4-4grlk   1/1     Running   0          2m56s   10.244.4.2   lab12-kub-worker-2   <none>           <none>
nginx-deployment-cd54446c4-sp9zd   1/1     Running   0          2m56s   10.244.3.2   lab12-kub-worker-1   <none>           <none>
```

Отметим также, что поды развернулись на двух разных воркер-нодах. 

Проверяем, что ClusterIP создал внутренний балансировщик и выделил общий абстрактный IP для сервиса: 

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get service nginx-service
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx-service   ClusterIP   10.105.217.88   <none>        80/TCP    5m1s
```

С ноды кластера пробуем сделать запрос к Nginx и получаем ответ: 

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ curl  http://10.105.217.88
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

После тестов удаляем созданный сервис:

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl delete -f nginx-test.yaml
deployment.apps "nginx-deployment" deleted from default namespace
service "nginx-service" deleted from default namespace
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get pods -o wide
No resources found in default namespace.
```

### 3. Установка балансировщика MetaLB, Ingress-контроллера

Для того, чтобы решить задачу передачи внешнего трафика на работающие сервисы внутри кластера Kubernetes будем использовать связку балансировщик MetaLB + Ingress-контроллер Nginx.

MetaLB - софтовый балансировщик для bare-metal кластеров, который выполняет перенаправление трафика с пула внешних IP во внутренние IP cервисов кластера. Будем использовать стандартный режим Layer 2 (ARP/NDP) Mode.

### 3.1 Установка балансировщика MetaLB

Для деплоя MetaLB используем стандартные манифесты, доступные на github:

```bash
deploy@lab12-kub-master-1:~$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
namespace/metallb-system created
customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/servicel2statuses.metallb.io created
serviceaccount/controller created
serviceaccount/speaker created
role.rbac.authorization.k8s.io/controller created
role.rbac.authorization.k8s.io/pod-lister created
clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
rolebinding.rbac.authorization.k8s.io/controller created
rolebinding.rbac.authorization.k8s.io/pod-lister created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
configmap/metallb-excludel2 created
secret/metallb-webhook-cert created
service/metallb-webhook-service created
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created
```

Проверим, что поды MetaLB (speaker-*) появились в кластере:

```bash
deploy@lab12-kub-master-1:~$ kubectl get pods -A
***
metallb-system   controller-7d69cc69fd-258cc                  1/1     Running   1 (50s ago)   112s
metallb-system   speaker-bdcmd                                1/1     Running   0             110s
metallb-system   speaker-kpzzq                                1/1     Running   0             111s
metallb-system   speaker-ncxcq                                1/1     Running   0             110s
metallb-system   speaker-qfnzf                                1/1     Running   0             110s
metallb-system   speaker-t9wgg                                1/1     Running   0             110s
```
Выполоняем базовую конфигурацию MetaLB:

```bash
deploy@lab12-kub-master-1:~$ kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
pod/controller-7d69cc69fd-258cc condition met
pod/speaker-bdcmd condition met
pod/speaker-kpzzq condition met
pod/speaker-ncxcq condition met
pod/speaker-qfnzf condition met
pod/speaker-t9wgg condition met
```

Создаем манифест для MetaLB, в котором описываем два типа:

- IPAddressPool - пул внешних IP. Задаем диапазон 192.168.70.155-192.168.70.160 из внешней для кластера сети
- L2Advertisement - сервис в рамках Layer 2 (ARP/NDP) Mode

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: prod-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.70.155-192.168.70.160 # actual unused network range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: prod-l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - prod-ip-pool
```

```bash
deploy@lab12-kub-master-1:~/metallb$ kubectl apply -f metallb-config.yaml
ipaddresspool.metallb.io/prod-ip-pool created
l2advertisement.metallb.io/prod-l2-advertisement created
```

### 3.2 Установка Ingress Controller

Установим Ingress Controller в качестве Load Balancer для подов кластера на базе Nginx. Для установки используем Helm, который предварительно установим:

```bash
deploy@lab12-kub-master-1:~$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
deploy@lab12-kub-master-1:~$ chmod 700 get_helm.sh
deploy@lab12-kub-master-1:~$ ./get_helm.sh
Downloading https://get.helm.sh/helm-v4.2.0-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm
deploy@lab12-kub-master-1:~$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
"ingress-nginx" has been added to your repositories
deploy@lab12-kub-master-1:~$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
Update Complete. ⎈Happy Helming!⎈
```

После установки Helm запустим установку Ingress Nginx:

```bash
deploy@lab12-kub-master-1:~$ helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
NAME: ingress-nginx
LAST DEPLOYED: Mon Jun  8 14:13:19 2026
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
It may take a few minutes for the load balancer IP to be available.
You can watch the status by running 'kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch'

An example Ingress that makes use of the controller:
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: nginx
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls

```

Теперь проверим трансляцию адресов между MetallB и Ingress контроллером:

```bash
deploy@lab12-kub-master-1:~$ kubectl get svc -n ingress-nginx ingress-nginx-controller
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.99.108.72   192.168.70.155   80:31669/TCP,443:30169/TCP   73s

```

Видно, что MetallB автоматически определил наличие Ingress контроллера и выполнил трансляцию внешнего адреса 192.168.70.155 во внутренний кластерный 10.99.108.72.


### 4. Разворачивание простого веб-приложения

Выполним деплой простейшего web-приложения, которое будет выдавать небольшой ответ при обращении к нему.

По аналогии, как было описано выше, создаем манифест с Deployment и Service. В качестве образа для нашего веб-приложения используем "nginxdemos/hello:plain-text" - легковесный Nginx сервер, используемый в качестве демонстрации работы бекенда.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

```

И манифест для Ingress-контроллера. Здесь указываем домен нашего веб-приложения "app.lab.local" - на основании него контроллер будет перенаправлять трафик на необходимый сервис и имя самого сервиса  "web-app-service"

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
spec:
  ingressClassName: nginx  
  rules:
  - host: app.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 80

```

Выполняем деплой:

```bash
deploy@lab12-kub-master-1:~/sample-app$ kubectl apply -f sample-app.yaml
deploy@lab12-kub-master-1:~/sample-app$ kubectl apply -f sample-ingress.yaml
```

Проверяем состояния запуска подов сервиса:

```bash
deploy@lab12-kub-master-1:~/sample-app$ kubectl get pods -l app=web-app
NAME                                  READY   STATUS    RESTARTS   AGE
web-app-deployment-65c865b5fb-bwlnd   1/1     Running   0          38s
web-app-deployment-65c865b5fb-nkdv6   1/1     Running   0          67s
```

С компьютера внешней сети делаем запрос на http://app.lab.local (предварительно записав в DNS соответствие доменного имени к IP)
и убеждаемся в получении корректного ответа от нашего приложения:

```bash
maksim@maksim-asus-tuf:~$ curl http://app.lab.local

Server address: 10.244.3.5:80
Server name: web-app-deployment-65c865b5fb-bwlnd
Date: 08/Jun/2026:16:14:16 +0000
URI: /
Request ID: 040fd6a83cc04ab1d05d7ab9a99fa872

```
Наш веб-сервер ответил, указав свой внутренний адрес в кластере и имя сервиса ("web-app-deployment-65c865b5fb-bwlnd"), которое соответствует имени сервиса в выводе подов сервиса.


### 5. Настройка бекапов кластера

#### 5.1 Стратегия бекапа

Общая стратегия бекапирования выглядит следующий образом:

1. Состояние кластера(состав и состояние подов, сервисов и пр) хранится в хранилище etcd - снапшот его состояния необходимо сделать, который можно будет использовать для восстановления состояние кластера
2. Деплой всех сервисов осуществляется в декларативном стиле - с использованием *.yaml манифестов, которые хранятся в актуальном состоянии в системе контроля версий и всегда могут быть развернуты заново.
3. Выполнение дампов namespace`ов кластера (команда kubectl get all --all-namespaces -o yaml ) - может быть полезным при анализе и развертывании кластера, однако не является инструментом бекапа - прямое восстановление кластера исходя из него невозможно.

#### 5.1 Бекап etcd

Для выполнения бекапов etcd установим стандартную утилиту etcd-client  на хост мастер-ноды. Несмотря на то, что etcd в Kubernetes запущен в контейнере, Kubernetes привязывает порт etcd (2379) к localhost машины и стандартные утилиты могут работать с etcd.  

```bash
deploy@lab12-kub-master-1:~$ sudo apt-get install etcd-client 
```

Для автоматизации создан небольшой скрипт, который выполняет снапшот etcd и помещает в  "/var/lib/etcd-backups" с датой выполнения снапшота.

```bash
#!/bin/bash

# Configuration
BACKUP_DIR="/var/lib/etcd-backups"
SNAPSHOT_FILE="${BACKUP_DIR}/etcd-snapshot-$(date +%Y-%m-%d-%H%M%S).db"

# Create backup directory if it doesn't exist
sudo mkdir -p ${BACKUP_DIR}

# Execute etcdctl snapshot using the cluster's internal certificates
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save ${SNAPSHOT_FILE}

# Verify the backup file integrity
sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status ${SNAPSHOT_FILE}

# Clean up backups older than 7 days to save disk space
sudo find ${BACKUP_DIR} -type f -name "etcd-snapshot-*.db" -mtime +7 -delete
```

Запустим выполнение снапшота: 
```bash
deploy@lab12-kub-master-1:~$ ./etcd_backup.sh
{"level":"info","ts":1781257799.3373735,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"/var/lib/etcd-backups/etcd-snapshot-2026-06-12-094959.db.part"}
{"level":"info","ts":"2026-06-12T09:49:59.342801Z","caller":"clientv3/maintenance.go:212","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1781257799.3437097,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-06-12T09:49:59.423844Z","caller":"clientv3/maintenance.go:220","msg":"completed snapshot read; closing"}
{"level":"info","ts":1781257799.532812,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"4.9 MB","took":0.195331536}
{"level":"info","ts":1781257799.5330355,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"/var/lib/etcd-backups/etcd-snapshot-2026-06-12-094959.db"}
Snapshot saved at /var/lib/etcd-backups/etcd-snapshot-2026-06-12-094959.db
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| a7498c83 |   880493 |       1395 |     4.9 MB |
+----------+----------+------------+------------+
```

Снапшот успешно выполнился и доступен в указанной папке:

```bash
deploy@lab12-kub-master-1:~$ ls /var/lib/etcd-backups/
etcd-snapshot-2026-06-12-094959.db
```
Далее данный снапшот может быть использован для воостановления etcd командой "etcdctl snapshot restore". Естественно подразумевается, что кластер должен быть остановлен systemctl stop kubelet.

```bash
systemctl stop kubelet
etcdctl snapshot restore
```

#### 5.1 Ymal-дамп кластера

Для получения yaml-дампа всех namespace кластера выполним команду  kubectl get all --all-namespaces -o yaml с указанием файла для записи "kub_dump.yaml"

```bash
kubectl get all --all-namespaces -o yaml >> kub_dump.yaml
```

В результате получаем файл, где в yaml отражено состояние и все манифесты кластера. Сам файл доступен в дереве проекта kub_dump/kub_dump.yaml

Как уже было сказано, это не явялется прямым бекапом кластера, но может быть полезно в качестве референса для проверки состояний/конфигураций при восстановлении кластера.


### Выводы:

В рамках данной работы было выполнено разворачивание отказоустойчивого высокодоступного кластера Kubernetes на bare-metall. Далее рассмотрен вопрос передачи внешнего трафика к запущенным сервисам в кластере - связка MetallB + Ingress контроллер. Выполнен запуск простого тестового бекенд -сервера для демонстарции работы. А также расммотрен вопрос бекапа кластера.  


