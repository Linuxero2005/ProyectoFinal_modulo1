#!/bin/bash
# normalizar.sh - Convierte el log crudo en preparados/mediciones_sec.txt (formato que lee el programa en C).

# 0. Preparacion:
# Igual que en capturar.sh, saco la raiz del proyecto a partir de la ruta del script.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
RAW_LOG="$RAIZ/capturas/telemetria_raw.log"
SALIDA="$RAIZ/preparados/mediciones_sec.txt"

# La etiqueta puede pasarse como primer argumento ($1); si no, usa AuditoriaCursoC.
ETIQUETA="${1:-AuditoriaCursoC}"

# 1. Validaciones iniciales:
# -r revisa que el log exista y se pueda leer; si no, no hay nada que normalizar.
if [ ! -r "$RAW_LOG" ]; then
    echo "ERROR: no se puede leer $RAW_LOG" >&2
    exit 1
fi

# La etiqueta no debe tener espacios y debe medir maximo 31 caracteres.
if ! [[ "$ETIQUETA" =~ ^[^[:space:]]{1,31}$ ]]; then
    echo "ERROR: la etiqueta debe ser una sola palabra de hasta 31 caracteres" >&2
    exit 1
fi

mkdir -p "$RAIZ/preparados" || exit 1

# 2. Extraer los registros:
# awk revisa cada linea del log y solo deja las que tienen:
#   NF==4 -> exactamente 4 campos (fecha hora CATEGORIA valor)
#   $3 que sea DISCO, PROCESOS o PERMISOS
#   $4 que sea un numero entero
# De cada linea buena imprime solo "CATEGORIA valor" (campos 3 y 4).
# NO uso sort ni uniq porque no se deben eliminar valores repetidos.
# El log original solo se lee, nunca se modifica.
TMP=$(mktemp) || exit 1
awk 'NF==4 && $3 ~ /^(DISCO|PROCESOS|PERMISOS)$/ && $4 ~ /^[0-9]+$/ {print $3, $4}' "$RAW_LOG" > "$TMP"

# 3. Contar registros:
# wc -l < archivo da solo el numero de lineas (sin el nombre del archivo).
TOTAL=$(wc -l < "$TMP")

# El maximo permitido en el encabezado es 200.
if [ "$TOTAL" -gt 200 ]; then
    echo "ERROR: hay $TOTAL registros y el maximo es 200" >&2
    rm -f "$TMP"
    exit 1
fi

# 4. Armar el archivo final:
# Primero la etiqueta, luego el total y despues los registros.
# Como TOTAL sale de las mismas lineas que se escriben, siempre coincide con el archivo.
{
    echo "$ETIQUETA"
    echo "$TOTAL"
    cat "$TMP"
} > "$SALIDA"

# Borro el archivo temporal que ya no sirve.
rm -f "$TMP"
