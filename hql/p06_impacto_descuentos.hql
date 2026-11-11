-- Pregunta 6. Análisis del impacto de los descuentos

USE superstore;

DROP VIEW IF EXISTS v_ventas_descuento;
CREATE VIEW v_ventas_descuento AS
SELECT v.*,
       CASE WHEN discount = 0    THEN '1. Sin descuento (0%)'
            WHEN discount <= 0.20 THEN '2. Bajo (0-20%]'
            WHEN discount <= 0.50 THEN '3. Medio (20-50%]'
            ELSE                       '4. Alto (>50%)' END AS rango_descuento
FROM ventas v;

SELECT rango_descuento,
       COUNT(*)                                            AS registros,
       ROUND(SUM(sales), 2)                                AS ventas,
       ROUND(SUM(profit), 2)                               AS ganancia,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)            AS margen_pct,
       SUM(IF(profit < 0, 1, 0))                           AS registros_con_perdida,
       ROUND(SUM(IF(profit < 0, 1, 0)) * 100.0 / COUNT(*), 2) AS pct_no_rentables,
       ROUND(AVG(discount) * 100, 2)                       AS descuento_prom_pct,
       ROUND(SUM(IF(profit < 0, profit, 0)), 2)            AS perdida_total
FROM v_ventas_descuento
GROUP BY rango_descuento
ORDER BY rango_descuento;

SELECT ROUND(discount * 100, 0)                          AS descuento_pct,
       COUNT(*)                                          AS registros,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)          AS margen_pct,
       ROUND(SUM(IF(profit < 0, 1, 0)) * 100.0 / COUNT(*), 2) AS pct_no_rentables
FROM ventas
GROUP BY discount
ORDER BY descuento_pct;

SELECT ROUND(CORR(CAST(discount AS DOUBLE), CAST(profit AS DOUBLE)), 4)                AS corr_descuento_ganancia,
       ROUND(CORR(CAST(discount AS DOUBLE), CAST(profit / sales AS DOUBLE)), 4)        AS corr_descuento_margen,
       ROUND(CORR(CAST(discount AS DOUBLE), IF(profit < 0, 1.0, 0.0)), 4)              AS corr_descuento_perdida
FROM ventas;

SELECT category, rango_descuento,
       COUNT(*)                                   AS registros,
       ROUND(SUM(sales), 2)                       AS ventas,
       ROUND(SUM(profit), 2)                      AS ganancia,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)   AS margen_pct,
       ROUND(SUM(IF(profit < 0, 1, 0)) * 100.0 / COUNT(*), 2) AS pct_no_rentables
FROM v_ventas_descuento
GROUP BY category, rango_descuento
ORDER BY category, rango_descuento;

WITH sub AS (
  SELECT category, sub_category,
         COUNT(*)                                        AS registros,
         ROUND(AVG(discount) * 100, 2)                   AS descuento_prom_pct,
         SUM(IF(discount > 0.20, 1, 0))                  AS registros_desc_medio_alto,
         ROUND(SUM(sales), 2)                            AS ventas,
         ROUND(SUM(profit), 2)                           AS ganancia,
         ROUND(SUM(IF(discount > 0.20, profit, 0)), 2)   AS ganancia_desc_medio_alto,
         ROUND(SUM(IF(profit < 0, 1, 0)) * 100.0 / COUNT(*), 2) AS pct_no_rentables
  FROM ventas
  GROUP BY category, sub_category
)
SELECT RANK() OVER (ORDER BY ganancia_desc_medio_alto ASC) AS rank_afectacion,
       category, sub_category, registros, descuento_prom_pct, registros_desc_medio_alto,
       ventas, ganancia, ganancia_desc_medio_alto, pct_no_rentables
FROM sub
ORDER BY rank_afectacion
LIMIT 10;

SELECT IF(discount > 0.20, 'Descuento > 20%', 'Descuento <= 20%') AS grupo,
       COUNT(*)                                                  AS registros,
       SUM(IF(profit < 0, 1, 0))                                 AS no_rentables,
       ROUND(SUM(IF(profit < 0, 1, 0)) * 100.0 / COUNT(*), 2)    AS pct_no_rentables,
       ROUND(SUM(profit), 2)                                     AS ganancia_neta
FROM ventas
GROUP BY IF(discount > 0.20, 'Descuento > 20%', 'Descuento <= 20%')
ORDER BY grupo;
