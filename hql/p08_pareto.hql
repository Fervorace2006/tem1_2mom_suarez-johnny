-- Pregunta 8. Análisis Pareto de ventas y rentabilidad

USE superstore;

WITH prod AS (
  SELECT product_id, MIN(product_name) AS product_name, MIN(category) AS category,
         SUM(sales) AS ventas
  FROM ventas
  GROUP BY product_id
),
acum AS (
  SELECT product_id, product_name, category, ventas,
         ROW_NUMBER() OVER (ORDER BY ventas DESC)                                    AS puesto,
         ventas * 100 / SUM(ventas) OVER ()                                          AS pct_individual,
         SUM(ventas) OVER (ORDER BY ventas DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           * 100 / SUM(ventas) OVER ()                                               AS pct_acumulado,
         COUNT(*) OVER ()                                                            AS total_productos
  FROM prod
)
SELECT puesto, product_id, category, SUBSTR(product_name, 1, 50) AS producto,
       ROUND(ventas, 2) AS ventas, ROUND(pct_individual, 3) AS pct_individual,
       ROUND(pct_acumulado, 2) AS pct_acumulado
FROM acum
WHERE puesto <= 15
ORDER BY puesto;

WITH prod AS (
  SELECT product_id, SUM(sales) AS ventas FROM ventas GROUP BY product_id
),
acum AS (
  SELECT product_id, ventas,
         SUM(ventas) OVER (ORDER BY ventas DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           * 100 / SUM(ventas) OVER () AS pct_acumulado,
         (SUM(ventas) OVER (ORDER BY ventas DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - ventas)
           * 100 / SUM(ventas) OVER () AS pct_acumulado_previo,
         COUNT(*) OVER () AS total_productos
  FROM prod
)
SELECT 'VENTAS' AS analisis,
       MAX(total_productos)                                              AS total_productos,
       SUM(IF(pct_acumulado_previo < 80, 1, 0))                          AS productos_80pct,
       ROUND(SUM(IF(pct_acumulado_previo < 80, 1, 0)) * 100.0 / MAX(total_productos), 2) AS pct_productos,
       ROUND(SUM(IF(pct_acumulado_previo < 80, ventas, 0)), 2)           AS monto_concentrado
FROM acum;

WITH prod AS (
  SELECT product_id, MIN(product_name) AS product_name, MIN(category) AS category,
         SUM(profit) AS ganancia
  FROM ventas
  GROUP BY product_id
),
acum AS (
  SELECT product_id, product_name, category, ganancia,
         ROW_NUMBER() OVER (ORDER BY ganancia DESC)                                   AS puesto,
         ganancia * 100 / SUM(ganancia) OVER ()                                       AS pct_individual_neto,
         ganancia * 100 / SUM(IF(ganancia > 0, ganancia, 0)) OVER ()                  AS pct_individual_positivo,
         SUM(ganancia) OVER (ORDER BY ganancia DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           * 100 / SUM(ganancia) OVER ()                                              AS pct_acum_neto
  FROM prod
)
SELECT puesto, product_id, category, SUBSTR(product_name, 1, 50) AS producto,
       ROUND(ganancia, 2) AS ganancia,
       ROUND(pct_individual_neto, 3) AS pct_individual,
       ROUND(pct_acum_neto, 2) AS pct_acumulado
FROM acum
WHERE puesto <= 15
ORDER BY puesto;

WITH prod AS (
  SELECT product_id, SUM(profit) AS ganancia FROM ventas GROUP BY product_id
),
acum AS (
  SELECT product_id, ganancia,
         SUM(ganancia) OVER () AS ganancia_neta,
         SUM(IF(ganancia > 0, ganancia, 0)) OVER () AS ganancia_positiva,
         SUM(ganancia) OVER (ORDER BY ganancia DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - ganancia AS acum_previo,
         COUNT(*) OVER () AS total_productos
  FROM prod
)
SELECT 'GANANCIA (base neta)' AS analisis,
       MAX(total_productos) AS total_productos,
       SUM(IF(acum_previo < 0.8 * ganancia_neta, 1, 0)) AS productos_80pct,
       ROUND(SUM(IF(acum_previo < 0.8 * ganancia_neta, 1, 0)) * 100.0 / MAX(total_productos), 2) AS pct_productos,
       ROUND(MAX(ganancia_neta), 2) AS base_ganancia
FROM acum
UNION ALL
SELECT 'GANANCIA (base solo positivos)',
       SUM(IF(ganancia > 0, 1, 0)),
       SUM(IF(ganancia > 0 AND acum_previo < 0.8 * ganancia_positiva, 1, 0)),
       ROUND(SUM(IF(ganancia > 0 AND acum_previo < 0.8 * ganancia_positiva, 1, 0)) * 100.0 / SUM(IF(ganancia > 0, 1, 0)), 2),
       ROUND(MAX(ganancia_positiva), 2)
FROM acum;

WITH prod AS (
  SELECT product_id, SUM(profit) AS ganancia FROM ventas GROUP BY product_id
),
acum AS (
  SELECT ganancia,
         SUM(ganancia) OVER (ORDER BY ganancia DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           * 100 / SUM(ganancia) OVER () AS pct_acum
  FROM prod
)
SELECT CASE WHEN ganancia > 0 THEN 'Con ganancia' WHEN ganancia = 0 THEN 'Sin ganancia' ELSE 'Con perdida' END AS grupo,
       COUNT(*)                 AS productos,
       ROUND(SUM(ganancia), 2)  AS ganancia,
       ROUND(MAX(pct_acum), 2)  AS max_pct_acumulado
FROM acum
GROUP BY CASE WHEN ganancia > 0 THEN 'Con ganancia' WHEN ganancia = 0 THEN 'Sin ganancia' ELSE 'Con perdida' END;

WITH prod AS (
  SELECT product_id, MIN(category) AS category, SUM(sales) AS ventas, SUM(profit) AS ganancia
  FROM ventas GROUP BY product_id
),
v AS (
  SELECT product_id, category, ventas, ganancia,
         (SUM(ventas) OVER (ORDER BY ventas DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - ventas)
           / SUM(ventas) OVER () AS prev_v,
         (SUM(ganancia) OVER (ORDER BY ganancia DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - ganancia)
           / SUM(ganancia) OVER () AS prev_g
  FROM prod
)
SELECT category,
       SUM(IF(prev_v < 0.8, 1, 0))                              AS en_pareto_ventas,
       SUM(IF(prev_g < 0.8 AND ganancia > 0, 1, 0))             AS en_pareto_ganancia,
       SUM(IF(prev_v < 0.8 AND prev_g < 0.8 AND ganancia > 0, 1, 0)) AS en_ambos,
       SUM(IF(prev_v < 0.8 AND ganancia < 0, 1, 0))             AS pareto_ventas_con_perdida
FROM v
GROUP BY category
ORDER BY category;
