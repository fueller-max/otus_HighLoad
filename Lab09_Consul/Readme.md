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