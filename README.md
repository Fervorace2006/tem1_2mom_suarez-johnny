# tem1_2mom_suarez-johnny

**Universidad del Valle — Examen Práctico Individual, 2do Momento**
**Estudiante:** Johnny Suarez Abasto · **Docente:** Ing. Efrain Luna Mamani
**Tema:** Procesamiento y análisis del dataset *Sample Superstore* con Apache Hive

---

## 1. Descripción

Proyecto de ingeniería y análisis de datos sobre el dataset **Sample Superstore**: 9 994 líneas de pedido de una cadena minorista de EE. UU. entre 2014 y 2017. Los datos se cargan en **HDFS**, se modelan en **Apache Hive** (capa *staging* + tabla analítica ORC) y se analizan con HiveQL: auditoría de calidad, evolución regional, segmentación RFM, ranking de productos, impacto de descuentos, tendencias mensuales y Pareto 80/20.

## 2. Objetivos

- Diseñar e implementar un modelo de almacenamiento en Hive con tipos de datos adecuados.
- Auditar la calidad e integridad del dataset antes del análisis.
- Resolver consultas analíticas avanzadas con CTE, funciones de ventana (`LAG`, `RANK`, `DENSE_RANK`, `NTILE`, `SUM() OVER`) y agregaciones.
- Aplicar técnicas de optimización (ORC, particiones, buckets, estadísticas, vectorización).
- Interpretar los resultados para apoyar la toma de decisiones comerciales.

## 3. Requisitos

| Componente | Versión |
|-----------|---------|
| Docker Desktop | 4.x (Windows 11) |
| Imagen `dockerspark:latest` (clúster del curso) | Hadoop 3.3.5 · Spark 3.4.1 · Hive 3.1.3 · Java 8 |
| Servicios usados | NameNode + 3 DataNodes (HDFS), YARN, Hive Metastore, HiveServer2 |
| Cliente | Beeline (JDBC `jdbc:hive2://localhost:10000`) |
| Shell en el host | Git Bash |

El clúster es el del repositorio del curso *Bigdata-Dockerspark-Transnochados* (`docker compose up -d`).

## 4. Estructura del repositorio

```
├── data/Sample - Superstore.csv     Dataset original (Kaggle)
├── docs/
│   ├── diccionario_datos.md         Diccionario de datos e inspección del CSV
│   └── optimizacion.md              Análisis de optimización
├── hql/
│   ├── p01_ddl.hql                  DDL: base de datos, staging y tabla ORC
│   ├── p01_carga_dml.hql            DML: transformación staging -> ventas
│   ├── p02_calidad_datos.hql ... p08_pareto.hql
│   └── p09_optimizacion.hql
├── scripts/
│   ├── cargar_datos.sh              CSV -> UTF-8 -> HDFS
│   └── ejecutar_hql.sh              Ejecuta un .hql en Beeline y guarda la salida
└── evidencias/
    ├── salidas/                     Salida completa de Beeline por script
    └── capturas/                    Capturas de ejecución
```

## 5. Procedimiento de ejecución

```bash
# 1. Levantar el clúster (desde la carpeta del repositorio del curso)
docker compose up -d
docker ps --format "table {{.Names}}\t{{.Status}}"

# 2. Cargar el CSV a HDFS (desde esta carpeta)
bash scripts/cargar_datos.sh

# 3. Ejecutar los scripts en orden
for f in p01_ddl p01_carga_dml p02_calidad_datos p03_evolucion_region p04_rfm_clientes \
         p05_ranking_productos p06_impacto_descuentos p07_tendencias_mensuales p08_pareto p09_optimizacion; do
  bash scripts/ejecutar_hql.sh hql/$f.hql
done
```

`ejecutar_hql.sh` copia el script al contenedor `hive-server`, lo ejecuta con Beeline y guarda la salida en `evidencias/salidas/`. Usa `mapreduce.task.io.sort.mb=16` porque HiveServer2 corre los jobs MapReduce en modo local con 256 MB de heap, y con el valor por defecto (100 MB) los `GROUP BY` fallaban con `OutOfMemoryError`.

---

# Desarrollo

## Pregunta 1. Diseño e implementación del modelo de datos

**Enunciado:** construir el modelo de almacenamiento en Hive: identificar los campos, elaborar el diccionario de datos, crear una tabla analítica con tipos apropiados y documentar la carga.

**Estrategia.** Antes de cargar se inspeccionó el CSV. Está en Windows-1252, tiene comas dentro de `Product Name`, usa fechas `M/d/yyyy` y trae códigos postales con cero inicial. Por eso el modelo tiene dos capas:

