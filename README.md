# sec_guard — Sistema de Monitoreo y Análisis de Recursos de Linux

Proyecto integrador del Módulo 1 (Linux y C). Autor: Cristopher Israel Vera Chávez

## 1. Descripción

`sec_guard` recopila tres mediciones del servidor (DISCO, PROCESOS y PERMISOS), las convierte a un formato común con utilerías de texto y Shell, y un programa en C las valida, calcula estadísticas por categoría y genera un informe. Además audita un paquete de archivos estáticos (`paquete_auditoria.tar.gz`).

Un único script, `scripts/ejecutar.sh`, coordina todo el proceso sin intervención del usuario y se detiene ante cualquier error. No requiere privilegios de administrador ni instala servicios.

Reparto de responsabilidades:

- Linux: Entorno de trabajo: permisos, enlaces, metadatos y procesos
- Utilerías (`df`, `ps`, `find`, `grep`, `sed`, `awk`, `tar`): Recopilar y transformar la información.
- Shell: Coordinar las etapas y comprobar el resultado de cada una
- Programa en C: Almacenar las mediciones, calcular estadísticas y generar el informe

## 2. Arquitectura y flujo

```
paquete_auditoria.tar.gz --> auditar.sh --> preparados/sshd_activo.txt
                                            preparados/usuarios_creados.txt
                                            preparados/conexiones_syn.txt

df / ps / find --> capturar.sh (N veces) --> capturas/telemetria_raw.log
                                             evidencias/capturas/  (salida de cada utilería)
                                                   │
                                                   |
                                             normalizar.sh --> preparados/mediciones_sec.txt
                                                                      │
                                                                      |
                         gcc --> fuentes/sec_engine (C) --> resultados/informe_seguridad.txt

```
`scripts/ejecutar.sh` ejecuta esta secuencia en siete pasos:

1. Limpieza de residuos de ejecuciones anteriores.
2. Verificación del paquete, extracción y auditoría (`auditar.sh`).
3. Captura de mediciones (`capturar.sh`, varias veces).
4. Normalización (`normalizar.sh`).
5. Compilación de `fuentes/sec_engine.c` con banderas de rigor.
6. Análisis con `sec_engine`.
7. Verificación del informe y respaldo de la corrida.

Si cualquier paso falla, el script informa la etapa y el motivo, borra cualquier informe y termina con código 1.

## 3. Estructura de directorios

```
sec_guard/
├── enlace_pruebas              enlace simbólico a evidencias/pruebas (Etapa 1)
├── capturas/
│   ├── estaticos/              paquete_auditoria.tar.gz y los archivos extraídos
│   └── telemetria_raw.log      registro original de las mediciones
├── preparados/                 archivos transformados para su procesamiento
├── fuentes/
│   ├── sec_engine.c            programa en C
│   └── sec_engine              binario (se genera al compilar)
├── scripts/                    auditar.sh, capturar.sh, normalizar.sh, ejecutar.sh, admin_proceso.sh
├── resultados/                 informe_seguridad.txt
├── evidencias/
│   ├── permissions.txt         permisos elegidos y su justificación
│   ├── link_record.txt         metadatos del archivo de prueba y de sus enlaces
│   ├── capturas/               salidas de df, ps y find de cada captura
│   ├── corridas/<fecha_hora>/  copia de datos e informe de cada ejecución
│   ├── pruebas/                archivo de prueba y enlace duro, proceso, entradas y salidas de pruebas
│   └── telemetria_raw_manual.log
└── README.md
```

Permisos: `scripts/` y `fuentes/` con 750; `capturas/`, `preparados/`, `resultados/` y `evidencias/` con 755. El detalle y la justificación están en `evidencias/permissions.txt`.

## 4. Descripción de archivos

