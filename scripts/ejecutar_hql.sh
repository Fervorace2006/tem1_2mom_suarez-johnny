#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
CONTAINER=hive-server
FILE="$1"
NAME=$(basename "$FILE" .hql)
OUT="evidencias/salidas/${NAME}.txt"

docker cp "$FILE" $CONTAINER:/tmp/${NAME}.hql
{
  echo "### Ejecución: $FILE"
  echo "### Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "### Comando: beeline -u jdbc:hive2://localhost:10000 -n root -f ${NAME}.hql"
  echo
  docker exec $CONTAINER /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root \
      --hiveconf mapreduce.task.io.sort.mb=16 \
      --hiveconf hive.server2.logging.operation.level=NONE \
      --showHeader=true --outputformat=table \
      -f /tmp/${NAME}.hql 2>&1 | grep -v -E '^SLF4J'
} > "$OUT"
if grep -q -E '^Error:' "$OUT"; then
  echo "ATENCION: hubo errores en $OUT"; grep -E '^Error:' "$OUT"; exit 1
fi
echo "Salida guardada en $OUT"
