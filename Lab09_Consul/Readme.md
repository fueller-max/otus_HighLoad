# Consul cluster для service discovery и DNS

## Цель

1. Настроить Consul cluster для управления DNS-записями веб-портала;
2. Реализовать отказоустойчивую балансировку нагрузки через DNS вместо плавающего IP

## Задание

1. Разверните кластер Consul (минимум 3 сервера и 1 клиент).
2. Зарегистрируйте веб-портал, реализованный в предыдущем задании, как сервис в Consul.
3. Настройте DNS через Consul так, чтобы доменное имя веб-портала разрешалось в IP-адреса его работающих инстансов.
4. Отключите использование плавающего IP — используйте DNS Consul для балансировки трафика.
5. Проверьте, что при падении одного из веб-серверов его IP больше не выдается в DNS-ответе.


## Решение

Внешний трафик → Внешний LB (HAProxy) → Балансировщики (Nginx) → Бэкенды
                           ↑                            ↑
                Consul API / Health Checks     Consul Service Discovery


1. Клиент отправляет запрос на внешний балансировщик (HAProxy).
2. Внешний LB через Consul API получает список здоровых балансировщиков Nginx.
3. Внешний LB направляет запрос на один из доступных балансировщиков.
4. Балансировщик Nginx через Consul получает список здоровых бэкендов.
5. Nginx проксирует запрос на один из бэкендов.
6. Бэкенд обрабатывает запрос и возвращает ответ.
7. Ответ проходит по цепочке обратно к клиенту.


```bash
deploy@lab09-consul-srv1:/etc/consul.d$ sudo consul members
Node               Address           Status  Type    Build   Protocol  DC   Partition  Segment
lab09-consul-srv1  10.10.20.91:8301  alive   server  1.22.6  2         dc1  default    <all>
lab09-consul-srv2  10.10.20.92:8301  alive   server  1.22.6  2         dc1  default    <all>
lab09-consul-srv3  10.10.20.93:8301  alive   server  1.22.6  2         dc1  default    <all>

deploy@lab09-consul-srv1:/etc/consul.d$ sudo consul operator raft list-peers
Node               ID                                    Address           State     Voter  RaftProtocol  Commit Index  Trails Leader By
lab09-consul-srv1  8eb7b3b5-1574-156e-3696-8a93822473d3  10.10.20.91:8300  leader    true   3             108           -
lab09-consul-srv3  ae3a20d8-5196-003d-f192-54724f85fe2b  10.10.20.93:8300  follower  true   3             108           0 commits
lab09-consul-srv2  3ef46df0-53a8-d226-f026-1da7d77b9a35  10.10.20.92:8300  follower  true   3             108           0 commits
deploy@lab09-consul-srv1:/etc/consul.d$ curl http://127.0.0.1:8500/v1/status/leader
"10.10.20.91:8300"
```

```bash
deploy@lab09-consul-srv1:~$ consul catalog services
backend
consul
load_balancer
deploy@lab09-consul-srv1:~$ dig @127.0.0.1 -p 8600 load_balancer.service.consul A +short
192.168.70.41
192.168.70.42
deploy@lab09-consul-srv1:~$ dig @127.0.0.1 -p 8600 backend.service.consul A +short
10.10.20.44
10.10.20.45
10.10.20.43

```

```bash
// ------- consul zone ---------------------------
// Forward to Consul cluster
zone "consul" IN {
    type forward;
    forward only;
    forwarders {
        192.168.70.91 port 8600;  # serv_1 Consul
        192.168.70.92 port 8600;  # serv_2 Consul
        192.168.70.93 port 8600;  # serv_3 Consul
    };
};
// ---------------------------------------------

```

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64989
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.42
load_balancer.service.consul. 0	IN	A	192.168.70.41

;; Query time: 5 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:45:25 MSK 2026
;; MSG SIZE  rcvd: 89

```

Тест отключание балансировщика 

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49459
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.41

;; Query time: 8 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:50:33 MSK 2026
;; MSG SIZE  rcvd: 73

```

```bash
deploy@lab04-load-balancer-2:~$ sudo systemctl stop angie

```

Включение 

```bash
maksim@maksim-asus-tuf:~$ dig load_balancer.service.consul

; <<>> DiG 9.18.39-0ubuntu0.24.04.3-Ubuntu <<>> load_balancer.service.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1361
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;load_balancer.service.consul.	IN	A

;; ANSWER SECTION:
load_balancer.service.consul. 0	IN	A	192.168.70.41
load_balancer.service.consul. 0	IN	A	192.168.70.42

;; Query time: 6 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Mon Apr 20 11:53:10 MSK 2026
;; MSG SIZE  rcvd: 89

```

Template:

```bash

```


```bash
deploy@lab04-backend3:~$ sudo systemctl stop nginx

```

``` bash
upstream backend {
    zone backend 1m;

    server  10.10.20.43:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.44:8080 max_fails=3 fail_timeout=30s;

}

```

```bash
deploy@lab04-backend3:~$ sudo systemctl start nginx

```

```bash
upstream backend {
    zone backend 1m;

    server  10.10.20.43:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.44:8080 max_fails=3 fail_timeout=30s;

    server  10.10.20.45:8080 max_fails=3 fail_timeout=30s;

}


```

```bash


angie: the configuration file /etc/angie/angie.conf syntax is ok
angie: configuration file /etc/angie/angie.conf test is successful
angie: the configuration file /etc/angie/angie.conf syntax is ok
angie: configuration file /etc/angie/angie.conf test is successful

```