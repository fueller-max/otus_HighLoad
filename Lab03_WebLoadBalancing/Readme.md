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

В данной работе для разворачивания инфраструктуры будем1/ использовать локальный стенд Proxmox.

Развернем стенд на базе СMS WordPress в количестве 5ти виртуальных машин. В составе:

* Балансировщик на базе Angie - 1 ВМ
* Бэкенд: WordPress + Nginx с использованием протокола fastcgi между ними- 3 ВМ
* База данных MySql и NFS хранилище для общих файлов - 1 ВМ

Для лучшего понимания графическая схема стенда представлена ниже.



Виртуальные машины в Proxmox:

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/ProxomoxLab03.png)

Страница WordPress

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/Wordpress_samplepage.png)


Тестирование нагрузки 2000+ запросов с использованием балансировки round robin:

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/CurlTestMassive_RoundRobin.png)

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/AngieConsole_roundRobin.png)

Тестирование с использованием балансировки hash:

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/AngieConsole_HashBalancing1.png)

![](/otus_HighLoad/Lab03_WebLoadBalancing/pics/AngieConsole_HashBalancing2.png)




```bash
maksim@maksim-asus-tuf:~/otus/labs/Lab03_WebBalancing/ansible$ ansible-playbook playbooks/main.yaml --ask-become-pass --limit loadbalancer --tag "configure" --tag "hash_balancing"
```



<details>
  <summary>text</summary>
</details>  