1. **`stg_superstore_raw`**: tabla externa sobre HDFS con `OpenCSVSerde` y todas las columnas `STRING`. Respeta las comillas y conserva el dato original para auditarlo.
2. **`ventas`**: tabla analítica en **ORC + Snappy** con `DATE`, `DECIMAL(12,4)`, `DECIMAL(4,2)` e `INT`, más tres columnas derivadas (`order_year`, `order_month`, `days_to_ship`).

**Diccionario de datos:** [docs/diccionario_datos.md](docs/diccionario_datos.md)
**DDL:** [hql/p01_ddl.hql](hql/p01_ddl.hql) · **DML:** [hql/p01_carga_dml.hql](hql/p01_carga_dml.hql) · **Carga:** [scripts/cargar_datos.sh](scripts/cargar_datos.sh)

**Procedimiento de carga**
1. `iconv -f WINDOWS-1252 -t UTF-8` convierte la codificación.
2. `hdfs dfs -put` sube el archivo a `hdfs://yarn-resourcemanager:9000/user/hive/raw/superstore/` (factor de replicación 3).
3. La tabla externa `stg_superstore_raw` lee el archivo y salta la cabecera (`skip.header.line.count=1`).
4. `INSERT OVERWRITE TABLE ventas SELECT ...` convierte los tipos: fechas con `UNIX_TIMESTAMP(...,'M/d/yyyy')`, montos con `CAST AS DECIMAL`, `LPAD` en el código postal y `REGEXP_REPLACE` del espacio no separable `U+00A0`.

**Evidencia:** [p01_carga_hdfs.txt](evidencias/salidas/p01_carga_hdfs.txt), [p01_ddl.txt](evidencias/salidas/p01_ddl.txt), [p01_carga_dml.txt](evidencias/salidas/p01_carga_dml.txt) · capturas 01–04.

**Resultado**

| Verificación | Valor |
|---|---|
| Líneas del archivo en HDFS | 9 995 (9 994 + cabecera) |
| Registros en `stg_superstore_raw` | 9 994 |
| Registros en `ventas` | 9 994 |
| Por año | 2014: 1 993 · 2015: 2 102 · 2016: 2 587 · 2017: 3 312 |

**Interpretación.** El conteo coincide en las tres etapas (archivo, staging y tabla analítica), así que no se perdieron filas al convertir los tipos. Separar staging y tabla analítica permite volver a transformar sin recargar el archivo y auditar el texto original en la P2.

**Conclusión.** El modelo queda cargado de forma íntegra y tipada. Las ventas crecen en volumen de líneas año tras año (+66 % entre 2014 y 2017).

---

## Pregunta 2. Auditoría de calidad e integridad de datos

**Enunciado:** total de registros, duplicados, órdenes y clientes únicos, NULL, fechas inválidas, ventas ≤ 0, descuentos fuera de rango, envíos anteriores al pedido; consulta resumen y criterios de tratamiento.

**Estrategia.** Se audita sobre dos capas. Sobre **staging** se revisa si cada fecha de texto se puede convertir: la fecha se re-formatea y se compara con el original para detectar fechas imposibles. Sobre la tabla **tipada** se revisan las reglas de negocio con `SUM(IF(...))`. La consulta resumen junta todos los indicadores con `UNION ALL` dentro de un CTE y marca cada uno como OK, REVISAR o INFORMATIVO.

**Consulta:** [hql/p02_calidad_datos.hql](hql/p02_calidad_datos.hql) · **Evidencia:** [p02_calidad_datos.txt](evidencias/salidas/p02_calidad_datos.txt) · capturas 05–08.

**Resultado (consulta resumen)**

| # | Indicador | Valor | % | Estado |
|---|-----------|------:|--:|--------|
| 1 | Total de registros | 9 994 | 100,00 | Informativo |
| 2 | Row ID duplicados | 0 | 0,00 | OK |
| 3 | Órdenes únicas | 5 009 | — | Informativo |
| 4 | Clientes únicos | 793 | — | Informativo |
| 5 | Filas con NULL en campos clave (20 campos revisados) | 0 | 0,00 | OK |
| 6 | Fechas inválidas o fuera de periodo | 0 | 0,00 | OK |
| 7 | Ventas ≤ 0 | 0 | 0,00 | OK |
| 8 | Descuento fuera de [0, 1] (rango real 0,00–0,80) | 0 | 0,00 | OK |
| 9 | Envío anterior al pedido (días de envío 0–7) | 0 | 0,00 | OK |
| 10 | Product ID con varios nombres | 32 | 0,32 | **Revisar** |
| 11 | Líneas con ganancia negativa | 1 871 | 18,72 | Informativo |

