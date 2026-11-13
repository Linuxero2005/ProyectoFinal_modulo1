#!/bin/bash
# capturar.sh - Toma las 3 metricas (DISCO, PROCESOS, PERMISOS) y las agrega al log crudo.

# 0. Preparacion:
# $0 es la ruta de este script; dirname saca su carpeta y con /.. subimos a sec_guard.
# Asi el script funciona sin importar desde donde lo ejecute.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
RAW_LOG="$RAIZ/capturas/telemetria_raw.log"
EVID="$RAIZ/evidencias/capturas"

# mkdir -p crea las carpetas si no existen y no marca error si ya estan.
mkdir -p "$RAIZ/capturas" "$EVID" || exit 1

# FECHA y HORA van separadas en el log; SELLO sirve para nombrar las evidencias.
FECHA=$(date +%F)
HORA=$(date +%T)
SELLO=$(date +%Y%m%d_%H%M%S)

# 1. Metrica de DISCO:
# df -P "$HOME" consulta el sistema de archivos donde esta mi directorio personal.
# Guardo la salida completa en evidencias para poder comprobar de donde sale el dato.
df -P "$HOME" > "$EVID/df_$SELLO.txt" 2>&1
RC_DF=$?
# NR==2 toma la fila de datos (la 1 es el encabezado), $5 es la columna del porcentaje
# y gsub quita el simbolo % para quedarme solo con el numero.
DISCO=$(awk 'NR==2 {gsub("%","",$5); print $5}' "$EVID/df_$SELLO.txt")

# 2. Metrica de PROCESOS:
# ps -u "$USER" saca solo los procesos de mi usuario.
# --no-headers quita el encabezado para que wc -l cuente exactamente cuantos son.
ps -u "$USER" --no-headers > "$EVID/ps_$SELLO.txt" 2>&1
RC_PS=$?
PROCESOS=$(wc -l < "$EVID/ps_$SELLO.txt")

# 3. Metrica de PERMISOS:
# find busca dentro del proyecto ($RAIZ) solo archivos regulares (-type f)
# que tengan escritura para el grupo (-perm -g+w) o (-o) para otros (-perm -o+w).
# Cada archivo sale una sola vez aunque cumpla las dos condiciones.
find "$RAIZ" -type f \( -perm -g+w -o -perm -o+w \) > "$EVID/perm_$SELLO.txt" 2> "$EVID/perm_err_$SELLO.txt"
RC_FIND=$?
PERMISOS=$(wc -l < "$EVID/perm_$SELLO.txt")

# 4. Validaciones:
# Si alguna utileria fallo ($? distinto de 0), aviso por el error estandar (>&2)
# y salgo con 1. Asi nunca se guarda un 0 falso como si fuera una medicion real.
if [ $RC_DF -ne 0 ] || [ $RC_PS -ne 0 ] || [ $RC_FIND -ne 0 ]; then
    echo "[$FECHA $HORA] ERROR CRITICO: fallo una utileria (df=$RC_DF ps=$RC_PS find=$RC_FIND)" >&2
    exit 1
fi

# Verifico que cada valor sea un numero entero y este dentro de su intervalo permitido.
# =~ compara contra la expresion regular ^[0-9]+$ (solo digitos).
if ! [[ "$DISCO" =~ ^[0-9]+$ ]] || [ "$DISCO" -gt 100 ]; then
    echo "[$FECHA $HORA] ERROR: DISCO invalido ('$DISCO')" >&2
    exit 1
fi
if ! [[ "$PROCESOS" =~ ^[0-9]+$ ]] || [ "$PROCESOS" -gt 2000 ]; then
    echo "[$FECHA $HORA] ERROR: PROCESOS invalido ('$PROCESOS')" >&2
    exit 1
fi
if ! [[ "$PERMISOS" =~ ^[0-9]+$ ]] || [ "$PERMISOS" -gt 200 ]; then
    echo "[$FECHA $HORA] ERROR: PERMISOS invalido ('$PERMISOS')" >&2
    exit 1
fi

# 5. Guardado:
# Uso >> para ir agregando las lecturas al final del log sin borrar las anteriores.
# Formato: fecha hora CATEGORIA valor
echo "$FECHA $HORA DISCO $DISCO" >> "$RAW_LOG"
echo "$FECHA $HORA PROCESOS $PROCESOS" >> "$RAW_LOG"
echo "$FECHA $HORA PERMISOS $PERMISOS" >> "$RAW_LOG"
