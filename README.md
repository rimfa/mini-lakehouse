# Mini Lakehouse

Локальный data lakehouse на Docker для разработки и тестирования аналитических пайплайнов.
Поднимает production-grade инфраструктуру на локальном компьютере — без облака и платных лицензий.

Предметная область: сервис доставки еды по Мытищам.

## Стек

| Компонент | Версия | Назначение |
|---|---|---|
| Apache Iceberg | 1.x | ACID table format, Time Travel |
| Trino | 482 | Распределённый SQL-движок |
| MinIO | latest | S3-совместимое объектное хранилище |
| PostgreSQL | 15 | Метаданные Iceberg-каталога |
| iceberg-rest | latest | REST Catalog (связывает Trino и PostgreSQL) |

## Архитектура
```
QUERIES: Trino SQL · Time Travel · Analytics
+------------------+
|      TRINO       |  :8080
|   (SQL engine)   |
+--------+---------+
| REST API
+--------+---------+
|   iceberg-rest   |  :8181
|  (REST catalog)  |
+--------+---------+
| JDBC
+--------+---------+
|    PostgreSQL    |  :5432
| (catalog meta)   |
+------------------+
+------------------+
|      MinIO       |  :9000 / :9001
|   (S3 storage)   |
|                  |
|  s3://warehouse/ |
|  +-- delivery/   |  <- Bronze
|  +-- gold/       |  <- Gold
+------------------+
```
**Как это работает:**
1. Trino получает SQL-запрос и обращается к iceberg-rest за метаданными таблиц
2. iceberg-rest хранит метаданные (схемы, снапшоты, партиции) в PostgreSQL
3. Trino читает Parquet-файлы напрямую из MinIO по S3 API

**Почему iceberg-rest вместо прямого JDBC:**
В Trino 482 есть баг — при прямом JDBC-подключении к Iceberg служебные таблицы каталога не создаются автоматически ([issue #20419](https://github.com/trinodb/trino/issues/20419)). REST-каталог решает эту проблему и является более современным стандартом.

## Порты

| Сервис | Порт | UI |
|---|---|---|
| MinIO API | 9000 | — |
| MinIO Console | 9001 | http://localhost:9001 |
| PostgreSQL | 5432 | — |
| iceberg-rest | 8181 | — |
| Trino | 8080 | http://localhost:8080 |

MinIO: `admin` / `password123`

## Быстрый старт

```bash
git clone https://github.com/rimfa/mini-lakehouse
cd mini-lakehouse
docker-compose up -d
```

Проверить что все сервисы запущены:

```bash
docker ps
```

Должно быть 4 контейнера в статусе `Up`: minio, postgres, iceberg-rest, trino.

**Важно:** перед первым запуском создай bucket в MinIO Console (http://localhost:9001) с именем `warehouse`.

## Данные

### Структура слоёв

**Bronze** (`iceberg.delivery`) — операционные данные:

| Таблица | Описание | Партиция |
|---|---|---|
| `orders` | Заказы | day(created_at) |
| `couriers` | Курьеры | — |
| `order_status_history` | История статусов | day(changed_at) |

**Gold** (`iceberg.gold`) — аналитические витрины:

| Таблица | Описание |
|---|---|
| `orders_summary` | Количество и сумма заказов по статусам |
| `courier_workload` | Загруженность курьеров |
| `delivery_time` | Среднее время доставки по ресторанам |

### SQL-скрипты

| Файл | Описание |
|---|---|
| `sql/01_create_tables.sql` | Создание схем и таблиц |
| `sql/02_insert_data.sql` | Загрузка тестовых данных |
| `sql/03_analytics.sql` | Gold-витрины и аналитические запросы |

## Работа с данными

Подключение к Trino:

```bash
docker exec -it trino trino
```

Сводка по заказам:

```sql
SELECT * FROM iceberg.gold.orders_summary;
```

Загруженность курьеров:

```sql
SELECT * FROM iceberg.gold.courier_workload;
```

Среднее время доставки:

```sql
SELECT * FROM iceberg.gold.delivery_time;
```

JOIN заказов с курьерами:

```sql
SELECT o.order_id, o.customer_name, o.status,
       c.full_name AS courier, o.amount
FROM iceberg.delivery.orders o
JOIN iceberg.delivery.order_status_history h ON o.order_id = h.order_id
JOIN iceberg.delivery.couriers c ON h.courier_id = c.courier_id
WHERE h.status = 'доставлен'
GROUP BY o.order_id, o.customer_name, o.status, c.full_name, o.amount;
```

Time Travel:

```sql
-- список снапшотов
SELECT snapshot_id, committed_at, operation
FROM iceberg.delivery."orders$snapshots";

-- состояние на конкретный снапшот
SELECT * FROM iceberg.delivery.orders FOR VERSION AS OF <snapshot_id>;
```

## Health-check

```bash
# MinIO
curl http://localhost:9000/minio/health/live

# Trino
docker logs trino --tail 20

# iceberg-rest
docker logs iceberg-rest --tail 20

# PostgreSQL
docker exec -it postgres psql -U iceberg -d iceberg_catalog -c "\dt"
```
