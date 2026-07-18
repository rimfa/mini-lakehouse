-- Создание схем
CREATE SCHEMA IF NOT EXISTS iceberg.delivery;
CREATE SCHEMA IF NOT EXISTS iceberg.gold;

-- Bronze слой: таблица заказов
CREATE TABLE IF NOT EXISTS iceberg.delivery.orders (
    order_id BIGINT,
    customer_name VARCHAR,
    pickup_address VARCHAR,
    delivery_address VARCHAR,
    amount DECIMAL(10,2),
    status VARCHAR,
    created_at TIMESTAMP,
    delivered_at TIMESTAMP
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['day(created_at)']
);

-- Bronze слой: таблица курьеров
CREATE TABLE IF NOT EXISTS iceberg.delivery.couriers (
    courier_id BIGINT,
    full_name VARCHAR,
    phone VARCHAR,
    status VARCHAR
) WITH (
    format = 'PARQUET'
);

-- Bronze слой: история статусов
CREATE TABLE IF NOT EXISTS iceberg.delivery.order_status_history (
    status_id BIGINT,
    order_id BIGINT,
    courier_id BIGINT,
    status VARCHAR,
    changed_at TIMESTAMP
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['day(changed_at)']
);