- `scripts/auditar.sh`: Verifica la existencia e integridad del `.tar.gz`, lo extrae, y genera `sshd_activo.txt`, `usuarios_creados.txt` y `conexiones_syn.txt` en `preparados/`
- `scripts/capturar.sh`: Obtiene DISCO, PROCESOS y PERMISOS, las valida y las agrega a `capturas/telemetria_raw.log`; guarda la salida de cada utilería en `evidencias/capturas/`
- `scripts/normalizar.sh`: Convierte el log crudo en `preparados/mediciones_sec.txt` (etiqueta, total y un registro por línea) sin modificar el original ni eliminar repetidos
- `scripts/ejecutar.sh`: Orquestador: limpieza, auditoría, captura, normalización, compilación, análisis y verificación
- `scripts/admin_proceso.sh`: Práctica de control de un proceso propio (`kill -STOP`, `-CONT`, `-TERM`); escribe `evidencias/pruebas/admin_process.txt`
- `fuentes/sec_engine.c`: Lee y valida la entrada, calcula estadísticas por categoría y escribe el informe
- `capturas/telemetria_raw.log`: Mediciones originales: fecha, hora, categoría y valor
- `preparados/mediciones_sec.txt`: Entrada del programa en C
- `resultados/informe_seguridad.txt`: Informe final
- `evidencias/permissions.txt`: Permisos elegidos para directorios, datos y scripts
- `evidencias/link_record.txt`: Metadatos del archivo de prueba y de sus enlaces
- `evidencias/pruebas/admin_process.txt`: Evidencia de suspensión, reanudación y terminación de un proceso propio

## 5. Requisitos

- Linux con `bash`, GNU coreutils y herramientas estándar: `sed`, `grep`, `awk`, `tar`, `gzip`, `find`, `ps`, `df`, `stat`.
- `gcc` (compilador de C).
- No se necesita `sudo`.
- Permisos necesarios: escritura en el directorio `sec_guard/` y permiso de ejecución en los scripts (`chmod 750 scripts/*.sh`).
- Algunas opciones son de GNU (`sed` con la bandera `I`, `stat -c`, `ps --no-headers`), por lo que el proyecto no está pensado para macOS.

## 6. Instrucciones paso a paso

### 6.1 Preparación

```bash
cd sec_guard
# El paquete debe estar en capturas/estaticos/
ls capturas/estaticos/paquete_auditoria.tar.gz
chmod 750 scripts/*.sh
```

### 6.2 Ejecución completa

```bash
./scripts/ejecutar.sh [etiqueta] [num_capturas] [pausa_segundos]
```

- `etiqueta` (por defecto: `AuditoriaCursoC`): Una palabra, hasta 31 caracteres
- `num_capturas` (por defecto: 3): Entero de 3 a 66 (66 capturas × 3 categorías = 198 registros; el máximo es 200)
- `pausa_segundos` (por defecto: 2): Entero en segundos

Ejemplos:

```bash
./scripts/ejecutar.sh                     # valores por defecto
./scripts/ejecutar.sh PruebaCuatro 4 1    # etiqueta, 4 capturas, pausa de 1 s
```

El informe queda en `resultados/informe_seguridad.txt` y una copia de los datos y del informe en `evidencias/corridas/<fecha_hora>/`.

### 6.3 Ejecución por partes

```bash
./scripts/auditar.sh
./scripts/capturar.sh                      # repetir al menos 3 veces
./scripts/normalizar.sh [etiqueta]
gcc -Wall -Wextra -Wpedantic -std=c11 -o fuentes/sec_engine fuentes/sec_engine.c
./fuentes/sec_engine preparados/mediciones_sec.txt resultados/informe_seguridad.txt
```

### 6.4 Códigos de salida

Todos los scripts y el programa en C devuelven `0` si todo salió bien y `1` si hubo cualquier error; los mensajes de error se escriben en la salida de error estándar.

### 6.5 Qué borra la limpieza inicial

`ejecutar.sh` borra únicamente lo que él mismo genera: el informe, el binario, `mediciones_sec.txt`, `telemetria_raw.log`, los tres archivos de `preparados/` y los tres archivos extraídos en `capturas/estaticos/`. No borra `paquete_auditoria.tar.gz`, las evidencias ni las corridas anteriores. Como consecuencia, si el flujo falla a medias, nunca queda un informe ni un binario de una ejecución anterior.

## 7. Formatos y reglas

**Registro original** (`capturas/telemetria_raw.log`), una línea por observación:

```
2026-11-12 18:04:24 DISCO 36
```

**Entrada del programa en C** (`preparados/mediciones_sec.txt`): etiqueta (sin espacios, hasta 31 caracteres), cantidad total de registros (0 a 200) y un registro `CATEGORIA valor` por línea. La cantidad debe coincidir con el número de registros.

