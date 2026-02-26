# Балансировка веб-приложения

## Цель

* Научиться использовать Nginx(Angie) в качестве балансировщика для веб-приложений;
* Получить рабочий пример настройки Nginx(Angie) с базовой отказоустойчивостью бэкенда;

## Задание

1ю развернуть 4 виртуальных машины терраформом в Яндекс.Облаке или на локальном стенде;
  * Одна  ВМ - Nginx-балансировщик с публичным IP адресом. Показать конфигурацию для балансировки методами round-robin и hash (выбор переменных  самостоятельный);
  *  Две ВМ - Nginx-фронтенд со статикой и бэкенд на выбор студента. В качестве бэкенда может использовать любой отладочный контейнер (образ vscoder/webdebugger) или заглушку;
   задание со звездочкой* в качестве бэкенда использовать полноценную CMS (Wordpress, Joomla, Drupal, MediaWiki или любое на стеке Uwsgi/Unicorn/PHP-FPM/Java) и запустить виртуалку с одним экземпляром БД для работы с бэкендами.


## Решение

В данной работе для разворачивания инфраструктуры будем  использовать локальный стенд Proxmox.

Развернем стенд на базе СMS WordPress в количестве 5ти виртуальных машин. В составе:

* Балансировщик на базе Angie - 1 ВМ
* Бэкенд: WordPress + Nginx с использованием протокола fastcgi между ними- 3 ВМ
* База данных MySql и NFS хранилище для общих файлов WordPress - 1 ВМ

Для лучшего понимания графическая схема стенда представлена ниже.

![](/Lab03_WebLoadBalancing/pics/Lab03_diagramm.jpg)

#### Виртуальные машины в Proxmox:

![](/Lab03_WebLoadBalancing/pics/ProxomoxLab03.png)

Для развертывания виртуальных машин в Proxmox использован Terraform. Проект Terraform для данного стенда представлен в соответствующем каталоге данной работы. Каких-либо особенностей не имеет - останавливаться детально на описании не будем. 

Отметим лишь сетевую структуру и организацию общего хранилища файлов. В качестве белого внешнего IP использован IP 192.168.70.11 из адаптера vmbr0, который имеет выход в общую сеть в т.ч Интернет. А для связи балансировщик - бекенды и  бекэнды - база данных + общее хранилище используются соответствующие "host only" адаптеры, имитируя реальную сетевую инфраструктуру.

В качестве общего хранилища файлов для WordPress (чтобы каждый бекенд имеел доступ к одним и тем же файлам и был равнозначен) используется NFS, сервер которой развернут на ВМ с БД, а каждый бекенд является клиентом NFS и на нем примонтирован соответствующий каталог. 

#### Настройка машин с использованием Ansblie.

Для настройки всех машин использован Ansible, основной плейбук представлен ниже:

<details>
  <summary>main.yaml</summary>

  ```bash
  - name: Provision database machine
  hosts: database
  become: true
  roles:
        - role: mysql-wordpress
        - role: nfs-server

- name: Provision backend machines
  hosts: backend2,backend3
  become: true
  roles:
        - role: nfs-client
        - role: wordpress       

- name: Provision load balancer machine
  hosts: loadbalancer
  become: true
  roles:
        - role: angie-lb
  ```                   
</details>  

Последовательно выполняется настройка узлов:

* 1-ая ВМ: БД (MySQL c настройкой под WP) и NFS сервер
* 2-4 машины: WordPress +  NFS клиент
* 5 -ая машина: балансировщик  на базе Angie

Весь проект Ansible c ролями представлен в соответствующем каталоге работы. Отдельно описывать каждую роль не будем, опишем и проверим работу балансировщика, что и является основной целью данной работы. 


Страница WordPress пор итогу разворачивания стенда:

![](/Lab03_WebLoadBalancing/pics/Wordpress_samplepage.png)

Конфигурация балансировщика Angie приведена ниже:

<details>
  <summary>default.conf.j2</summary>

  ````bash
  {% if 'hash_balancing' in ansible_run_tags %}

  upstream backend {
    zone backend 1m;
    hash $remote_addr consistent;
    server  {{ ip_server_backend1 }}:8080 max_fails=3 fail_timeout=30s;
    server  {{ ip_server_backend2 }}:8080 max_fails=3 fail_timeout=30s;
    server  {{ ip_server_backend3 }}:8080 max_fails=3 fail_timeout=30s;  

   }  