Además: 16 nombres de producto aparecen con más de un ID, y ningún cliente ni orden tiene atributos contradictorios.

**Criterios de tratamiento**

| Inconsistencia | Tratamiento propuesto |
|---|---|
| Fecha no convertible o fuera de 2014–2017 | Queda en NULL al tipar. Se excluye de los análisis temporales y se reporta para corregir en origen. |
| Row ID duplicado | Se conserva una fila con `ROW_NUMBER() OVER (PARTITION BY row_id ORDER BY order_date)` = 1. |
| Ventas ≤ 0 o cantidad ≤ 0 | Se excluye: una venta sin importe no es una transacción válida. |
| Descuento < 0 o > 1 | Se excluye o se recorta al intervalo [0, 1] según la regla del negocio. |
| `ship_date < order_date` | Se marca como inválido y se excluye de los cálculos de tiempo de envío. |
| Product ID con varios nombres | Error del catálogo de origen. Se agrupa por `product_id` (clave de negocio) y se muestra un nombre de referencia. Lo ideal sería una dimensión de productos depurada. |
| Ganancia negativa | **No se corrige**: son pérdidas reales (ver P6). |
| Codificación y `U+00A0` | Conversión a UTF-8 y `REGEXP_REPLACE` durante la carga. |

**Interpretación.** El dataset viene limpio en lo estructural: no hay nulos, duplicados, fechas imposibles ni montos inválidos. El único problema real de integridad es de catálogo (IDs con dos nombres). El 18,7 % de líneas con pérdida no es un error de datos, sino una señal de negocio.

**Conclusión.** Los datos son confiables para el análisis. Solo hace falta cuidado al analizar por producto, por eso se agrupa por `product_id`.

---

## Pregunta 3. Análisis de evolución comercial por región

**Enunciado:** ventas y ganancia por región y año, margen, variación porcentual interanual y región con mejor y peor desempeño, usando CTE y funciones de ventana.

**Estrategia.** El CTE `base` agrega por región y año. El CTE `evolucion` aplica `LAG() OVER (PARTITION BY region ORDER BY anio)` para traer el año anterior y `RANK() OVER (PARTITION BY anio ...)` para ordenar las regiones dentro de cada año. Una segunda consulta acumula 2014–2017 y usa `RANK()` y `SUM() OVER ()` para la participación y la clasificación.

**Consulta:** [hql/p03_evolucion_region.hql](hql/p03_evolucion_region.hql) · **Evidencia:** [p03_evolucion_region.txt](evidencias/salidas/p03_evolucion_region.txt) · capturas 09–10.

**Resultado (año por región)**

| Región | Año | Ventas | Ganancia | Margen % | Var. ventas % | Var. ganancia % |
|--------|-----|-------:|---------:|---------:|--------------:|----------------:|
| Central | 2014 | 103 838,16 | 539,55 | 0,52 | — | — |
| Central | 2015 | 102 874,22 | 11 716,80 | 11,39 | −0,93 | 2 071,57 |
| Central | 2016 | 147 429,38 | 19 899,16 | 13,50 | 43,31 | 69,83 |
| Central | 2017 | 147 098,13 | 7 550,84 | 5,13 | −0,22 | −62,05 |
| East | 2014 | 128 680,46 | 17 059,61 | 13,26 | — | — |
| East | 2015 | 156 332,06 | 21 091,01 | 13,49 | 21,49 | 23,63 |
| East | 2016 | 180 685,82 | 20 141,60 | 11,15 | 15,58 | −4,50 |
| East | 2017 | 213 082,90 | 33 230,56 | 15,60 | 17,93 | 64,98 |
| South | 2014 | 103 845,84 | 11 879,12 | 11,44 | — | — |
| South | 2015 | 71 359,98 | 8 318,59 | 11,66 | −31,28 | −29,97 |
| South | 2016 | 93 610,22 | 17 702,81 | 18,91 | 31,18 | 112,81 |
| South | 2017 | 122 905,86 | 8 848,91 | 7,20 | 31,30 | −50,01 |
| West | 2014 | 147 883,03 | 20 065,69 | 13,57 | — | — |
| West | 2015 | 139 966,25 | 20 492,19 | 14,64 | −5,35 | 2,13 |
| West | 2016 | 187 480,18 | 24 051,61 | 12,83 | 33,95 | 17,37 |
| West | 2017 | 250 128,37 | 43 808,96 | 17,51 | 33,42 | 82,15 |

**Acumulado 2014–2017**