- DISCO
  - Qué mide: % de ocupación del sistema de archivos del directorio personal
  - Intervalo: 0 a 100
  - Condición de alerta: valor ≥ 80
- PROCESOS
  - Qué mide: Procesos de la cuenta del usuario
  - Intervalo: 0 a 2000
  - Condición de alerta: valor ≥ 30
- PERMISOS
  - Qué mide: Archivos regulares del proyecto con escritura para grupo u otros
  - Intervalo: 0 a 200
  - Condición de alerta: valor > 0

Las alertas son reglas didácticas: indican que se cumplió una condición del ejercicio, no demuestran por sí solas una falla o un incidente de seguridad.

## 8. Decisiones de diseño y limitaciones

- **Captura fallida:** nunca se sustituye por cero. Si una utilería falla o el valor no es un entero dentro de su intervalo, `capturar.sh` informa el error, termina con código 1 y no escribe nada en el log.
- **Valores repetidos:** no se usa `sort -u` ni `uniq`. Dos observaciones distintas pueden tener el mismo valor y eliminarlas alteraría cantidades, sumas y promedios.
- **Log original intacto:** `normalizar.sh` solo lee `telemetria_raw.log`.
- **Promedios por categoría:** cada promedio usa la cantidad de observaciones de su categoría. No se calcula una suma ni un promedio global que mezcle porcentajes, procesos y archivos.
- **Informe solo si la entrada es válida:** el programa en C valida todo antes de escribir y no crea el informe si detecta un error.
- **Informe nuevo:** la limpieza lo borra al inicio y, al final, se comprueba que exista y que su fecha de modificación sea posterior al inicio de la ejecución.
- **Limitaciones conocidas:**
  - DISCO mide el sistema de archivos completo, no el espacio usado solo por el participante.
  - PROCESOS incluye los procesos del propio script (`bash`, `ps`, etc.), por eso puede dar un valor mayor al ejecutarse desde `ejecutar.sh`.
  - PERMISOS revisa solo el directorio del proyecto, incluidas las evidencias.
  - Las condiciones de alerta son umbrales didácticos.

### Decisiones de diseño detalladas

**Criterios de asignación de permisos**

- Principio de menor privilegio: nadie fuera del propietario necesita modificar el proyecto.
- Directorios con código (`scripts/`, `fuentes/`): 750. El propietario escribe y entra, el grupo solo entra y lee, y otros no tienen acceso. Los directorios necesitan `x` para poder entrar.
- Directorios de datos y documentación (`capturas/`, `preparados/`, `resultados/`, `evidencias/`): 755. Otros pueden entrar y leer, pero no crear ni borrar archivos.
- Archivos de datos: sin ejecución y sin escritura para grupo ni otros (por ejemplo 644). Scripts: 750.
- La categoría PERMISOS verifica este criterio en cada captura: cuenta los archivos regulares del proyecto con escritura para grupo u otros, y debe dar 0. El detalle está en `evidencias/permissions.txt`.

**Estructuras de datos en C**

- `Medicion` (`categoria`, `valor`): una observación individual; la categoría se guarda como índice de un `enum` (DISCO, PROCESOS, PERMISOS).
- `ResumenCategoria` (`cantidad`, `suma`, `minimo`, `maximo`, `promedio`, `alertas`): el resumen de una categoría. Hay un arreglo fijo de tres.
- `Datos` (`etiqueta`, `total`, `mediciones`): todo lo leído del archivo de entrada.
- Los arreglos constantes `NOMBRES`, `MAXIMOS` y `UMBRAL`, indexados por el mismo `enum`, asocian cada categoría con su nombre, su intervalo y su umbral de alerta. Agregar una categoría implica agregar una entrada en cada uno, sin duplicar código.
- Separar medición y resumen evita mezclar categorías: cada promedio usa la cantidad de su propia categoría.

**Gestión de memoria dinámica**

