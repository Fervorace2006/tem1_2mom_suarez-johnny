-- Pregunta 7. Análisis de tendencias temporales

USE superstore;

DROP TABLE IF EXISTS ventas_mensuales;
CREATE TABLE ventas_mensuales STORED AS ORC AS
SELECT order_year                                   AS anio,
       order_month                                  AS mes,
       CONCAT(order_year, '-', LPAD(order_month, 2, '0')) AS periodo,
       ROUND(SUM(sales), 2)                         AS ventas,
       ROUND(SUM(profit), 2)                        AS ganancia,
       COUNT(DISTINCT order_id)                     AS ordenes
FROM ventas
GROUP BY order_year, order_month;

WITH m AS (
  SELECT periodo, anio, mes, ventas, ganancia, ordenes,
         LAG(ventas, 1)    OVER (ORDER BY periodo)                AS ventas_mes_ant,
         LAG(ganancia, 1)  OVER (ORDER BY periodo)                AS ganancia_mes_ant,
         LAG(ventas, 1)    OVER (PARTITION BY mes ORDER BY anio)  AS ventas_mismo_mes_anio_ant,
         LAG(ganancia, 1)  OVER (PARTITION BY mes ORDER BY anio)  AS ganancia_mismo_mes_anio_ant,
         AVG(ventas)       OVER (ORDER BY periodo ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS prom_movil_3m_ventas,
         AVG(ganancia)     OVER (ORDER BY periodo ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS prom_movil_3m_ganancia
  FROM ventas_mensuales
)
SELECT periodo, ventas, ganancia,
       ROUND((ventas - ventas_mes_ant) / ventas_mes_ant * 100, 2)                         AS var_mensual_pct,
       ROUND((ganancia - ganancia_mes_ant) / ABS(ganancia_mes_ant) * 100, 2)              AS var_ganancia_mensual_pct,
       ventas_mismo_mes_anio_ant                                                          AS ventas_mes_anio_ant,
       ROUND((ventas - ventas_mismo_mes_anio_ant) / ventas_mismo_mes_anio_ant * 100, 2)   AS var_interanual_pct,
       ROUND(prom_movil_3m_ventas, 2)                                                     AS prom_movil_3m,
       ROUND(prom_movil_3m_ganancia, 2)                                                   AS prom_movil_3m_ganancia
FROM m
ORDER BY periodo;

WITH r AS (
  SELECT periodo, ventas, ganancia,
         RANK() OVER (ORDER BY ventas DESC) AS rank_mayor,
         RANK() OVER (ORDER BY ventas ASC)  AS rank_menor
  FROM ventas_mensuales
)
SELECT 'MAYOR VENTA' AS tipo, rank_mayor AS puesto, periodo, ventas, ganancia FROM r WHERE rank_mayor <= 3
UNION ALL
SELECT 'MENOR VENTA', rank_menor, periodo, ventas, ganancia FROM r WHERE rank_menor <= 3
ORDER BY tipo, puesto;

SELECT mes,
       ROUND(AVG(ventas), 2)                                     AS ventas_prom,
       ROUND(AVG(ganancia), 2)                                   AS ganancia_prom,
       ROUND(AVG(ventas) * 100 / SUM(AVG(ventas)) OVER (), 2)    AS peso_estacional_pct
FROM ventas_mensuales
GROUP BY mes
ORDER BY mes;

SELECT anio,
       ROUND(SUM(ventas), 2)                                             AS ventas_anio,
       ROUND(SUM(SUM(ventas)) OVER (ORDER BY anio), 2)                   AS ventas_acumuladas,
       ROUND(MAX(ventas), 2)                                             AS mejor_mes,
       ROUND(MIN(ventas), 2)                                             AS peor_mes
FROM ventas_mensuales
GROUP BY anio
ORDER BY anio;