| Región | Ventas | Ganancia | Margen % | Crec. 14→17 % | Part. ventas % | Clasificación |
|--------|-------:|---------:|---------:|--------------:|---------------:|---------------|
| West | 725 457,82 | 108 418,45 | 14,94 | 69,14 | 31,58 | **Mejor desempeño** |
| East | 678 781,24 | 91 522,78 | 13,48 | 65,59 | 29,55 | — |
| South | 391 721,91 | 46 749,43 | 11,93 | 18,35 | 17,05 | — |
| Central | 501 239,89 | 39 706,36 | 7,92 | 41,66 | 21,82 | **Peor desempeño** |

**Interpretación.** West lidera en ventas, ganancia y margen, y es primera en ventas en tres de los cuatro años. Central vende más que South (21,8 % frente a 17,1 %), pero gana menos: tiene el margen más bajo (7,9 %), y en 2017 sus ventas se mantuvieron mientras su ganancia cayó 62 %. South es la región más volátil: cayó 31 % en 2015 y en 2017 creció 31 % en ventas, pero perdió la mitad de su ganancia.

**Conclusión.** La mejor región es **West** y la peor es **Central**. El problema de Central no es de volumen sino de rentabilidad: vender más con menos margen sugiere un exceso de descuentos (lo confirma la P6).

---

## Pregunta 4. Segmentación avanzada de clientes mediante RFM

**Enunciado:** calcular Recency, Frequency y Monetary por cliente, puntuarlos, clasificarlos e identificar clientes de alto valor, recurrentes y en riesgo, justificando los criterios.

**Estrategia**
- **Fecha de referencia:** `MAX(order_date)` = **2017-12-30**.
- **R** = `DATEDIFF(fecha_ref, última compra)` · **F** = `COUNT(DISTINCT order_id)` · **M** = `SUM(sales)`.
- **Puntuación 1–5 con `NTILE(5)`:** cada nota agrupa alrededor del 20 % de los clientes. R se ordena descendente (menos días da nota 5); F y M, ascendente. Se usan quintiles en lugar de umbrales fijos porque se adaptan a la distribución real de los datos.
- El resultado se guarda en la tabla `rfm_clientes` (ORC).

**Rangos reales de cada puntuación**

| Score | Recency (días) | Frequency (órdenes) | Monetary (USD) |
|------:|----------------|---------------------|----------------|
| 5 | 0 – 26 | 9 – 17 | 4 299 – 25 043 |
| 4 | 26 – 52 | 7 – 9 | 2 767 – 4 283 |
| 3 | 53 – 102 | 5 – 7 | 1 745 – 2 754 |
| 2 | 103 – 224 | 4 – 5 | 965 – 1 740 |
| 1 | 225 – 1 165 | 1 – 4 | 4,83 – 959 |

**Criterios de segmentación (se evalúan en orden)**

| Segmento | Regla | Justificación |
|---|---|---|
| Alto valor (Campeones) | R ≥ 4, F ≥ 4 y M ≥ 4 | Compraron hace poco, compran seguido y gastan mucho |
| Recurrentes / Leales | F ≥ 4 y R ≥ 3 | Compran a menudo y siguen activos, aunque gasten menos |
| En riesgo de abandono | R ≤ 2 y (F ≥ 3 o M ≥ 3) | Fueron buenos clientes, pero llevan más de 100 días sin comprar |
| Nuevos / Prometedores | R ≥ 4 y F ≤ 2 | Activos recientes con pocas órdenes |
| Perdidos / Inactivos | R ≤ 2, F ≤ 2 y M ≤ 2 | Poco valor y sin actividad reciente |
| Necesitan atención | Resto | Perfil intermedio |

**Consulta:** [hql/p04_rfm_clientes.hql](hql/p04_rfm_clientes.hql) · **Evidencia:** [p04_rfm_clientes.txt](evidencias/salidas/p04_rfm_clientes.txt) · capturas 11–14.

**Resultado**

| Segmento | Clientes | % clientes | Recency prom. | Frequency prom. | Monetary prom. | % ventas |
|----------|---------:|-----------:|--------------:|----------------:|---------------:|---------:|
| Alto valor (Campeones) | 105 | 13,24 | 24,8 | 9,3 | 5 269,17 | 24,08 |
| Recurrentes / Leales | 129 | 16,27 | 50,0 | 8,5 | 2 749,46 | 15,44 |
| En riesgo de abandono | 199 | 25,09 | 255,9 | 6,7 | 3 480,32 | **30,15** |
| Nuevos / Prometedores | 87 | 10,97 | 25,1 | 4,1 | 1 811,13 | 6,86 |
| Perdidos / Inactivos | 119 | 15,01 | 383,1 | 3,4 | 786,76 | 4,08 |
| Necesitan atención | 154 | 19,42 | 56,4 | 5,4 | 2 892,73 | 19,39 |