- Las mediciones se guardan en un arreglo reservado con `malloc` del tamaño exacto indicado en el encabezado (`total * sizeof(Medicion)`), una vez validado que `total` está entre 0 y 200.
- Si `total` es 0 no se reserva memoria y el arreglo queda en `NULL`; el informe sale con «Sin datos».
- Se comprueba que `malloc` no devuelva `NULL` antes de usar el arreglo.
- Todas las rutas de error de `leer_entrada` pasan por un único punto de limpieza (`fallo`) que cierra el archivo y libera la memoria. En `main`, `free` se ejecuta al terminar; `free(NULL)` es seguro.
- Los buffers de texto tienen tamaño fijo y `fscanf` limita el ancho (`%63s`), lo que previene desbordamientos.

**Delimitadores en `sed` y `awk` y diseño de expresiones regulares**

- `sshd_config`: `sed -E` con delimitador `/` para el puerto y `|` para `HostKey`, porque su patrón contiene la `/` de la ruta y así no hay que escaparla. Orden: primero habilitar (`#Port` pasa a `Port 8080` y se quita el `#` de `HostKey`) y al final borrar comentarios (`/^[[:space:]]*#/d`) y líneas vacías (`/^[[:space:]]*$/d`). El patrón del puerto exige dígitos y el de `HostKey` exige una ruta que empiece con `/`, para no habilitar comentarios descriptivos.
- `secure.log`: `grep "new user"` y `sed -E 's/.*name=([^,]+).*UID=([^,]+).*GID=([^,]+).*/.../'`. La coma es el delimitador de cada valor, así que `[^,]+` captura hasta la coma y los tres grupos se reordenan en columnas.
- `net_traffic.log`: `grep 'Flags \[S\]'` selecciona los SYN (los corchetes se escapan porque son especiales; un SYN-ACK aparece como `[S.]` y no coincide). `awk '{print $2, $4}'` usa el separador de campos por defecto (espacios) para tomar origen y destino, y `sed -E 's/^(.+)\.([0-9]+) (.+)\.([0-9]+):$/.../'` separa IP y puerto: `.+` es voraz y retrocede hasta el último punto, por lo que los cuatro octetos quedan completos.
- `df`: `awk 'NR==2 {gsub("%","",$5); print $5}'` toma la fila de datos y la columna del porcentaje.
- `normalizar.sh`: `awk` conserva solo líneas con 4 campos, categoría válida (`$3 ~ /^(DISCO|PROCESOS|PERMISOS)$/`) y valor entero (`$4 ~ /^[0-9]+$/`).

## 9. Control de un proceso propio

`scripts/admin_proceso.sh` inicia `sleep 300` en segundo plano (no consume CPU), obtiene su PID con `$!` y registra en `evidencias/pruebas/admin_process.txt` el estado (`ps`) en cuatro momentos: iniciado (`S`), tras `kill -STOP` (`T`, detenido), tras `kill -CONT` (`S`, reanudado) y tras `kill -TERM` (el proceso ya no existe). Solo se toca un proceso propio y de bajo impacto.

## 10. Pruebas

Los datos de prueba son archivos independientes de las capturas reales. Las salidas reales de cada prueba están en `evidencias/pruebas/` y se reproducen completas en la sección 13 (registro de pruebas).

- Prueba 1: Paquete `.tar.gz` corrupto
  - Qué demuestra: El orquestador valida la integridad antes de procesar
  - Resultado esperado: `auditar.sh` informa que el paquete está dañado; `ejecutar.sh` aborta en la etapa `auditoria`, sale con 1 y no hay informe
  - Evidencia: `prueba1_tar_corrupto.txt`
- Prueba 2: Cantidad declarada incorrecta (15 o 3 con 9 registros)
  - Qué demuestra: El analizador no asume entradas ciegas y detecta archivos incompletos o manipulados
  - Resultado esperado: Error "se declararon 15 registros pero solo hay 9" y "hay más registros que los 3 declarados"; sale con 1 y no se crea informe
  - Evidencia: `prueba2_declara15.txt`, `prueba2_declara3.txt`
- Prueba 3: Categoría vacía y cero registros
  - Qué demuestra: Resiliencia aritmética
  - Resultado esperado: Sale con 0; muestra "Sin datos" en la categoría vacía o en las tres; sin divisiones entre cero
  - Evidencia: `prueba3_sin_permisos.txt`, `prueba3_cero_registros.txt`
