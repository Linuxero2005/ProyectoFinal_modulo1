#!/bin/bash
# admin_proceso.sh - Practica de control de un proceso propio con senales.
# Solo toca un proceso que inicia el propio script (sleep), nunca procesos de otros.

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$RAIZ/evidencias/pruebas/admin_process.txt"
mkdir -p "$(dirname "$DOC")" || exit 1

# estado: anota en el documento la fecha, un titulo y la linea de ps del proceso.
estado() {
    echo "--- $(date '+%F %T') | $1" >> "$DOC"
    ps -o pid,ppid,user,stat,etime,cmd -p "$PID" >> "$DOC" 2>&1
}

# : > vacia el documento para empezar la practica desde cero.
: > "$DOC"
echo "PRACTICA: control de un proceso propio con senales" >> "$DOC"
echo "Usuario: $(id -un)" >> "$DOC"

# 1. Proceso auxiliar:
# sleep 300 solo espera, no consume CPU. El & lo manda a segundo plano
# y $! guarda su PID.
sleep 300 &
PID=$!
echo "PID del proceso auxiliar (sleep 300): $PID" >> "$DOC"
estado "1. Proceso iniciado en segundo plano (STAT S = durmiendo)"

# 2. Suspension: STOP congela el proceso sin terminarlo.
kill -STOP "$PID"
sleep 1
estado "2. Tras kill -STOP (STAT T = detenido)"

# 3. Reanudacion: CONT lo hace continuar donde se quedo.
kill -CONT "$PID"
sleep 1
estado "3. Tras kill -CONT (STAT S = reanudado)"

# 4. Terminacion controlada: TERM le pide que termine y le deja cerrar sus recursos.
# wait recoge su estado de salida para que no quede como proceso zombi.
kill -TERM "$PID"
wait "$PID" 2>/dev/null
echo "--- $(date '+%F %T') | 4. Tras kill -TERM" >> "$DOC"
if ps -p "$PID" > /dev/null 2>&1; then
    echo "El proceso $PID sigue activo" >> "$DOC"
else
    echo "El proceso $PID ya no existe (termino de forma controlada)" >> "$DOC"
fi

cat >> "$DOC" << 'EOF'

JUSTIFICACION DE LAS SENALES
- SIGSTOP (kill -STOP): suspende el proceso sin matarlo. No puede ser ignorada.
- SIGCONT (kill -CONT): reanuda un proceso detenido sin perder su estado.
- SIGTERM (kill -TERM): solicita una terminacion ordenada. Se prefiere sobre
  SIGKILL (-9) porque el proceso puede cerrar archivos y liberar recursos.
Solo se uso un proceso propio y de bajo impacto (sleep), sin afectar servicios
ni procesos de otros usuarios.
EOF