Top de alto valor: Adrian Barton (14 473,57 USD; RFM 455), Ken Lonsdale y Sanjit Engle. En riesgo, el caso más importante es **Tamara Chand**: 19 052,22 USD y 8 981 USD de ganancia, pero 399 días sin comprar.

**Interpretación.** El 13 % de los clientes (Campeones) genera el 24 % de las ventas. El hallazgo más importante es que el segmento **en riesgo** concentra el **30 % de las ventas históricas**: son clientes valiosos (6,7 órdenes y 3 480 USD en promedio) que no compran desde hace 256 días en promedio.

**Conclusión.** La prioridad comercial es una campaña de reactivación para los 199 clientes en riesgo, empezando por los de mayor monto. A los Campeones y Recurrentes conviene fidelizarlos, y a los Nuevos, convertirlos en compradores frecuentes.

---

## Pregunta 5. Ranking de productos según rentabilidad

**Enunciado:** top 5 de ganancia por categoría, top 5 en volumen de ventas, 5 productos menos rentables, margen individual y posición en la categoría, usando `RANK()`, `DENSE_RANK()` y agregación acumulativa.

**Estrategia.** Se agrega por `product_id` (1 862 productos) en la tabla `productos_kpi` y se calcula:
- `RANK() OVER (PARTITION BY category ORDER BY ganancia DESC)` para la posición dentro de la categoría.
- `DENSE_RANK() OVER (ORDER BY ventas DESC)` para el ranking por volumen de ventas.
- `SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC ROWS UNBOUNDED PRECEDING)` para la ganancia acumulada y el % acumulado de la categoría.
- `ganancia / ventas * 100` para el margen individual.

**Consulta:** [hql/p05_ranking_productos.hql](hql/p05_ranking_productos.hql) · **Evidencia:** [p05_ranking_productos.txt](evidencias/salidas/p05_ranking_productos.txt) · capturas 15–19.

**Resultado — Top 5 por ganancia en cada categoría**

| Categoría | # | Producto | Ganancia | Margen % | % acum. categoría |
|-----------|--:|----------|---------:|---------:|------------------:|
| Furniture | 1 | Hon Deluxe Fabric Upholstered Stacking Chairs | 1 927,44 | 18,12 | 10,45 |
| Furniture | 5 | Office Star Professional Matrix Back Chair | 1 305,65 | 14,88 | 41,85 |
| Office Supplies | 1 | Fellowes PB500 Electric Punch Binding Machine | 7 753,04 | 28,24 | 6,33 |
| Office Supplies | 5 | Ibico Ibimaster 300 Manual Binding System | 2 318,34 | 29,03 | 15,66 |
| Technology | 1 | Canon imageCLASS 2200 Advanced Copier | 25 199,93 | 40,91 | 17,32 |
| Technology | 5 | HP Designjet T520 Large Format Printer | 4 094,98 | 22,29 | 31,13 |

*(La tabla completa de los 15 productos está en la evidencia.)*

**Top 5 por volumen de ventas**

| # | Producto | Ventas | Ganancia | Margen % | Puesto en su categoría |
|--:|----------|-------:|---------:|---------:|-----------------------:|
| 1 | Canon imageCLASS 2200 Advanced Copier | 61 599,82 | 25 199,93 | 40,91 | 1 |
| 2 | Fellowes PB500 Electric Punch Binding Machine | 27 453,38 | 7 753,04 | 28,24 | 1 |
| 3 | Cisco TelePresence System EX90 | 22 638,48 | **−1 811,08** | −8,00 | 401 de 404 |
| 4 | HON 5400 Series Task Chairs for Big and Tall | 21 870,58 | 0,00 | 0,00 | 253 de 375 |
| 5 | GBC DocuBind TL300 Electric Binding System | 19 823,48 | 2 233,51 | 11,27 | 6 |

**Cinco productos menos rentables**

| # | Producto | Ventas | Ganancia | Margen % |
|--:|----------|-------:|---------:|---------:|
| 1 | Cubify CubeX 3D Printer Double Head Print | 11 099,96 | −8 879,97 | −80,00 |
| 2 | Lexmark MX611dhe Monochrome Laser Printer | 16 829,90 | −4 589,97 | −27,27 |
| 3 | Cubify CubeX 3D Printer Triple Head Print | 7 999,98 | −3 839,99 | −48,00 |
| 4 | Chromcraft Bull-Nose Wood Oval Conference Tables | 9 917,64 | −2 876,12 | −29,00 |
| 5 | Bush Advantage Collection Racetrack Conference Table | 9 544,73 | −1 934,40 | −20,27 |