- Prueba 4: Fallo de permisos en la captura (`chmod 000`)
  - Qué demuestra: El orquestador no entrega un informe viejo ante un error intermedio
  - Resultado esperado: `ejecutar.sh` aborta en la etapa `captura` y `informe_seguridad.txt` no existe
  - Evidencia: `prueba4_sin_permiso_captura.txt`
- Prueba 5: Error de sintaxis en el código C
  - Qué demuestra: El orquestador detecta errores del compilador y no ejecuta un binario previo
  - Resultado esperado: `gcc` falla, `ejecutar.sh` aborta en `compilacion` y no existe `fuentes/sec_engine`
  - Evidencia: `prueba5_error_compilacion.txt`

Pruebas adicionales del analizador:

- Ejemplo de 9 registros
  - Resultado esperado: Informe con los valores de referencia (DISCO suma 222 y promedio 74.00, PROCESOS 29 y 9.67, PERMISOS 1 y 0.33; 2 alertas)
  - Evidencia: `ejemplo_9.txt`, `informe_ejemplo.txt`
- Valores en los límites (0, 79, 80, 100, 2000, 200)
  - Resultado esperado: Se aceptan; alertas en los umbrales (80, 30 y 1)
  - Evidencia: `prueba_limites.txt`
- Datos incorrectos (101, 2001, 201, negativo, categoría desconocida)
  - Resultado esperado: Mensaje específico, salida 1 y sin informe
  - Evidencia: `prueba_datos_incorrectos.txt`
- Archivo de entrada inexistente
  - Resultado esperado: Error de apertura y salida 1
  - Evidencia: `prueba_archivo_inexistente.txt`
- Nueva captura real
  - Resultado esperado: `ejecutar.sh` con parámetros distintos genera un informe actualizado y una nueva carpeta en `evidencias/corridas/`
  - Evidencia: `evidencias/corridas/`

## 11. Respuestas a las preguntas de cada etapa

### Etapa 1. Organización del entorno y revisión de archivos

**1. ¿Por qué los permisos adecuados para un directorio pueden ser distintos de los necesarios para un archivo de datos?**
Porque los bits significan cosas distintas. En un directorio, `r` permite listar los nombres, `w` permite crear, borrar o renombrar entradas y `x` permite entrar (`cd`) y acceder por nombre a lo que contiene. En un archivo de datos solo se necesita `r` y `w`. Por eso los directorios llevan `x` (750 o 755), los datos no la necesitan (644) y los scripts sí (750). Quitar `w` a otros en un directorio impide que creen o borren archivos aunque el archivo tenga permisos amplios.

**2. ¿Qué diferencia existe entre el archivo original y su enlace duro?**
Ninguna real: son dos nombres para el mismo inodo (mismos datos, permisos, propietario y marcas de tiempo, y el mismo número de inodo). El contador de enlaces sube a 2. Si se renombra o se borra uno, el otro sigue funcionando, y los datos se eliminan solo cuando el contador llega a 0. En la prueba, tras renombrar `prueba_doc.txt` a `doc_original.txt`, `hardlink.txt` conservó el mismo inodo.

**3. ¿Cuál es la utilidad de establecer enlaces simbólicos en el desarrollo de un sistema?**
Un enlace simbólico guarda una ruta, así que da un nombre estable a algo que cambia de lugar o de versión (por ejemplo `actual -> v2`), permite atajos a directorios, puede apuntar a otro sistema de archivos y evita duplicar datos. Su desventaja es que queda roto si el destino se mueve o se borra.

**4. ¿Qué información de los metadatos permite reconocer cambios en un archivo?**
`stat` muestra el tiempo de modificación (cambió el contenido), el tiempo de cambio del inodo (cambiaron permisos, propietario, nombre o enlaces), el tiempo de acceso, el tamaño, los permisos, el propietario, el número de inodo y el contador de enlaces. Si el archivo se modifica cambian el tamaño y el tiempo de modificación; si solo se cambian sus permisos cambia el tiempo de cambio del inodo; si se reemplaza por otro archivo cambia el número de inodo.

### Etapa 2. Captura, desempaquetado y preparación

**1. ¿Qué transformación necesita la salida de cada utilería para convertirse en un registro del archivo normalizado?**
Cada salida trae texto adicional y hay que reducirla a un entero. De `df -P` se toma la fila 2, columna 5 y se quita el `%`. De `ps -u "$USER" --no-headers` y de `find` se cuentan las líneas con `wc -l`. En el log crudo se antepone fecha, hora y categoría; al normalizar, `awk` conserva solo las líneas bien formadas y deja `CATEGORIA valor`.

