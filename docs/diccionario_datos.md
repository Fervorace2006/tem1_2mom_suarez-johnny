# Diccionario de datos — Sample Superstore

**Archivo origen:** `data/Sample - Superstore.csv`
**Registros:** 9 994 (más 1 línea de cabecera) · **Columnas:** 21
**Separador:** coma (`,`) · **Calificador de texto:** comillas dobles (`"`) · **Codificación original:** Windows-1252
**Formato de fechas:** `M/d/yyyy` (ej. `11/8/2016`, sin ceros a la izquierda)
**Periodo cubierto:** 2014-01-03 a 2017-12-30

## Hallazgos de la inspección previa del CSV

| # | Observación | Tratamiento en la ingesta |
|---|-------------|---------------------------|
| 1 | El archivo está en Windows-1252, no en UTF-8 (caracteres especiales y espacios no separables `U+00A0` en `Product Name`). | Conversión con `iconv -f WINDOWS-1252 -t UTF-8` antes de subir a HDFS y reemplazo de `U+00A0` por espacio. |
| 2 | `Product Name` contiene comas dentro de comillas (ej. `"Hon Deluxe Fabric ... Chairs, Rounded Back"`). | Se usa `OpenCSVSerde` en staging (un `FIELDS TERMINATED BY ','` simple rompería las columnas). |
| 3 | Las fechas vienen como texto `M/d/yyyy`. | Conversión con `UNIX_TIMESTAMP(..., 'M/d/yyyy')` → `DATE`. Fecha no convertible = `NULL` (se audita en P2). |
| 4 | `Postal Code` tiene códigos con cero inicial (ej. `05408`, Vermont). | Se guarda como `STRING` y se normaliza con `LPAD(...,5,'0')`; como número se perdería el cero. |
| 5 | `Country` tiene un único valor (`United States`). | Se conserva, pero no aporta a los análisis. |
| 6 | 32 `Product ID` aparecen con más de un `Product Name` y 16 nombres con más de un ID. | Se reporta en la auditoría (P2); en los rankings se agrupa por `product_id` (clave de negocio). |
| 7 | Una orden tiene varias líneas (5 009 órdenes en 9 994 filas). | La granularidad de la tabla es **línea de pedido**; las métricas por orden usan `COUNT(DISTINCT order_id)`. |

## Diccionario

| # | Campo CSV | Columna Hive | Tipo Hive | Descripción | Restricciones / dominio |
|---|-----------|--------------|-----------|-------------|-------------------------|
| 1 | Row ID | `row_id` | `INT` | Identificador secuencial de la línea | NOT NULL, único (clave primaria lógica), 1–9994 |
| 2 | Order ID | `order_id` | `STRING` | Identificador de la orden | NOT NULL, formato `XX-AAAA-NNNNNN` (5 009 distintos) |
| 3 | Order Date | `order_date` | `DATE` | Fecha en que se realizó el pedido | NOT NULL, 2014–2017 |
| 4 | Ship Date | `ship_date` | `DATE` | Fecha de envío | NOT NULL, `ship_date >= order_date` |
| 5 | Ship Mode | `ship_mode` | `STRING` | Modalidad de envío | {Standard Class, Second Class, First Class, Same Day} |
| 6 | Customer ID | `customer_id` | `STRING` | Identificador del cliente | NOT NULL (793 distintos) |
| 7 | Customer Name | `customer_name` | `STRING` | Nombre del cliente | NOT NULL |
| 8 | Segment | `segment` | `STRING` | Segmento de mercado | {Consumer, Corporate, Home Office} |
| 9 | Country | `country` | `STRING` | País | {United States} |
| 10 | City | `city` | `STRING` | Ciudad | 531 distintas |
| 11 | State | `state` | `STRING` | Estado | 49 distintos |
| 12 | Postal Code | `postal_code` | `STRING` | Código postal | 5 dígitos (se conserva el cero inicial) |
| 13 | Region | `region` | `STRING` | Región comercial | {Central, East, South, West} |
| 14 | Product ID | `product_id` | `STRING` | Identificador del producto | `CAT-SUB-NNNNNNNN` (1 862 distintos) |
| 15 | Category | `category` | `STRING` | Categoría | {Furniture, Office Supplies, Technology} |
| 16 | Sub-Category | `sub_category` | `STRING` | Subcategoría | 17 valores |
| 17 | Product Name | `product_name` | `STRING` | Nombre del producto | Máx. 127 caracteres, puede contener comas |
| 18 | Sales | `sales` | `DECIMAL(12,4)` | Importe de la venta en USD | `> 0` |
| 19 | Quantity | `quantity` | `INT` | Unidades vendidas | `>= 1` (1–14) |
| 20 | Discount | `discount` | `DECIMAL(4,2)` | Descuento como fracción | `0 <= discount <= 1` (valores 0 a 0.80) |
| 21 | Profit | `profit` | `DECIMAL(12,4)` | Ganancia (positiva) o pérdida (negativa) en USD | Puede ser negativo |
| — | *(derivado)* | `order_year` | `INT` | Año de `order_date` | 2014–2017 |
| — | *(derivado)* | `order_month` | `INT` | Mes de `order_date` | 1–12 |
| — | *(derivado)* | `days_to_ship` | `INT` | `DATEDIFF(ship_date, order_date)` | `>= 0` |

## Justificación de tipos

- **`DECIMAL` para montos** (`sales`, `profit`): evita los errores de redondeo de `DOUBLE` en sumas de dinero. Escala 4 porque el CSV trae hasta 4 decimales en `profit` (ej. `41.9136`).
- **`DECIMAL(4,2)` para `discount`**: los descuentos son fracciones con máximo 2 decimales (0.15, 0.32, 0.45...).
- **`DATE` para fechas**: permite `DATEDIFF`, `YEAR`, `MONTH`, `TRUNC` y comparaciones directas.
- **`STRING` para identificadores y `postal_code`**: no se operan aritméticamente y tienen formato alfanumérico o ceros iniciales.
- **Formato ORC + Snappy** para la tabla analítica: almacenamiento columnar, compresión y estadísticas por *stripe* que aceleran las agregaciones (ver `docs/optimizacion.md`).
