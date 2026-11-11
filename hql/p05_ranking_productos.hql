-- Pregunta 5. Ranking de productos según rentabilidad

USE superstore;

DROP TABLE IF EXISTS productos_kpi;
CREATE TABLE productos_kpi STORED AS ORC AS
WITH prod AS (
  SELECT product_id,
         MIN(product_name)  AS product_name,
         MIN(category)      AS category,
         MIN(sub_category)  AS sub_category,
         SUM(sales)         AS ventas,
         SUM(quantity)      AS unidades,
         SUM(profit)        AS ganancia,
         COUNT(*)           AS lineas
  FROM ventas
  GROUP BY product_id
)
SELECT p.*,
       ROUND(ganancia / ventas * 100, 2)                                        AS margen_pct,
       RANK()       OVER (PARTITION BY category ORDER BY ganancia DESC)         AS rank_ganancia_cat,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY ganancia DESC)         AS dense_rank_ganancia_cat,
       DENSE_RANK() OVER (ORDER BY ventas DESC)                                 AS dense_rank_ventas,
       RANK()       OVER (ORDER BY ganancia / ventas ASC)                       AS rank_menor_margen,
       SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)   AS ganancia_acum_cat,
       SUM(ganancia) OVER (PARTITION BY category)                               AS ganancia_total_cat,
       COUNT(*)      OVER (PARTITION BY category)                               AS productos_cat
FROM prod p;

SELECT COUNT(*) AS productos, COUNT(DISTINCT category) AS categorias FROM productos_kpi;

SELECT category, rank_ganancia_cat AS puesto, product_id,
       SUBSTR(product_name, 1, 55)                                      AS producto,
       ROUND(ventas, 2)  AS ventas, ROUND(ganancia, 2) AS ganancia, margen_pct,
       ROUND(ganancia_acum_cat, 2)                                      AS ganancia_acumulada,
       ROUND(ganancia_acum_cat / ganancia_total_cat * 100, 2)           AS pct_acum_categoria
FROM productos_kpi
WHERE rank_ganancia_cat <= 5
ORDER BY category, puesto;

SELECT dense_rank_ventas AS puesto, product_id, category,
       SUBSTR(product_name, 1, 55) AS producto,
       ROUND(ventas, 2) AS ventas, unidades, ROUND(ganancia, 2) AS ganancia, margen_pct,
       rank_ganancia_cat AS puesto_en_categoria
FROM productos_kpi
WHERE dense_rank_ventas <= 5
ORDER BY puesto;

SELECT RANK() OVER (ORDER BY ganancia ASC) AS puesto, product_id, category,
       SUBSTR(product_name, 1, 55) AS producto,
       ROUND(ventas, 2) AS ventas, ROUND(ganancia, 2) AS ganancia, margen_pct,
       rank_ganancia_cat AS puesto_en_categoria, productos_cat
FROM productos_kpi
ORDER BY ganancia ASC
LIMIT 5;

SELECT rank_menor_margen AS puesto, product_id, category,
       SUBSTR(product_name, 1, 55) AS producto,
       ROUND(ventas, 2) AS ventas, ROUND(ganancia, 2) AS ganancia, margen_pct
FROM productos_kpi
WHERE rank_menor_margen <= 5
ORDER BY puesto;

SELECT category, rank_ganancia_cat AS rank_cat, dense_rank_ganancia_cat AS dense_rank_cat,
       product_id, SUBSTR(product_name, 1, 45) AS producto,
       ROUND(ganancia, 2) AS ganancia, margen_pct,
       CONCAT(rank_ganancia_cat, ' de ', productos_cat) AS posicion
FROM productos_kpi
WHERE rank_ganancia_cat <= 15
ORDER BY category, rank_cat;

SELECT category,
       COUNT(*)                         AS productos,
       SUM(IF(ganancia < 0, 1, 0))      AS productos_con_perdida,
       ROUND(SUM(ganancia), 2)          AS ganancia_total,
       ROUND(SUM(ganancia) / SUM(ventas) * 100, 2) AS margen_pct
FROM productos_kpi
GROUP BY category
ORDER BY ganancia_total DESC;
