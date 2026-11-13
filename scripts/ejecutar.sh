#!/bin/bash
# ejecutar.sh - Orquestador: limpieza, auditoria, captura, normalizacion, compilacion y analisis.
# No pide nada al usuario una vez invocado.
# Uso: ./scripts/ejecutar.sh [etiqueta] [num_capturas] [pausa_segundos]

# 0. Preparacion:
# Me muevo a la raiz del proyecto para que las rutas relativas funcionen desde donde lo ejecute.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ" || exit 1

# INICIO guarda la hora de arranque en segundos; al final sirve para comprobar que el informe es nuevo.
INICIO=$(date +%s)
ETIQUETA="${1:-AuditoriaCursoC}"
NUM_CAPTURAS="${2:-3}"
PAUSA="${3:-2}"

RAW_LOG="capturas/telemetria_raw.log"
ENTRADA="preparados/mediciones_sec.txt"
INFORME="resultados/informe_seguridad.txt"
FUENTE="fuentes/sec_engine.c"
BIN="fuentes/sec_engine"

# abortar: dice que etapa fallo y por que, borra cualquier informe y termina con codigo 1.
abortar() {
    echo "" >&2
    echo "[ejecutar] ERROR en la etapa '$1': $2" >&2
    echo "[ejecutar] Flujo detenido; no hay informe de esta ejecucion." >&2
    rm -f "$INFORME"
    exit 1
}

# 1. Limpieza preventiva:
# Borro lo generado antes para que una ejecucion que falle a medias no muestre algo viejo.
# OJO: no se borra paquete_auditoria.tar.gz, solo los archivos que salen de extraerlo.
echo "[1/7] Limpieza de residuos de ejecuciones anteriores"
rm -f "$INFORME" "$BIN" "$ENTRADA" "$RAW_LOG" \
      preparados/sshd_activo.txt preparados/usuarios_creados.txt preparados/conexiones_syn.txt \
      capturas/estaticos/secure.log capturas/estaticos/net_traffic.log capturas/estaticos/sshd_config \
  || abortar "limpieza" "no se pudo borrar algun archivo residual"

# Valido los parametros. El maximo es 66 porque 66 capturas x 3 categorias = 198 registros (limite: 200).
if ! [[ "$NUM_CAPTURAS" =~ ^[0-9]+$ ]] || [ "$NUM_CAPTURAS" -lt 3 ] || [ "$NUM_CAPTURAS" -gt 66 ]; then
    abortar "parametros" "num_capturas debe ser un entero entre 3 y 66 (recibido: '$NUM_CAPTURAS')"
fi
if ! [[ "$PAUSA" =~ ^[0-9]+$ ]]; then
    abortar "parametros" "la pausa debe ser un entero en segundos (recibido: '$PAUSA')"
fi

# 2. Auditoria de insumos estaticos:
# auditar.sh valida el .tar.gz, lo extrae y genera los 3 archivos de preparados/.
echo "[2/7] Verificacion del paquete, extraccion y auditoria de insumos"
if ! ./scripts/auditar.sh; then
    abortar "auditoria" "auditar.sh fallo (revisa el mensaje de arriba)"
fi

# 3. Captura de mediciones:
# Repito capturar.sh las veces pedidas, con una pausa para que cambie la hora.
echo "[3/7] Captura de mediciones ($NUM_CAPTURAS capturas, pausa de ${PAUSA}s)"
for ((i = 1; i <= NUM_CAPTURAS; i++)); do
    if ! ./scripts/capturar.sh; then
        abortar "captura" "capturar.sh fallo en la captura $i de $NUM_CAPTURAS"
    fi
    if [ "$i" -lt "$NUM_CAPTURAS" ]; then
        sleep "$PAUSA"
    fi
done

# 4. Normalizacion:
echo "[4/7] Normalizacion con etiqueta '$ETIQUETA'"
if ! ./scripts/normalizar.sh "$ETIQUETA"; then
    abortar "normalizacion" "normalizar.sh fallo"
fi
if [ ! -s "$ENTRADA" ]; then
    abortar "normalizacion" "no se creo $ENTRADA"
fi

# 5. Compilacion con banderas de rigor:
# Si gcc falla, abortar sale del script y el binario nunca se ejecuta
# (ademas, la limpieza ya borro cualquier binario viejo).
echo "[5/7] Compilacion de $FUENTE"
if [ ! -f "$FUENTE" ]; then
    abortar "compilacion" "no existe $FUENTE"
fi
if ! gcc -Wall -Wextra -Wpedantic -std=c11 -o "$BIN" "$FUENTE"; then
    abortar "compilacion" "gcc reporto errores; no se ejecuta el analizador"
fi

# 6. Analisis en C:
# Guardo el codigo de salida en RC porque $? cambia con cada comando.
echo "[6/7] Analisis con sec_engine"
"$BIN" "$ENTRADA" "$INFORME"
RC=$?
if [ $RC -ne 0 ]; then
    abortar "analisis" "sec_engine termino con codigo $RC"
fi

# 7. Verificar el informe y respaldar la corrida:
# El informe debe existir, no estar vacio y haberse modificado despues de INICIO
# (stat -c %Y da la fecha de modificacion en segundos).
echo "[7/7] Verificacion del informe y respaldo de la corrida"
if [ ! -s "$INFORME" ]; then
    abortar "verificacion" "no existe $INFORME o esta vacio"
fi
if [ "$(stat -c %Y "$INFORME")" -lt "$INICIO" ]; then
    abortar "verificacion" "el informe es anterior al inicio de esta ejecucion"
fi

# Guardo una copia de los datos usados y del resultado para poder reproducir el analisis.
SELLO=$(date +%Y%m%d_%H%M%S)
DESTINO="evidencias/corridas/$SELLO"
mkdir -p "$DESTINO" && cp "$RAW_LOG" "$ENTRADA" "$INFORME" "$DESTINO/" \
  || abortar "respaldo" "no se pudo guardar la corrida en $DESTINO"

echo ""
cat "$INFORME"
echo ""
echo "[ejecutar] Flujo completo OK. Corrida guardada en $DESTINO"
