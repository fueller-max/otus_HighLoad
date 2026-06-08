
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