**2. ¿Por qué un valor cero puede ser válido y no debe confundirse con una captura fallida?**
`PERMISOS 0` significa que se midió y no hay archivos con escritura para grupo u otros, un resultado válido y bueno. Una captura fallida significa que no hay medición. Si se escribiera 0, el informe diría que todo está bien sin haber medido nada. Por eso `capturar.sh` revisa el código de salida (`$?`) de cada utilería y que el valor sea un entero dentro de su intervalo; si falla, avisa por la salida de error y no escribe el registro.

**3. ¿Cómo comprobarán que la cantidad del encabezado corresponde a los registros conservados?**
Con `tail -n +3 preparados/mediciones_sec.txt | wc -l`, que debe coincidir con `sed -n 2p preparados/mediciones_sec.txt`. Además, `normalizar.sh` calcula el total a partir de las mismas líneas que escribe, y `sec_engine` vuelve a validarlo y rechaza archivos con registros de más o de menos.

**4. ¿Por qué el orden de las instrucciones dentro del flujo de `sed` es estrictamente determinante al habilitar directivas y eliminar comentarios?**
`sed` aplica los comandos en orden a cada línea. Primero se habilitan las directivas (se quita el `#` de `Port` y de `HostKey` y se fija el puerto 8080) y al final se borran comentarios y líneas vacías. Si los comentarios se borraran primero, `#Port 22` y `#HostKey ...` desaparecerían antes de poder habilitarlos y el archivo quedaría sin esas directivas.

**5. ¿Qué estrategia se empleó para aislar el puerto sin limitar obtener correctamente los cuatro octetos de la IP?**
El puerto es el número que sigue al último punto del campo. Con `awk` se separan primero los campos de origen y destino, y con `sed` se usa `(.+)\.([0-9]+)`: como `.+` es voraz, consume todo y retrocede solo hasta el último punto, de modo que los cuatro octetos quedan completos en el primer grupo y los dígitos finales en el segundo. Un corte simple por puntos partiría la IP. La misma expresión funciona con destinos IPv6 como `fd00::2.80`.

### Etapa 3. Programa de análisis en C

**1. ¿Qué diferencia existe entre almacenar una medición y almacenar el resumen de una categoría?**
Una medición (`Medicion`) es una observación individual y hay una por cada línea del archivo, por eso se guardan en un arreglo dinámico del tamaño indicado en el encabezado. El resumen (`ResumenCategoria`) condensa todas las observaciones de una categoría (cantidad, suma, mínimo, máximo, promedio y alertas) y su tamaño es fijo: tres estructuras, sin importar cuántos registros haya.

**2. ¿Cómo evitarán una división entre cero o utilizar un mínimo que todavía no se ha inicializado?**
El promedio solo se calcula si la cantidad de la categoría es mayor que cero; si es cero, el informe muestra "Sin datos". El mínimo y el máximo no se inicializan con valores arbitrarios: se asignan con la primera medición de la categoría (`if (cantidad == 0)`), así nunca se compara contra un valor inventado.

**3. Si ocurre un error después de reservar memoria y abrir un archivo, ¿qué recursos deben liberar o cerrar?**
Hay que cerrar el archivo (`fclose`) y liberar la memoria (`free`). En `leer_entrada` esto se hace en un solo punto de salida (la etiqueta `fallo`) para que ninguna ruta de error se escape. Si falla la escritura del informe, también se cierra ese archivo, y en `main` se libera el arreglo antes de terminar.

### Etapa 4. Integración, control de procesos y pruebas

**1. ¿Cómo decide el script si puede continuar después de ejecutar el programa C?**
Guarda el código de salida en una variable (`RC=$?`) justo después de ejecutarlo. El programa devuelve 0 si todo salió bien y 1 si detectó cualquier error, y `if [ $RC -ne 0 ]` aborta el flujo. Después comprueba que el informe exista, no esté vacío y sea posterior al inicio de la ejecución.

