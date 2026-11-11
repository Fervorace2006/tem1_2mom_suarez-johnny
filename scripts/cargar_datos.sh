#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
CONTAINER=hive-server
SRC="data/Sample - Superstore.csv"

docker cp "$SRC" $CONTAINER:/tmp/superstore_cp1252.csv
docker exec $CONTAINER bash -c "
  iconv -f WINDOWS-1252 -t UTF-8 /tmp/superstore_cp1252.csv > /tmp/superstore.csv &&
  hdfs dfs -mkdir -p /user/hive/raw/superstore &&
  hdfs dfs -put -f /tmp/superstore.csv /user/hive/raw/superstore/superstore.csv &&
  hdfs dfs -ls -h /user/hive/raw/superstore &&
  echo 'Lineas del archivo (incluye cabecera):' && wc -l < /tmp/superstore.csv
"
