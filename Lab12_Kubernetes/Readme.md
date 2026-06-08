
```bash
deploy@lab12-kub-master-1:~$ kubectl get nodes
NAME                 STATUS   ROLES           AGE     VERSION
lab12-kub-master-1   Ready    control-plane   4h42m   v1.36.1
lab12-kub-master-2   Ready    control-plane   73m     v1.36.1
lab12-kub-master-3   Ready    control-plane   73m     v1.36.1
lab12-kub-worker-1   Ready    <none>          6m46s   v1.36.1
lab12-kub-worker-2   Ready    <none>          6m46s   v1.36.1
```


Test Nginx


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

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl apply -f nginx-test.yaml
deployment.apps/nginx-deployment created
service/nginx-service created
```

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE     IP           NODE                 NOMINATED NODE   READINESS GATES
nginx-deployment-cd54446c4-4grlk   1/1     Running   0          2m56s   10.244.4.2   lab12-kub-worker-2   <none>           <none>
nginx-deployment-cd54446c4-sp9zd   1/1     Running   0          2m56s   10.244.3.2   lab12-kub-worker-1   <none>           <none>
```


Verify that your internal load-balancing Service (ClusterIP) was created:

```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get service nginx-service
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx-service   ClusterIP   10.105.217.88   <none>        80/TCP    5m1s
```
This virtual IP abstracts the pods, routing traffic to either worker node seamlessly.


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

Flannel CNI is successfully routing traffic between your virtual machines


```bash
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl delete -f nginx-test.yaml
deployment.apps "nginx-deployment" deleted from default namespace
service "nginx-service" deleted from default namespace
deploy@lab12-kub-master-1:~/kub_deploy$ kubectl get pods -o wide
No resources found in default namespace.
```

##################################################################################################

MetaLB

Deploy the native MetalLB manifest using the following command:
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
Proceeding with configuration
```bash
deploy@lab12-kub-master-1:~$ kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
pod/controller-7d69cc69fd-258cc condition met
pod/speaker-bdcmd condition met
pod/speaker-kpzzq condition met
pod/speaker-ncxcq condition met
pod/speaker-qfnzf condition met
pod/speaker-t9wgg condition met
```

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

Ingress Controller as a Load Balancer

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
deploy@lab12-kub-master-1:~$ kubectl get svc -n ingress-nginx ingress-nginx-controller
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.99.108.72   192.168.70.155   80:31669/TCP,443:30169/TCP   73s
```
###############################


##### TEST WEB APPP ################################33

sample-app.yaml

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

sample-ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
spec:
  ingressClassName: nginx  # This replaces the deprecated annotation
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


```bash
deploy@lab12-kub-master-1:~/sample-app$ kubectl apply -f sample-app.yaml
deploy@lab12-kub-master-1:~/sample-app$ kubectl apply -f sample-ingress.yaml
```

```bash
deploy@lab12-kub-master-1:~/sample-app$ kubectl get pods -l app=web-app
NAME                                  READY   STATUS    RESTARTS   AGE
web-app-deployment-65c865b5fb-bwlnd   1/1     Running   0          38s
web-app-deployment-65c865b5fb-nkdv6   1/1     Running   0          67s
```

```bash
maksim@maksim-asus-tuf:~$ curl http://app.lab.local
Server address: 10.244.3.5:80
Server name: web-app-deployment-65c865b5fb-bwlnd
Date: 08/Jun/2026:16:14:16 +0000
URI: /
Request ID: 040fd6a83cc04ab1d05d7ab9a99fa872

```
#####################3##

