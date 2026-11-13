#!/bin/bash
# auditar.sh - Verifica y extrae paquete_auditoria.tar.gz y genera los 3 archivos de preparados/.

# 0. Preparacion:
# Saco la raiz del proyecto a partir de la ruta del script, igual que en capturar.sh.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ESTATICOS="$RAIZ/capturas/estaticos"
PAQUETE="$ESTATICOS/paquete_auditoria.tar.gz"
PREP="$RAIZ/preparados"
mkdir -p "$ESTATICOS" "$PREP" || exit 1

# 1. Validar el paquete antes de extraer:
# -f revisa que exista; gzip -t prueba la integridad sin extraer;
# tar -tzf lista el contenido y falla si el tar esta danado.
if [ ! -f "$PAQUETE" ]; then
    echo "ERROR: no existe $PAQUETE" >&2
    exit 1
fi
if ! gzip -t "$PAQUETE" 2>/dev/null || ! tar -tzf "$PAQUETE" > /dev/null 2>&1; then
    echo "ERROR: $PAQUETE esta danado o no es un tar.gz valido" >&2
    exit 1
fi

# 2. Extraer y comprobar que estan los 3 archivos (-C indica la carpeta destino).
if ! tar -xzf "$PAQUETE" -C "$ESTATICOS"; then
    echo "ERROR: fallo la extraccion de $PAQUETE" >&2
    exit 1
fi
for ARCH in secure.log net_traffic.log sshd_config; do
    if [ ! -s "$ESTATICOS/$ARCH" ]; then
        echo "ERROR: falta $ARCH despues de extraer" >&2
        exit 1
    fi
done

# 3. sshd_activo.txt:
# El ORDEN importa: primero habilito (quito el # de Port y HostKey y pongo el 8080)
# y hasta el final borro comentarios y lineas vacias. Si borrara los comentarios
# primero, "#Port 22" y "#HostKey ..." desaparecerian antes de poder habilitarlos.
sed -E '
s/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+.*/Port 8080/I
s|^[[:space:]]*#[[:space:]]*(HostKey[[:space:]]+/)|\1|I
/^[[:space:]]*#/d
/^[[:space:]]*$/d
' "$ESTATICOS/sshd_config" > "$PREP/sshd_activo.txt"

# 4. usuarios_creados.txt:
# grep deja solo las lineas de usuarios nuevos y sed saca nombre, UID y GID.
grep "new user" "$ESTATICOS/secure.log" \
  | sed -E 's/.*name=([^,]+).*UID=([^,]+).*GID=([^,]+).*/Usuario: \1 | UID: \2 | GID: \3/' \
  > "$PREP/usuarios_creados.txt"

# 5. conexiones_syn.txt:
# grep deja solo los SYN (Flags [S]). awk separa por espacios y toma el campo 2 (origen)
# y el 4 (destino). sed parte cada uno en IP y puerto: como .+ es voraz, retrocede hasta
# el ULTIMO punto, asi los 4 octetos de la IP quedan completos y el puerto es lo que sigue.
grep 'Flags \[S\]' "$ESTATICOS/net_traffic.log" \
  | awk '{print $2, $4}' \
  | sed -E 's/^(.+)\.([0-9]+) (.+)\.([0-9]+):$/Origen_IP: \1 | Puerto_Orig: \2 | Destino_IP: \3 | Puerto_Dest: \4/' \
  > "$PREP/conexiones_syn.txt"

# 6. Validacion: ningun archivo debe quedar vacio.
for ARCH in sshd_activo.txt usuarios_creados.txt conexiones_syn.txt; do
    if [ ! -s "$PREP/$ARCH" ]; then
        echo "ERROR: $ARCH quedo vacio" >&2
        exit 1
    fi
done