**Resumen por categoría:** Technology 404 productos, 54 con pérdida, margen 17,40 % · Office Supplies 1 083, 124 con pérdida, margen 17,04 % · **Furniture 375, 121 con pérdida (32 %), margen 2,49 %**.

**Interpretación.** Vender mucho no garantiza ganar: dos de los cinco productos más vendidos no dejan ganancia (Cisco TelePresence pierde 1 811 USD y HON 5400 queda en cero). En Technology, un solo producto (Canon imageCLASS 2200) aporta el 17 % de la ganancia de la categoría. Las mayores pérdidas se concentran en impresoras 3D y mesas de conferencia.

**Conclusión.** Hay que revisar el precio y los descuentos de las impresoras Cubify y de las mesas de Furniture, y proteger el margen de las copiadoras Canon/HP, que son las más rentables. Furniture tiene la peor salud: casi un tercio de sus productos pierde dinero.

---

## Pregunta 6. Análisis del impacto de los descuentos

**Enunciado:** clasificar los registros en sin descuento, bajo (0–20 %], medio (20–50 %] y alto (> 50 %); calcular ventas, ganancias, margen, registros con pérdida, % no rentables, descuento promedio y categorías y subcategorías más afectadas; concluir si los descuentos altos se asocian a más pérdidas.

**Estrategia.** La vista `v_ventas_descuento` asigna el rango con `CASE`. Sobre ella se agrega por rango, por descuento exacto y por categoría × rango. Además se calcula la correlación de Pearson (`CORR`) entre el descuento y la ganancia, el margen y la pérdida, y se ordenan las subcategorías con `RANK()` según la ganancia que pierden cuando el descuento supera el 20 %.

**Consulta:** [hql/p06_impacto_descuentos.hql](hql/p06_impacto_descuentos.hql) · **Evidencia:** [p06_impacto_descuentos.txt](evidencias/salidas/p06_impacto_descuentos.txt) · capturas 20–23.

**Resultado por rango**

| Rango | Registros | Ventas | Ganancia | Margen % | Con pérdida | % no rentables | Desc. prom. % |
|-------|----------:|-------:|---------:|---------:|------------:|---------------:|--------------:|
| Sin descuento | 4 798 | 1 087 908,47 | 320 987,60 | 29,51 | 0 | 0,00 | 0,00 |
| Bajo (0–20 %] | 3 803 | 846 522,24 | 100 785,47 | 11,91 | 523 | 13,75 | 19,68 |
| Medio (20–50 %] | 537 | 298 541,41 | −58 817,00 | −19,70 | 492 | 91,62 | 36,70 |
| Alto (> 50 %) | 856 | 64 228,74 | −76 559,05 | −119,20 | 856 | **100,00** | 71,89 |

**Correlaciones:** descuento–margen **−0,86** · descuento–pérdida **+0,75** · descuento–ganancia −0,22.

**Subcategorías más afectadas (ganancia perdida con descuento > 20 %):** Binders −38 510,50 · **Tables −30 698,22** (ganancia total negativa, 63,6 % no rentables) · Machines −29 555,35 · Bookcases −11 097,76 (ganancia total negativa).
**Categorías:** Furniture con descuento medio tiene 96 % de líneas no rentables. En las tres categorías, el descuento alto da 100 % de pérdidas.

| Grupo | Registros | No rentables | % | Ganancia neta |
|-------|----------:|-------------:|--:|--------------:|
| Descuento ≤ 20 % | 8 601 | 523 | 6,08 | 421 773,08 |
| Descuento > 20 % | 1 393 | 1 348 | **96,77** | **−135 376,06** |

**Interpretación.** La relación es clara y casi lineal: a mayor descuento, menor margen (correlación −0,86). Hasta el 20 % el negocio sigue siendo rentable (margen 11,9 %). Desde el 30 % el margen se vuelve negativo, y desde el 50 % **todas** las operaciones pierden dinero. El 14 % de las líneas con descuento > 20 % destruye 135 mil USD, casi un tercio de la ganancia que generan las demás.

**Conclusión.** **Sí**, los descuentos elevados están asociados a una proporción mucho mayor de operaciones no rentables (96,8 % frente a 6,1 %). Se recomienda limitar los descuentos al 20 %, sobre todo en Tables, Bookcases, Binders y Machines.

---

## Pregunta 7. Análisis de tendencias temporales

**Enunciado:** ventas y ganancias mensuales, variación frente al mes anterior y al mismo mes del año anterior, promedio móvil de 3 meses y los 3 meses con mayor y menor venta, usando `LAG()` y funciones de ventana.

