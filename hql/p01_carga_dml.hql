-- Pregunta 1. Procedimiento de carga (DML)

USE superstore;

SELECT COUNT(*) AS registros_staging FROM stg_superstore_raw;

SELECT row_id, order_id, order_date, ship_date, product_name, sales, discount, profit
FROM stg_superstore_raw
LIMIT 5;

INSERT OVERWRITE TABLE ventas
SELECT
  CAST(TRIM(row_id) AS INT),
  TRIM(order_id),
  TO_DATE(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'M/d/yyyy'))),
  TO_DATE(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(ship_date),  'M/d/yyyy'))),
  TRIM(ship_mode),
  TRIM(customer_id),
  TRIM(customer_name),
  TRIM(segment),
  TRIM(country),
  TRIM(city),
  TRIM(state),
  LPAD(TRIM(postal_code), 5, '0'),
  TRIM(region),
  TRIM(product_id),
  TRIM(category),
  TRIM(sub_category),
  TRIM(REGEXP_REPLACE(product_name, ' ', ' ')),
  CAST(TRIM(sales)    AS DECIMAL(12,4)),
  CAST(TRIM(quantity) AS INT),
  CAST(TRIM(discount) AS DECIMAL(4,2)),
  CAST(TRIM(profit)   AS DECIMAL(12,4)),
  YEAR(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'M/d/yyyy'))),
  MONTH(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'M/d/yyyy'))),
  DATEDIFF(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(ship_date),  'M/d/yyyy')),
           FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'M/d/yyyy')))
FROM stg_superstore_raw;

SELECT COUNT(*) AS registros_ventas FROM ventas;

SELECT order_year, COUNT(*) AS registros
FROM ventas
GROUP BY order_year
ORDER BY order_year;

SELECT row_id, order_id, order_date, ship_date, customer_name, region,
       product_name, sales, quantity, discount, profit
FROM ventas
ORDER BY row_id
LIMIT 10;
