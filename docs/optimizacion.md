# Análisis de optimización

Script: [`hql/p09_optimizacion.hql`](../hql/p09_optimizacion.hql) · Evidencia: [`evidencias/salidas/p09_optimizacion.txt`](../evidencias/salidas/p09_optimizacion.txt)

## Técnicas aplicadas

| Técnica | Implementación | Propósito |
|---------|----------------|-----------|
| Formato columnar | `ventas` en **ORC + Snappy** | Leer solo las columnas usadas y comprimir |
| Particionamiento | `ventas_part PARTITIONED BY (order_year)` con particionamiento dinámico | *Partition pruning*: filtrar por año sin leer los demás años |
| Bucketing | `CLUSTERED BY (customer_id) INTO 4 BUCKETS` | Distribuir los datos por cliente para joins/muestreos por cliente |
| Estadísticas | `ANALYZE TABLE ... COMPUTE STATISTICS [FOR COLUMNS]` | Que el optimizador conozca filas y tamaños; respuestas desde metadatos |
| Respuesta por estadísticas | `hive.compute.query.using.stats=true` | `COUNT(*)` sin lanzar un job |
| Vectorización | `hive.vectorized.execution.enabled=true` | Procesar lotes de 1024 filas en vez de fila por fila |
| Ajuste de memoria | `mapreduce.task.io.sort.mb=16` | Evitar `OutOfMemoryError` en el modo local de HiveServer2 (heap de 256 MB) |

## Resultados medidos

### Almacenamiento: TEXTFILE vs ORC

| Tabla | Formato | numRows | totalSize (bytes) | Tamaño relativo |
|-------|---------|--------:|------------------:|----------------:|
| `ventas_texto` | TEXTFILE | 9 994 | 2 425 507 | 100 % |
| `ventas` | ORC + Snappy | 9 994 | 374 566 | **15,4 %** |
| `ventas_part` (partición 2017) | ORC + Snappy, 4 buckets | 3 312 | 219 756 | — |

Con ORC el mismo contenido ocupa **6,5 veces menos** en HDFS. Esto reduce la lectura de disco y el tráfico de red entre los datanodes.

### Poda de particiones (EXPLAIN)

Consulta: `SELECT region, SUM(sales) ... WHERE order_year = 2017 GROUP BY region`

| Tabla | Filas que el plan estima leer (TableScan) | Particiones leídas |
|-------|------------------------------------------:|--------------------|
| `ventas` (sin particionar) | 9 994 | toda la tabla |
| `ventas_part` | **3 312** | solo `order_year=2017` |

`EXPLAIN DEPENDENCY` lo confirma: `"input_partitions":[{"partitionName":"superstore@ventas_part@order_year=2017"}]`. La consulta lee el 33 % de los datos.

### Estadísticas y vectorización

- Con las estadísticas calculadas, `SELECT COUNT(*) FROM ventas` responde en **0,056 s** sin lanzar un job MapReduce. Una agregación normal tarda alrededor de 2,4 s.
- `EXPLAIN VECTORIZATION` muestra `enabled: true` para la fase Map sobre ORC (`inputFileFormats: OrcInputFormat`). La fase Reduce queda en `enabled: false` porque el motor de ejecución es MapReduce: la vectorización del Reduce requiere Tez o Spark.

### Tiempos

Las tres variantes de la consulta por región en 2017 tardaron casi lo mismo (TEXT 2,42 s, ORC 2,41 s, particionada 2,45 s). Con un dataset de 2,2 MB, el tiempo lo domina el arranque del job MapReduce y no la lectura. La mejora se ve en los planes de ejecución (filas y bytes leídos), que es lo que escala cuando el volumen crece a GB o TB.

## Conclusión

Para este modelo, la configuración recomendada es **ORC + Snappy, particionado por año y con estadísticas actualizadas**. Las consultas analíticas filtran casi siempre por periodo (P3, P7), así que la partición por `order_year` es la más útil. Si el volumen creciera, el siguiente paso sería cambiar el motor a Tez o Spark para aprovechar la vectorización completa y evitar la latencia de arranque de MapReduce.
