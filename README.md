# Mini Lakehouse

Локальный mini data lakehouse на Docker: MinIO (S3-хранилище) + PostgreSQL (метакаталог) + Iceberg REST Catalog + Trino (SQL-движок).

## Архитектура
                ┌─────────────┐
                │    Trino    │  ← SQL-запросы (порт 8080)
                │ (SQL engine)│
                └──────┬──────┘
                       │ REST API
                ┌──────▼──────┐
                │ iceberg-rest│  ← каталог Iceberg (порт 8181)
                └──────┬──────┘
                       │ JDBC
                ┌──────▼──────┐
                │  PostgreSQL │  ← метаданные таблиц (порт 5432)
                └─────────────┘
                       
                ┌─────────────┐
                │    MinIO    │  ← файлы Parquet (порт 9000/9001)
                │ (S3 storage)│
                └─────────────┘
            
**Как это работает:**
1. Trino получает SQL-запрос от пользователя.
2. Для операций с Iceberg-таблицами Trino обращается к `iceberg-rest` — сервису, реализующему Iceberg REST Catalog Spec.
3. `iceberg-rest` хранит метаданные о таблицах (схемы, снапшоты, версии) в PostgreSQL через JDBC.
4. Сами данные (файлы формата Parquet) физически хранятся в MinIO — S3-совместимом объектном хранилище.

## Стек

| Сервис | Образ | Назначение |
|---|---|---|
| MinIO | `minio/minio:latest` | S3-совместимое хранилище файлов |
| PostgreSQL | `postgres:15` | Хранение метаданных Iceberg-каталога |
| iceberg-rest | `tabulario/iceberg-rest:latest` | REST-каталог Iceberg (связывает Trino, PostgreSQL и MinIO) |
| Trino | `trinodb/trino:latest` | Распределённый SQL-движок |

## Порты

| Сервис | Порт | UI |
|---|---|---|
| MinIO API | 9000 | — |
| MinIO Console | 9001 | http://localhost:9001 (admin / password123) |
| PostgreSQL | 5432 | — |
| iceberg-rest | 8181 | — |
| Trino | 8080 | http://localhost:8080 |

## Запуск

```bash
git clone <ссылка-на-репозиторий>
cd mini-lakehouse
docker-compose up -d
```

Проверить, что все сервисы работают:

```bash
docker ps
```

Все 4 контейнера должны быть в статусе `Up`.

## Проверка работы (health-check)

```bash
# MinIO
curl http://localhost:9000/minio/health/live

# iceberg-rest
docker logs iceberg-rest --tail 20

# Trino (должно быть SERVER STARTED в логах)
docker logs trino --tail 20

# PostgreSQL
docker exec -it postgres psql -U iceberg -d iceberg_catalog -c "\dt"
```

## Пример работы с данными

Подключение к Trino:

```bash
docker exec -it trino trino
```

Создание схемы и таблицы:

```sql
CREATE SCHEMA iceberg.warehouse;

CREATE TABLE iceberg.warehouse.orders (
    order_id BIGINT,
    customer_name VARCHAR,
    amount DECIMAL(10,2),
    order_date DATE
) WITH (format = 'PARQUET');
```

Вставка и выборка данных:

```sql
INSERT INTO iceberg.warehouse.orders VALUES
    (1, 'Иван Иванов', 1500.50, DATE '2026-07-01');

SELECT * FROM iceberg.warehouse.orders;
```

JOIN двух таблиц:

```sql
SELECT o.order_id, o.customer_name, o.amount, s.status
FROM iceberg.warehouse.orders o
JOIN iceberg.warehouse.order_status s ON o.order_id = s.order_id;
```

Time Travel — просмотр состояния таблицы в прошлом:

```sql
-- список версий (снапшотов) таблицы
SELECT * FROM iceberg.warehouse."orders$snapshots";

-- состояние на конкретный снапшот
SELECT * FROM iceberg.warehouse.orders FOR VERSION AS OF <snapshot_id>;

-- состояние на конкретный момент времени
SELECT * FROM iceberg.warehouse.orders FOR TIMESTAMP AS OF TIMESTAMP '2026-07-14 09:39:49 UTC';
```

## Известные нюансы

- В используемой версии Trino (482) есть баг с автоматическим созданием служебных таблиц при прямом JDBC-подключении к Iceberg (см. [trinodb/trino#20419](https://github.com/trinodb/trino/issues/20419)). Поэтому вместо `iceberg.catalog.type=jdbc` используется `iceberg.catalog.type=rest` через отдельный сервис `iceberg-rest`, который не подвержен этому багу.
- Bucket `warehouse` в MinIO нужно создать вручную перед первым `CREATE TABLE` (автоматическое создание bucket в текущей связке REST-каталога не работает).

## Автор

[]