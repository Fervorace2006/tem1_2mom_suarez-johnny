-- Análisis de optimización

USE superstore;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.enforce.bucketing=true;

DROP TABLE IF EXISTS ventas_texto;
CREATE TABLE ventas_texto
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
AS SELECT * FROM ventas;

DROP TABLE IF EXISTS ventas_part;
CREATE TABLE ventas_part (
  row_id INT, order_id STRING, order_date DATE, ship_date DATE, ship_mode STRING,
  customer_id STRING, customer_name STRING, segment STRING, country STRING, city STRING,
  state STRING, postal_code STRING, region STRING, product_id STRING, category STRING,
  sub_category STRING, product_name STRING, sales DECIMAL(12,4), quantity INT,
  discount DECIMAL(4,2), profit DECIMAL(12,4), order_month INT, days_to_ship INT
)
PARTITIONED BY (order_year INT)
CLUSTERED BY (customer_id) INTO 4 BUCKETS
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

INSERT OVERWRITE TABLE ventas_part PARTITION (order_year)
SELECT row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name, segment,
       country, city, state, postal_code, region, product_id, category, sub_category, product_name,
       sales, quantity, discount, profit, order_month, days_to_ship, order_year
FROM ventas;

SHOW PARTITIONS ventas_part;

ANALYZE TABLE ventas COMPUTE STATISTICS;
ANALYZE TABLE ventas COMPUTE STATISTICS FOR COLUMNS;
ANALYZE TABLE ventas_texto COMPUTE STATISTICS;
ANALYZE TABLE ventas_part PARTITION (order_year) COMPUTE STATISTICS;

DESCRIBE FORMATTED ventas_texto;
DESCRIBE FORMATTED ventas;
DESCRIBE FORMATTED ventas_part PARTITION (order_year = 2017);

SELECT region, ROUND(SUM(sales), 2) AS ventas, ROUND(SUM(profit), 2) AS ganancia
FROM ventas_texto WHERE order_year = 2017 GROUP BY region ORDER BY region;

SELECT region, ROUND(SUM(sales), 2) AS ventas, ROUND(SUM(profit), 2) AS ganancia
FROM ventas WHERE order_year = 2017 GROUP BY region ORDER BY region;

SELECT region, ROUND(SUM(sales), 2) AS ventas, ROUND(SUM(profit), 2) AS ganancia
FROM ventas_part WHERE order_year = 2017 GROUP BY region ORDER BY region;

EXPLAIN
SELECT region, SUM(sales) FROM ventas WHERE order_year = 2017 GROUP BY region;

EXPLAIN
SELECT region, SUM(sales) FROM ventas_part WHERE order_year = 2017 GROUP BY region;

EXPLAIN DEPENDENCY
SELECT region, SUM(sales) FROM ventas_part WHERE order_year = 2017 GROUP BY region;

SET hive.compute.query.using.stats=true;
SELECT COUNT(*) FROM ventas;

SET hive.vectorized.execution.enabled=true;
SET hive.vectorized.execution.reduce.enabled=true;
EXPLAIN VECTORIZATION ONLY SUMMARY
SELECT category, SUM(sales), SUM(profit) FROM ventas GROUP BY category;

SELECT category, ROUND(SUM(sales), 2) AS ventas, ROUND(SUM(profit), 2) AS ganancia
FROM ventas GROUP BY category ORDER BY category;
