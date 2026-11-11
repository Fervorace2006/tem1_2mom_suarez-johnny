-- Pregunta 1. Diseño e implementación del modelo de datos (DDL)

DROP DATABASE IF EXISTS superstore CASCADE;

CREATE DATABASE superstore
COMMENT 'Examen 2do momento - Sample Superstore'
LOCATION 'hdfs://yarn-resourcemanager:9000/user/hive/warehouse/superstore.db';

USE superstore;

DROP TABLE IF EXISTS stg_superstore_raw;
CREATE EXTERNAL TABLE stg_superstore_raw (
  row_id        STRING,
  order_id      STRING,
  order_date    STRING,
  ship_date     STRING,
  ship_mode     STRING,
  customer_id   STRING,
  customer_name STRING,
  segment       STRING,
  country       STRING,
  city          STRING,
  state         STRING,
  postal_code   STRING,
  region        STRING,
  product_id    STRING,
  category      STRING,
  sub_category  STRING,
  product_name  STRING,
  sales         STRING,
  quantity      STRING,
  discount      STRING,
  profit        STRING
)
COMMENT 'Staging: CSV original Superstore sin transformar'
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar'     = '"',
  'escapeChar'    = '\\'
)
STORED AS TEXTFILE
LOCATION 'hdfs://yarn-resourcemanager:9000/user/hive/raw/superstore'
TBLPROPERTIES ('skip.header.line.count' = '1');

DROP TABLE IF EXISTS ventas;
CREATE TABLE ventas (
  row_id        INT            COMMENT 'Identificador de fila (PK lógica)',
  order_id      STRING         COMMENT 'Identificador de la orden (CA-AAAA-NNNNNN)',
  order_date    DATE           COMMENT 'Fecha del pedido',
  ship_date     DATE           COMMENT 'Fecha de envío',
  ship_mode     STRING         COMMENT 'Modalidad de envío',
  customer_id   STRING         COMMENT 'Identificador del cliente',
  customer_name STRING         COMMENT 'Nombre del cliente',
  segment       STRING         COMMENT 'Segmento: Consumer, Corporate, Home Office',
  country       STRING         COMMENT 'País',
  city          STRING         COMMENT 'Ciudad',
  state         STRING         COMMENT 'Estado',
  postal_code   STRING         COMMENT 'Código postal (STRING: conserva ceros a la izquierda)',
  region        STRING         COMMENT 'Región: Central, East, South, West',
  product_id    STRING         COMMENT 'Identificador del producto',
  category      STRING         COMMENT 'Categoría',
  sub_category  STRING         COMMENT 'Subcategoría',
  product_name  STRING         COMMENT 'Nombre del producto',
  sales         DECIMAL(12,4)  COMMENT 'Importe de venta (USD)',
  quantity      INT            COMMENT 'Unidades vendidas',
  discount      DECIMAL(4,2)   COMMENT 'Descuento aplicado (fracción 0-1)',
  profit        DECIMAL(12,4)  COMMENT 'Ganancia/pérdida (USD)',
  order_year    INT            COMMENT 'Derivado: año del pedido',
  order_month   INT            COMMENT 'Derivado: mes del pedido',
  days_to_ship  INT            COMMENT 'Derivado: días entre pedido y envío'
)
COMMENT 'Tabla analítica Superstore tipada'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

SHOW TABLES;
DESCRIBE ventas;
