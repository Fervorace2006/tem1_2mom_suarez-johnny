-- Pregunta 3. Análisis de evolución comercial por región

USE superstore;

WITH base AS (
  SELECT region,
         order_year            AS anio,
         SUM(sales)            AS ventas,
         SUM(profit)           AS ganancia
  FROM ventas
  GROUP BY region, order_year
),
evolucion AS (
  SELECT region, anio, ventas, ganancia,
         ganancia / ventas * 100                                   AS margen_pct,
         LAG(ventas)   OVER (PARTITION BY region ORDER BY anio)    AS ventas_anio_ant,
         LAG(ganancia) OVER (PARTITION BY region ORDER BY anio)    AS ganancia_anio_ant,
         RANK() OVER (PARTITION BY anio ORDER BY ventas DESC)      AS rank_ventas_anio,
         RANK() OVER (PARTITION BY anio ORDER BY ganancia DESC)    AS rank_ganancia_anio
  FROM base
)
SELECT region, anio,
       ROUND(ventas, 2)                                              AS ventas,
       ROUND(ganancia, 2)                                            AS ganancia,
       ROUND(margen_pct, 2)                                          AS margen_pct,
       ROUND((ventas - ventas_anio_ant) / ventas_anio_ant * 100, 2)  AS var_ventas_pct,
       ROUND((ganancia - ganancia_anio_ant) / ABS(ganancia_anio_ant) * 100, 2) AS var_ganancia_pct,
       rank_ventas_anio,
       rank_ganancia_anio
FROM evolucion
ORDER BY region, anio;

WITH base AS (
  SELECT region, order_year AS anio, SUM(sales) AS ventas, SUM(profit) AS ganancia
  FROM ventas
  GROUP BY region, order_year
),
totales AS (
  SELECT region,
         SUM(ventas)                                   AS ventas_total,
         SUM(ganancia)                                 AS ganancia_total,
         SUM(ganancia) / SUM(ventas) * 100             AS margen_pct,
         MAX(IF(anio = 2014, ventas, NULL))            AS ventas_2014,
         MAX(IF(anio = 2017, ventas, NULL))            AS ventas_2017
  FROM base
  GROUP BY region
)
SELECT region,
       ROUND(ventas_total, 2)                                     AS ventas_total,
       ROUND(ganancia_total, 2)                                   AS ganancia_total,
       ROUND(margen_pct, 2)                                       AS margen_pct,
       ROUND((ventas_2017 - ventas_2014) / ventas_2014 * 100, 2)  AS crecimiento_14_17_pct,
       ROUND(ventas_total * 100 / SUM(ventas_total) OVER (), 2)   AS participacion_ventas_pct,
       RANK() OVER (ORDER BY ganancia_total DESC)                 AS rank_ganancia,
       RANK() OVER (ORDER BY margen_pct DESC)                     AS rank_margen,
       CASE WHEN RANK() OVER (ORDER BY ganancia_total DESC) = 1 THEN 'MEJOR DESEMPENO'
            WHEN RANK() OVER (ORDER BY ganancia_total ASC)  = 1 THEN 'PEOR DESEMPENO'
            ELSE '-' END                                          AS clasificacion
FROM totales
ORDER BY rank_ganancia;