**2. ¿Cómo se distinguirá un informe nuevo de uno conservado de una ejecución anterior?**
La limpieza borra el informe antes de empezar, así que si existe fue creado por esta ejecución. Además, el script compara su fecha de modificación (`stat -c %Y`) con la hora de inicio, y cada corrida se respalda en una carpeta con fecha y hora en `evidencias/corridas/`.

**3. ¿Qué evidencia demuestra que el informe se obtuvo mediante el flujo completo y no se elaboró manualmente?**
La salida de los siete pasos en pantalla, las salidas de `df`, `ps` y `find` guardadas en `evidencias/capturas/` con marcas de tiempo que coinciden con `telemetria_raw.log`, la copia de la corrida en `evidencias/corridas/<fecha_hora>/`, el orden coherente de las fechas de los archivos (log crudo, entrada normalizada, binario e informe) y el historial de commits en Git.

## 12. Control de versiones

Repositorio: `proyectoFinal_Modulo1`, con commits progresivos por etapa. El archivo `.gitignore` omite el binario `fuentes/sec_engine` y los archivos temporales (`*.tmp`).

## 13. Registro de pruebas

Evidencia de los casos de validación ejecutados, clasificados así:

- Datos nominales: Ejemplo de 9 registros; corrida completa de `ejecutar.sh` con valores por defecto
- Valores frontera: Límites de intervalo y umbrales (0, 79, 80, 100, 2000, 200); categoría vacía; cero registros
- Error inducido: Paquete corrupto (prueba 1); cantidad declarada incorrecta (prueba 2); fallo de permisos en la captura (prueba 4); error de compilación (prueba 5); datos fuera de rango o desconocidos; archivo inexistente

Cada bloque siguiente es la salida real capturada con `tee`, e incluye el código de salida (`salida: N`).

### Salidas registradas

#### prueba_corrida_nominal
```
[1/7] Limpieza de residuos de ejecuciones anteriores
[2/7] Verificacion del paquete, extraccion y auditoria de insumos
[3/7] Captura de mediciones (3 capturas, pausa de 2s)
[4/7] Normalizacion con etiqueta 'AuditoriaCursoC'
[5/7] Compilacion de fuentes/sec_engine.c
[6/7] Analisis con sec_engine
[7/7] Verificacion del informe y respaldo de la corrida

INFORME DE MONITOREO
Etiqueta: AuditoriaCursoC
Registros: 9

Categoria DISCO
  Cantidad: 3
  Suma: 108
  Minimo: 36
  Maximo: 36
  Promedio: 36.00
  Alertas: 0

Categoria PROCESOS
  Cantidad: 3
  Suma: 30
  Minimo: 10
  Maximo: 10
  Promedio: 10.00
  Alertas: 0

Categoria PERMISOS
  Cantidad: 3
  Suma: 0
  Minimo: 0
  Maximo: 0
  Promedio: 0.00
  Alertas: 0

Observaciones que cumplen condiciones de alerta: 0
Umbrales utilizados con fines didacticos.

[ejecutar] Flujo completo OK. Corrida guardada en evidencias/corridas/20261113_061307
```

#### informe_ejemplo
```
INFORME DE MONITOREO
Etiqueta: AuditoriaCursoC
Registros: 9

Categoria DISCO
  Cantidad: 3
  Suma: 222
  Minimo: 62
  Maximo: 82
  Promedio: 74.00
  Alertas: 1

Categoria PROCESOS
  Cantidad: 3
  Suma: 29
  Minimo: 8
  Maximo: 11
  Promedio: 9.67
  Alertas: 0

Categoria PERMISOS
  Cantidad: 3
  Suma: 1
  Minimo: 0
  Maximo: 1
  Promedio: 0.33
  Alertas: 1

Observaciones que cumplen condiciones de alerta: 2
Umbrales utilizados con fines didacticos.
```

#### prueba_limites
```
salida: 0
INFORME DE MONITOREO
Etiqueta: AuditoriaCursoC
Registros: 11

Categoria DISCO
  Cantidad: 4
  Suma: 259
  Minimo: 0
  Maximo: 100
  Promedio: 64.75
  Alertas: 2

Categoria PROCESOS
  Cantidad: 4
  Suma: 2059
  Minimo: 0
  Maximo: 2000
  Promedio: 514.75
  Alertas: 2

Categoria PERMISOS
  Cantidad: 3
  Suma: 201
  Minimo: 0
  Maximo: 200
  Promedio: 67.00
  Alertas: 2

Observaciones que cumplen condiciones de alerta: 6
Umbrales utilizados con fines didacticos.
```