{% else %}

upstream backend {
    zone backend 1m;
    server  {{ ip_server_backend1 }}:8080 max_fails=3 fail_timeout=30s;
    server  {{ ip_server_backend2 }}:8080 max_fails=3 fail_timeout=30s;
    server  {{ ip_server_backend3 }}:8080 max_fails=3 fail_timeout=30s;
}

{% endif %}


server {
    listen       80;
    server_name  localhost;
    status_zone single;

    #access_log  /var/log/angie/host.access.log  main;

    location / {
        #root   /usr/share/angie/html;
        #index  index.html index.htm;
        proxy_pass http://backend;
    }

    location /status/ {
        api     /status/;
        allow   127.0.0.1;
        deny    all;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/angie/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with angie's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}

    location /console/ {

    
    allow 192.168.0.0/16;
    deny all;

    auto_redirect on;

    alias /usr/share/angie-console-light/html/;
    # Только во FreeBSD:
    # alias /usr/local/www/angie-console-light/html/;
    index index.html;

    location /console/api/ {
        api /status/;
    }

}
}


  ````
</details>  

Доступны два вида балансировки: round-robin (основная), а также hash балансировка, основанная на определении соответствия клиента серверу при помощи хэшированного значения ключа. В данном случае использован директива $remote_addr, которая распределяет клиентов на базе хешированного значения IP адреса клиента. Т.е. клиенты из одной подсети будут попадать на один бэк-сервер.

Для определения конфигурации использован шаблон с привязкой к тегу, чтобы можно было определить тип балансировки во время разворачивания с использованием значения тега. Например, как указано в команде ниже.

```bash
 ansible-playbook playbooks/main.yaml --ask-become-pass --limit loadbalancer --tag "configure" --tag "hash_balancing"
```

#### Тестирование 

Проведем тестирование нагрузки 2000+ запросов с использованием балансировки round robin. Для имитации нагрузки будем использовать запросы curl из консоли в цикле, а для объективного контроля панель Angie.

![](/Lab03_WebLoadBalancing/pics/CurlTestMassive_RoundRobin.png)

![](/Lab03_WebLoadBalancing/pics/AngieConsole_roundRobin.png)


Видим, что как и ожидалось, запросы распределяются строго равномерно между каждым из трех бекендов. Скорость обработки запросов 6 з/с для каждого из серверов.

Проведем пробное тестирование с использованием балансировки hash:

![](/Lab03_WebLoadBalancing/pics/AngieConsole_HashBalancing1.png)

![](/Lab03_WebLoadBalancing/pics/AngieConsole_HashBalancing2.png)

Здесь ожидаемо запросы с одного ПК приходят только на один сервер (запросы с ПК с IP 192.168.40.x и IP 192.168.50.x  приходят только на 1ый сервер). При выполнении запроса с устройства из  подсети  192.168.9.x уже приходят уже на 3-ый сервер. 
Таким образом, хэш балансировка работает равномерно при естественном условии равномерного распределения приходящих IP адресов в рамках общего кол-ва. При запросах с преимущественно одного адреса или близкой подсети балансировка может перегружать один из серверов, с простоем оставшихся. 
 
#### Выводы

В данной работе рассмотрены базовые типы балансировки бэк-серверов на базе балансировщика Angie. Собран тестовый стенд с соответствующей инфраструктурой, близкой к реальной. 
Показан работа двух типов балансировки: основная и самая базовая, т.н. round-robin, обеспечивающая полностью равномерное распределение запросов между серверами (с возможностью задания т.н. "весов"). 
А также hash - балансировки с использованием в качестве хешируемого параметра IP адрес клиента. Данная балансировка обеспечивает загрузку серверов на основании приходящих IP адресов.
Каждый тип балансировки имеет свои достоинства и недостатки, стоит отметь важность предварительного анализа предполагаемого характера нагрузки и располагаемой архитектуры и инфраструктуры. Также стоит отметить крайнюю важность наличия мониторинга для контроля и оценки работы и равномерности загрузки системы.   
