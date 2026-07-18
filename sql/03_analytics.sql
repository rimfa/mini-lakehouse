-- Gold слой: сводка по заказам
CREATE TABLE IF NOT EXISTS iceberg.gold.orders_summary AS
SELECT
    status,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_check
FROM iceberg.delivery.orders
GROUP BY status;

-- Gold слой: загруженность курьеров
CREATE TABLE IF NOT EXISTS iceberg.gold.courier_workload AS
SELECT
    c.courier_id,
    c.full_name,
    COUNT(h.order_id) AS order_count,
    COUNT(CASE WHEN o.status = 'доставлен' THEN 1 END) AS delivered_count
FROM iceberg.delivery.couriers c
LEFT JOIN iceberg.delivery.order_status_history h ON c.courier_id = h.courier_id
LEFT JOIN iceberg.delivery.orders o ON h.order_id = o.order_id
GROUP BY c.courier_id, c.full_name;

-- Gold слой: среднее время доставки
CREATE TABLE IF NOT EXISTS iceberg.gold.delivery_time AS
SELECT
    customer_name AS restaurant,
    AVG(date_diff('minute', created_at, delivered_at)) AS avg_delivery_minutes,
    COUNT(*) AS total_orders
FROM iceberg.delivery.orders
WHERE delivered_at IS NOT NULL
GROUP BY customer_name;

-- JOIN: заказы с курьерами
SELECT
    o.order_id,
    o.customer_name,
    o.status,
    c.full_name AS courier,
    o.amount
FROM iceberg.delivery.orders o
JOIN iceberg.delivery.order_status_history h ON o.order_id = h.order_id
JOIN iceberg.delivery.couriers c ON h.courier_id = c.courier_id
WHERE h.status = 'доставлен'
GROUP BY o.order_id, o.customer_name, o.status, c.full_name, o.amount;

-- Time Travel: список снапшотов
SELECT snapshot_id, committed_at, operation
FROM iceberg.delivery."orders$snapshots";

-- Time Travel: состояние таблицы на первый снапшот (пустая)
-- SELECT * FROM iceberg.delivery.orders FOR VERSION AS OF <snapshot_id>;