#### prueba3_sin_permisos
```
salida: 0
INFORME DE MONITOREO
Etiqueta: AuditoriaCursoC
Registros: 4

Categoria DISCO
  Cantidad: 2
  Suma: 110
  Minimo: 50
  Maximo: 60
  Promedio: 55.00
  Alertas: 0

Categoria PROCESOS
  Cantidad: 2
  Suma: 12
  Minimo: 5
  Maximo: 7
  Promedio: 6.00
  Alertas: 0

Categoria PERMISOS
  Sin datos

Observaciones que cumplen condiciones de alerta: 0
Umbrales utilizados con fines didacticos.
```

#### prueba3_cero_registros
```
salida: 0
INFORME DE MONITOREO
Etiqueta: AuditoriaCursoC
Registros: 0

Categoria DISCO
  Sin datos

Categoria PROCESOS
  Sin datos

Categoria PERMISOS
  Sin datos

Observaciones que cumplen condiciones de alerta: 0
Umbrales utilizados con fines didacticos.
```

#### prueba1_tar_corrupto
```
[1/7] Limpieza de residuos de ejecuciones anteriores
[2/7] Verificacion del paquete, extraccion y auditoria de insumos
ERROR: /home/becario19/sec_guard/capturas/estaticos/paquete_auditoria.tar.gz esta danado o no es un tar.gz valido

[ejecutar] ERROR en la etapa 'auditoria': auditar.sh fallo (revisa el mensaje de arriba)
[ejecutar] Flujo detenido; no hay informe de esta ejecucion.
salida: 1
```

#### prueba2_declara15
```
ERROR: se declararon 15 registros pero solo hay 9
salida: 1
```

#### prueba2_declara3
```
ERROR: hay mas registros que los 3 declarados
salida: 1
```

#### prueba4_sin_permiso_captura
```
[1/7] Limpieza de residuos de ejecuciones anteriores
[2/7] Verificacion del paquete, extraccion y auditoria de insumos
[3/7] Captura de mediciones (3 capturas, pausa de 2s)
./scripts/ejecutar.sh: line 60: ./scripts/capturar.sh: Permission denied

[ejecutar] ERROR en la etapa 'captura': capturar.sh fallo en la captura 1 de 3
[ejecutar] Flujo detenido; no hay informe de esta ejecucion.
salida: 1
```

#### prueba5_error_compilacion
```
[1/7] Limpieza de residuos de ejecuciones anteriores
[2/7] Verificacion del paquete, extraccion y auditoria de insumos
[3/7] Captura de mediciones (3 capturas, pausa de 2s)
[4/7] Normalizacion con etiqueta 'AuditoriaCursoC'
[5/7] Compilacion de fuentes/sec_engine.c
fuentes/sec_engine.c: In function ‘main’:
fuentes/sec_engine.c:234:5: error: ‘palabra_invalida’ undeclared (first use in this function)
  234 |     palabra_invalida;
      |     ^~~~~~~~~~~~~~~~
fuentes/sec_engine.c:234:5: note: each undeclared identifier is reported only once for each function it appears in

[ejecutar] ERROR en la etapa 'compilacion': gcc reporto errores; no se ejecuta el analizador
[ejecutar] Flujo detenido; no hay informe de esta ejecucion.
salida: 1
```

#### prueba_datos_incorrectos
```
== DISCO 101
ERROR: DISCO=101 fuera de rango (0-100) en el registro 1
salida: 1
== PROCESOS 2001
ERROR: PROCESOS=2001 fuera de rango (0-2000) en el registro 1
salida: 1
== PERMISOS 201
ERROR: PERMISOS=201 fuera de rango (0-200) en el registro 1
salida: 1
== DISCO -1
ERROR: DISCO=-1 fuera de rango (0-100) en el registro 1
salida: 1
== HOLA 5
ERROR: categoria desconocida 'HOLA' en el registro 1
salida: 1
```

#### prueba_archivo_inexistente
```
ERROR: no se pudo abrir el archivo 'no_existe.txt'
salida: 1
```
