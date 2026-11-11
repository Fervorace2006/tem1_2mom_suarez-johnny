-- Pregunta 2. Auditoría de calidad e integridad de datos

USE superstore;

SELECT COUNT(*)                              AS total_registros,
       COUNT(DISTINCT row_id)                AS row_id_distintos,
       COUNT(*) - COUNT(DISTINCT row_id)     AS row_id_duplicados,
       COUNT(DISTINCT order_id)              AS ordenes_unicas,
       COUNT(DISTINCT customer_id)           AS clientes_unicos,
       COUNT(DISTINCT product_id)            AS productos_unicos,
       MIN(order_date)                       AS primera_fecha,
       MAX(order_date)                       AS ultima_fecha
FROM ventas;

SELECT
  SUM(IF(row_id        IS NULL, 1, 0))                         AS null_row_id,
  SUM(IF(order_id      IS NULL OR order_id      = '', 1, 0))   AS null_order_id,
  SUM(IF(order_date    IS NULL, 1, 0))                         AS null_order_date,
  SUM(IF(ship_date     IS NULL, 1, 0))                         AS null_ship_date,
  SUM(IF(ship_mode     IS NULL OR ship_mode     = '', 1, 0))   AS null_ship_mode,
  SUM(IF(customer_id   IS NULL OR customer_id   = '', 1, 0))   AS null_customer_id,
  SUM(IF(customer_name IS NULL OR customer_name = '', 1, 0))   AS null_customer_name,
  SUM(IF(segment       IS NULL OR segment       = '', 1, 0))   AS null_segment,
  SUM(IF(city          IS NULL OR city          = '', 1, 0))   AS null_city,
  SUM(IF(state         IS NULL OR state         = '', 1, 0))   AS null_state,
  SUM(IF(postal_code   IS NULL OR postal_code   = '', 1, 0))   AS null_postal_code,
  SUM(IF(region        IS NULL OR region        = '', 1, 0))   AS null_region,
  SUM(IF(product_id    IS NULL OR product_id    = '', 1, 0))   AS null_product_id,
  SUM(IF(category      IS NULL OR category      = '', 1, 0))   AS null_category,
  SUM(IF(sub_category  IS NULL OR sub_category  = '', 1, 0))   AS null_sub_category,
  SUM(IF(product_name  IS NULL OR product_name  = '', 1, 0))   AS null_product_name,
  SUM(IF(sales         IS NULL, 1, 0))                         AS null_sales,
  SUM(IF(quantity      IS NULL, 1, 0))                         AS null_quantity,
  SUM(IF(discount      IS NULL, 1, 0))                         AS null_discount,
  SUM(IF(profit        IS NULL, 1, 0))                         AS null_profit
FROM ventas;

SELECT
  SUM(IF(UNIX_TIMESTAMP(order_date, 'M/d/yyyy') IS NULL, 1, 0)) AS order_date_no_parseable,
  SUM(IF(UNIX_TIMESTAMP(ship_date,  'M/d/yyyy') IS NULL, 1, 0)) AS ship_date_no_parseable,
  SUM(IF(FROM_UNIXTIME(UNIX_TIMESTAMP(order_date,'M/d/yyyy'),'M/d/yyyy') <> order_date, 1, 0)) AS order_date_inconsistente,
  SUM(IF(FROM_UNIXTIME(UNIX_TIMESTAMP(ship_date, 'M/d/yyyy'),'M/d/yyyy') <> ship_date,  1, 0)) AS ship_date_inconsistente
FROM stg_superstore_raw;

SELECT
  SUM(IF(sales <= 0, 1, 0))                          AS ventas_cero_o_negativas,
  SUM(IF(discount < 0 OR discount > 1, 1, 0))        AS descuento_fuera_0_1,
  SUM(IF(discount > 0.8, 1, 0))                      AS descuento_mayor_80pct,
  SUM(IF(quantity <= 0, 1, 0))                       AS cantidad_invalida,
  SUM(IF(ship_date < order_date, 1, 0))              AS envio_antes_de_pedido,
  SUM(IF(order_year NOT BETWEEN 2014 AND 2017, 1, 0)) AS fuera_de_periodo,
  MIN(days_to_ship)                                  AS min_dias_envio,
  MAX(days_to_ship)                                  AS max_dias_envio,
  MIN(discount)                                      AS min_descuento,
  MAX(discount)                                      AS max_descuento