**Estrategia.** La tabla `ventas_mensuales` agrega los 48 meses. Sobre ella se calcula:
- `LAG(ventas,1) OVER (ORDER BY periodo)` para el mes anterior.
- `LAG(ventas,1) OVER (PARTITION BY mes ORDER BY anio)` para el mismo mes del año anterior.
- `AVG(ventas) OVER (ORDER BY periodo ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` para el promedio móvil.
- `RANK()` ascendente y descendente para los extremos.
- Un análisis estacional (promedio por mes) y el acumulado anual con `SUM(SUM()) OVER`.

**Consulta:** [hql/p07_tendencias_mensuales.hql](hql/p07_tendencias_mensuales.hql) · **Evidencia:** [p07_tendencias_mensuales.txt](evidencias/salidas/p07_tendencias_mensuales.txt) · capturas 24–27.

**Resultado (extracto; la serie completa de 48 meses está en la evidencia)**

| Periodo | Ventas | Ganancia | Var. mensual % | Var. interanual % | Prom. móvil 3m |
|---------|-------:|---------:|---------------:|------------------:|---------------:|
| 2016-12 | 96 999,04 | 17 885,31 | 22,15 | 29,47 | 78 699,59 |
| 2017-01 | 43 971,37 | 7 140,44 | −54,67 | 137,14 | 73 460,79 |
| 2017-09 | 87 866,65 | 10 991,56 | 39,20 | 19,69 | 65 417,32 |
| 2017-11 | 118 447,83 | 9 690,10 | 52,29 | 49,16 | 94 697,13 |
| 2017-12 | 83 829,32 | 8 483,35 | −29,23 | −13,58 | 93 351,36 |

| Tipo | Puesto | Periodo | Ventas |
|------|-------:|---------|-------:|
| Mayor venta | 1 | 2017-11 | 118 447,83 |
| Mayor venta | 2 | 2016-12 | 96 999,04 |
| Mayor venta | 3 | 2017-09 | 87 866,65 |
| Menor venta | 1 | 2014-02 | 4 519,89 |
| Menor venta | 2 | 2015-02 | 11 951,41 |
| Menor venta | 3 | 2014-01 | 14 236,90 |

**Estacionalidad (peso de cada mes):** noviembre 15,3 % · diciembre 14,2 % · septiembre 13,4 % · febrero 2,6 % · enero 4,1 %.
**Anual:** 2014: 484 247,51 · 2015: 470 532,51 · 2016: 609 205,60 · 2017: 733 215,26 (acumulado 2,30 millones).

**Interpretación.** La serie tiene una estacionalidad muy marcada: septiembre, noviembre y diciembre concentran el 43 % de las ventas promedio del año, y enero y febrero son siempre los meses más bajos. Por eso la variación mensual es muy volátil (por ejemplo, −54 % de diciembre a enero), mientras que la comparación interanual y el promedio móvil muestran mejor la tendencia, que es creciente: 2017 vendió 51 % más que 2014. La ganancia no sigue a las ventas al mismo ritmo: noviembre de 2017 es récord en ventas, pero tiene un margen de solo 8,2 %.

**Conclusión.** La tendencia es positiva, con picos en el último cuatrimestre. Conviene planificar inventario y personal para septiembre–diciembre y cuidar los descuentos de esa temporada, que reducen el margen.

---

## Pregunta 8. Análisis Pareto de ventas y rentabilidad

**Enunciado:** cuántos productos representan el 80 % de las ventas y cuántos el 80 % de las ganancias: ordenar, calcular la participación individual, identificar los productos que concentran la contribución y comparar ambos resultados.

**Estrategia.** Por producto se calcula:
- `ROW_NUMBER() OVER (ORDER BY valor DESC)` para el orden de contribución.
- `valor / SUM(valor) OVER ()` para la participación individual.
- `SUM(valor) OVER (ORDER BY valor DESC ROWS UNBOUNDED PRECEDING)` para el % acumulado.

Un producto entra al grupo del 80 % si el acumulado **previo** a él es menor que 80 %, lo que incluye al producto que cruza el umbral. En ganancias hay productos con pérdida, así que el total neto es menor que la suma de los positivos. Por eso se calcula con dos bases: la neta y la de solo productos con ganancia.

**Consulta:** [hql/p08_pareto.hql](hql/p08_pareto.hql) · **Evidencia:** [p08_pareto.txt](evidencias/salidas/p08_pareto.txt) · capturas 28–33.

**Resultado**

| Análisis | Productos en el 80 % | Total de productos | % de productos |
|----------|---------------------:|-------------------:|---------------:|
| a) Ventas | **414** | 1 862 | **22,23 %** |
| b) Ganancias (base neta 286 397 USD) | **164** | 1 862 | **8,81 %** |
| b) Ganancias (base solo positivos 363 118 USD) | 340 | 1 557 | 21,84 % |

