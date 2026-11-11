-- Pregunta 4. Segmentación avanzada de clientes mediante RFM

USE superstore;

DROP TABLE IF EXISTS rfm_clientes;
CREATE TABLE rfm_clientes STORED AS ORC AS
WITH ref AS (
  SELECT MAX(order_date) AS fecha_ref FROM ventas
),
base AS (
  SELECT v.customer_id,
         MAX(v.customer_name)                       AS customer_name,
         MAX(v.segment)                             AS segment,
         DATEDIFF(MAX(r.fecha_ref), MAX(v.order_date)) AS recency,
         COUNT(DISTINCT v.order_id)                 AS frequency,
         ROUND(SUM(v.sales), 2)                     AS monetary,
         ROUND(SUM(v.profit), 2)                    AS ganancia
  FROM ventas v CROSS JOIN ref r
  GROUP BY v.customer_id
),
scores AS (
  SELECT b.*,
         NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,
         NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
         NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
  FROM base b
)
SELECT s.*,
       CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS rfm_codigo,
       r_score + f_score + m_score AS rfm_total,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4        THEN '1. Alto valor (Campeones)'
         WHEN f_score >= 4 AND r_score >= 3                         THEN '2. Recurrentes / Leales'
         WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3)       THEN '3. En riesgo de abandono'
         WHEN r_score >= 4 AND f_score <= 2                         THEN '4. Nuevos / Prometedores'
         WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2        THEN '5. Perdidos / Inactivos'
         ELSE '6. Necesitan atencion'
       END AS segmento_rfm
FROM scores s;

SELECT (SELECT MAX(order_date) FROM ventas) AS fecha_referencia,
       COUNT(*)                     AS clientes,
       MIN(recency) AS r_min, ROUND(AVG(recency),1) AS r_prom, MAX(recency) AS r_max,
       MIN(frequency) AS f_min, ROUND(AVG(frequency),1) AS f_prom, MAX(frequency) AS f_max,
       MIN(monetary) AS m_min, ROUND(AVG(monetary),2) AS m_prom, MAX(monetary) AS m_max
FROM rfm_clientes;

SELECT r_score AS score,
       CONCAT(MIN(recency), ' - ', MAX(recency), ' dias') AS rango_recency
FROM rfm_clientes GROUP BY r_score ORDER BY score;

SELECT f_score AS score,
       CONCAT(MIN(frequency), ' - ', MAX(frequency), ' ordenes') AS rango_frequency
FROM rfm_clientes GROUP BY f_score ORDER BY score;

SELECT m_score AS score,
       CONCAT(MIN(monetary), ' - ', MAX(monetary), ' USD') AS rango_monetary
FROM rfm_clientes GROUP BY m_score ORDER BY score;

SELECT segmento_rfm,
       COUNT(*)                                                   AS clientes,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)         AS pct_clientes,
       ROUND(AVG(recency), 1)                                     AS recency_prom,
       ROUND(AVG(frequency), 1)                                   AS frequency_prom,
       ROUND(AVG(monetary), 2)                                    AS monetary_prom,
       ROUND(SUM(monetary), 2)                                    AS ventas_total,
       ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 2) AS pct_ventas
FROM rfm_clientes
GROUP BY segmento_rfm
ORDER BY segmento_rfm;

SELECT customer_id, customer_name, segment, recency, frequency, monetary, ganancia, rfm_codigo
FROM rfm_clientes
WHERE segmento_rfm = '1. Alto valor (Campeones)'
ORDER BY monetary DESC
LIMIT 10;

SELECT customer_id, customer_name, segment, recency, frequency, monetary, ganancia, rfm_codigo
FROM rfm_clientes
WHERE segmento_rfm = '3. En riesgo de abandono'
ORDER BY monetary DESC
LIMIT 10;