FROM ventas;

SELECT 'product_id con >1 nombre' AS verificacion, COUNT(*) AS casos
FROM (SELECT product_id FROM ventas GROUP BY product_id HAVING COUNT(DISTINCT product_name) > 1) a
UNION ALL
SELECT 'product_name con >1 id', COUNT(*)
FROM (SELECT product_name FROM ventas GROUP BY product_name HAVING COUNT(DISTINCT product_id) > 1) b
UNION ALL
SELECT 'customer_id con >1 nombre', COUNT(*)
FROM (SELECT customer_id FROM ventas GROUP BY customer_id HAVING COUNT(DISTINCT customer_name) > 1) c
UNION ALL
SELECT 'order_id con >1 fecha o cliente', COUNT(*)
FROM (SELECT order_id FROM ventas GROUP BY order_id
      HAVING COUNT(DISTINCT order_date) > 1 OR COUNT(DISTINCT customer_id) > 1) d;

SELECT product_id, COUNT(DISTINCT product_name) AS nombres,
       CONCAT_WS(' | ', COLLECT_SET(product_name)) AS variantes
FROM ventas
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
ORDER BY product_id
LIMIT 5;

WITH t AS (
  SELECT
    COUNT(*)                                        AS total,
    COUNT(*) - COUNT(DISTINCT row_id)               AS dup_row_id,
    COUNT(DISTINCT order_id)                        AS ordenes,
    COUNT(DISTINCT customer_id)                     AS clientes,
    SUM(IF(row_id IS NULL OR order_id IS NULL OR order_date IS NULL OR ship_date IS NULL
        OR customer_id IS NULL OR product_id IS NULL OR sales IS NULL OR quantity IS NULL
        OR discount IS NULL OR profit IS NULL, 1, 0)) AS filas_con_null,
    SUM(IF(order_date IS NULL OR ship_date IS NULL
        OR order_year NOT BETWEEN 2014 AND 2017, 1, 0)) AS fechas_invalidas,
    SUM(IF(sales <= 0, 1, 0))                       AS ventas_no_positivas,
    SUM(IF(discount < 0 OR discount > 1, 1, 0))     AS descuento_fuera_rango,
    SUM(IF(ship_date < order_date, 1, 0))           AS envio_antes_pedido,
    SUM(IF(profit < 0, 1, 0))                       AS lineas_con_perdida
  FROM ventas
),
dim AS (
  SELECT COUNT(*) AS prod_multi_nombre
  FROM (SELECT product_id FROM ventas GROUP BY product_id
        HAVING COUNT(DISTINCT product_name) > 1) x
),
resumen AS (
  SELECT 1 AS orden, 'Total de registros'                 AS indicador, total                 AS valor, 'INFO' AS tipo FROM t
  UNION ALL SELECT 2,  'Row ID duplicados',                  dup_row_id,            'REGLA' FROM t
  UNION ALL SELECT 3,  'Ordenes unicas',                     ordenes,               'INFO'  FROM t
  UNION ALL SELECT 4,  'Clientes unicos',                    clientes,              'INFO'  FROM t
  UNION ALL SELECT 5,  'Filas con NULL en campos clave',     filas_con_null,        'REGLA' FROM t
  UNION ALL SELECT 6,  'Fechas invalidas o fuera de periodo',fechas_invalidas,      'REGLA' FROM t
  UNION ALL SELECT 7,  'Ventas <= 0',                        ventas_no_positivas,   'REGLA' FROM t
  UNION ALL SELECT 8,  'Descuento fuera de [0,1]',           descuento_fuera_rango, 'REGLA' FROM t
  UNION ALL SELECT 9,  'Envio anterior al pedido',           envio_antes_pedido,    'REGLA' FROM t
  UNION ALL SELECT 10, 'Product ID con varios nombres',      prod_multi_nombre,     'REGLA' FROM dim
  UNION ALL SELECT 11, 'Lineas con ganancia negativa',       lineas_con_perdida,    'INFO'  FROM t
)
SELECT orden, indicador, valor,
       ROUND(valor * 100.0 / (SELECT total FROM t), 2) AS pct_sobre_total,
       CASE WHEN tipo = 'INFO' THEN 'INFORMATIVO'
            WHEN valor = 0     THEN 'OK'
            ELSE 'REVISAR' END AS estado
FROM resumen
ORDER BY orden;