Productos con mayor contribución: **Canon imageCLASS 2200** (2,68 % de las ventas y **8,80 % de la ganancia**), Fellowes PB500 (1,20 % / 2,71 %), HP LaserJet 3310 Copier (0,82 % / 2,44 %).

| Grupo | Productos | Ganancia |
|-------|----------:|---------:|
| Con ganancia | 1 557 | 363 118,15 |
| Con pérdida | 299 | −76 721,13 |
| Sin ganancia | 6 | 0,00 |

Por categoría (en el Pareto de ventas / de ganancia / con pérdida): Furniture 156 / 31 / **73** · Office Supplies 101 / 52 / 25 · Technology 157 / 81 / 13.

**Comparación e interpretación.** Las ventas cumplen casi exactamente la regla 80/20: el 22 % de los productos genera el 80 % de los ingresos. La ganancia está **mucho más concentrada**: solo el 8,8 % de los productos (164) genera el 80 % de la ganancia neta. Hay dos razones:
1. Los 299 productos con pérdida restan 76 721 USD. El total neto es menor y el acumulado de los mejores productos llega antes al 80 % (de hecho supera el 100 % y alcanza 126,8 % antes de que las pérdidas lo bajen).
2. Muchos productos que venden mucho tienen margen bajo o negativo: 73 de los 156 productos de Furniture que están en el Pareto de ventas pierden dinero.

Con la base de solo productos con ganancia, la concentración vuelve a ser parecida a la de ventas (21,8 %). Esto confirma que la diferencia la explican las pérdidas.

**Conclusión.** La ganancia depende de un grupo pequeño de productos, sobre todo copiadoras y equipos de Technology. Ese grupo hay que protegerlo en stock y precio. Los productos que venden mucho pero pierden, la mayoría de Furniture, deben revisarse en precio, descuento y costo logístico.

---

## Análisis de optimización

Detalle completo en [docs/optimizacion.md](docs/optimizacion.md).

| Técnica | Resultado |
|---------|-----------|
| ORC + Snappy frente a TEXTFILE | 374 566 frente a 2 425 507 bytes: **6,5 veces menos** espacio |
| Particionamiento por `order_year` | El filtro de 2017 lee **3 312 de 9 994 filas**, solo la partición `order_year=2017` |
| Bucketing por `customer_id` (4) | 4 archivos por partición |
| Estadísticas + `compute.query.using.stats` | `COUNT(*)` en 0,056 s sin lanzar un job |
| Vectorización | Activa en la fase Map sobre ORC; el Reduce necesita Tez o Spark |

Con 2,2 MB, los tiempos están dominados por el arranque de MapReduce (alrededor de 2,4 s en todas las variantes). La ganancia se ve en los planes de ejecución, que son los que escalan con el volumen.

---

## Conclusiones generales

1. **Calidad.** El dataset es estructuralmente íntegro: sin nulos, duplicados ni fechas o montos inválidos. La única inconsistencia relevante es de catálogo (32 IDs de producto con dos nombres), y se resolvió agrupando por `product_id`.
2. **Crecimiento.** Las ventas crecieron 51 % entre 2014 y 2017 (de 484 mil a 733 mil USD), con una fuerte estacionalidad en septiembre–diciembre.
3. **Regiones.** West es la región más fuerte (31,6 % de las ventas y margen de 14,9 %). Central es la más débil en rentabilidad (margen de 7,9 %), pese a vender más que South.
4. **Descuentos.** Son el principal destructor de valor. Por encima del 20 %, el 96,8 % de las operaciones pierde dinero, con una pérdida neta de 135 mil USD. La correlación descuento–margen es −0,86.
5. **Productos.** La ganancia está muy concentrada: el 8,8 % de los productos genera el 80 % de la ganancia neta, frente al 22 % que genera el 80 % de las ventas. Furniture concentra los productos que venden mucho y pierden.
6. **Clientes.** El segmento en riesgo de abandono reúne el 30 % de las ventas históricas, así que reactivarlo es la oportunidad comercial más grande.
7. **Técnico.** El modelo staging + ORC particionado, junto con funciones de ventana, permite resolver todo el análisis en HiveQL sobre HDFS. Para volúmenes reales conviene migrar el motor de MapReduce a Tez o Spark.

**Recomendación principal:** poner un tope de descuento del 20 %, revisar los precios de Furniture (Tables y Bookcases) y lanzar una campaña de reactivación para los clientes en riesgo de mayor valor.
