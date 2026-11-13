/* sec_engine.c - Lee mediciones_sec.txt, calcula estadisticas por categoria
 * y genera el informe de seguridad.
 * Uso: ./fuentes/sec_engine entrada.txt salida.txt */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_REGISTROS 200
#define MAX_ETIQUETA  31
#define NUM_CAT       3

/* Indices de categoria: el orden coincide con los arreglos de abajo */
enum { DISCO = 0, PROCESOS = 1, PERMISOS = 2 };

static const char *NOMBRES[NUM_CAT] = {"DISCO", "PROCESOS", "PERMISOS"};
static const int   MAXIMOS[NUM_CAT] = {100, 2000, 200};   /* intervalo 0..MAXIMO */
static const int   UMBRAL[NUM_CAT]  = {80, 30, 1};        /* alerta si valor >= UMBRAL */

/* Una medicion leida del archivo */
typedef struct {
    int categoria;   /* DISCO, PROCESOS o PERMISOS */
    int valor;
} Medicion;

/* Resumen de una categoria */
typedef struct {
    int    cantidad;
    long   suma;
    int    minimo;
    int    maximo;
    double promedio;
    int    alertas;
} ResumenCategoria;

/* Todo lo leido del archivo de entrada */
typedef struct {
    char      etiqueta[MAX_ETIQUETA + 1];
    int       total;
    Medicion *mediciones;   /* NULL si total == 0 */
} Datos;

/* Devuelve el indice de la categoria o -1 si no existe */
static int indice_categoria(const char *texto) {
    for (int i = 0; i < NUM_CAT; i++)
        if (strcmp(texto, NOMBRES[i]) == 0)
            return i;
    return -1;
}

/* Convierte texto a entero; devuelve 0 si es valido y -1 si no lo es */
static int a_entero(const char *texto, long *resultado) {
    char *fin;
    *resultado = strtol(texto, &fin, 10);
    if (texto[0] == '\0' || *fin != '\0')
        return -1;
    return 0;
}

/* Lee y valida el archivo. Devuelve 0 si todo esta bien, -1 si hubo error. */
static int leer_entrada(const char *ruta, Datos *d) {
    FILE *f;
    char  etiqueta[64], tok1[64], tok2[64];
    long  total, valor;
    int   i, cat;

    d->total = 0;
    d->mediciones = NULL;

    f = fopen(ruta, "r");
    if (f == NULL) {
        fprintf(stderr, "ERROR: no se pudo abrir el archivo '%s'\n", ruta);
        return -1;
    }

    /* Linea 1: etiqueta */
    if (fscanf(f, "%63s", etiqueta) != 1) {
        fprintf(stderr, "ERROR: el archivo esta vacio o no tiene etiqueta\n");
        goto fallo;
    }
    if (strlen(etiqueta) > MAX_ETIQUETA) {
        fprintf(stderr, "ERROR: la etiqueta excede %d caracteres\n", MAX_ETIQUETA);
        goto fallo;
    }
    strcpy(d->etiqueta, etiqueta);

    /* Linea 2: cantidad de registros */
    if (fscanf(f, "%63s", tok1) != 1 || a_entero(tok1, &total) != 0) {
        fprintf(stderr, "ERROR: la cantidad de registros falta o no es un entero\n");
        goto fallo;
    }
    if (total < 0 || total > MAX_REGISTROS) {
        fprintf(stderr, "ERROR: la cantidad declarada (%ld) debe estar entre 0 y %d\n",
                total, MAX_REGISTROS);
        goto fallo;
    }
    d->total = (int)total;

    /* Memoria dinamica solo si hay registros */
    if (d->total > 0) {
        d->mediciones = malloc((size_t)d->total * sizeof(Medicion));
        if (d->mediciones == NULL) {
            fprintf(stderr, "ERROR: no se pudo reservar memoria\n");
            goto fallo;
        }
    }

    /* Registros: CATEGORIA valor */
    for (i = 0; i < d->total; i++) {
        if (fscanf(f, "%63s %63s", tok1, tok2) != 2) {
            fprintf(stderr, "ERROR: se declararon %d registros pero solo hay %d\n",
                    d->total, i);
            goto fallo;
        }
        cat = indice_categoria(tok1);
        if (cat < 0) {
            fprintf(stderr, "ERROR: categoria desconocida '%s' en el registro %d\n",
                    tok1, i + 1);
            goto fallo;
        }
        if (a_entero(tok2, &valor) != 0) {
            fprintf(stderr, "ERROR: valor no entero '%s' en el registro %d\n",
                    tok2, i + 1);
            goto fallo;
        }
        if (valor < 0 || valor > MAXIMOS[cat]) {
            fprintf(stderr, "ERROR: %s=%ld fuera de rango (0-%d) en el registro %d\n",
                    NOMBRES[cat], valor, MAXIMOS[cat], i + 1);
            goto fallo;
        }
        d->mediciones[i].categoria = cat;
        d->mediciones[i].valor = (int)valor;
    }

    /* Si queda algo mas, hay registros adicionales a los declarados */
    if (fscanf(f, "%63s", tok1) == 1) {
        fprintf(stderr, "ERROR: hay mas registros que los %d declarados\n", d->total);
        goto fallo;
    }

    fclose(f);
    return 0;

fallo:
    /* Un solo punto de limpieza: cierra el archivo y libera la memoria */
    fclose(f);
    free(d->mediciones);
    d->mediciones = NULL;
    d->total = 0;
    return -1;
}

/* Calcula el resumen de cada categoria por separado */
static void procesar(const Datos *d, ResumenCategoria r[NUM_CAT]) {
    int i, c, v;

    for (c = 0; c < NUM_CAT; c++) {
        r[c].cantidad = 0;
        r[c].suma = 0;
        r[c].minimo = 0;      /* no se usan hasta tener la primera medicion */
        r[c].maximo = 0;
        r[c].promedio = 0.0;
        r[c].alertas = 0;
    }

    for (i = 0; i < d->total; i++) {
        c = d->mediciones[i].categoria;
        v = d->mediciones[i].valor;

        if (r[c].cantidad == 0) {      /* primera medicion de esta categoria */
            r[c].minimo = v;
            r[c].maximo = v;
        } else {
            if (v < r[c].minimo) r[c].minimo = v;
            if (v > r[c].maximo) r[c].maximo = v;
        }
        r[c].cantidad++;
        r[c].suma += v;
        if (v >= UMBRAL[c]) r[c].alertas++;
    }

    for (c = 0; c < NUM_CAT; c++)
        if (r[c].cantidad > 0)          /* evita dividir entre cero */
            r[c].promedio = (double)r[c].suma / r[c].cantidad;
}

/* Escribe el informe. Devuelve 0 si todo salio bien, -1 si hubo error. */
static int escribir_informe(const char *ruta, const Datos *d,
                            const ResumenCategoria r[NUM_CAT]) {
    FILE *f = fopen(ruta, "w");
    int   c, total_alertas = 0;

    if (f == NULL) {
        fprintf(stderr, "ERROR: no se pudo crear el informe '%s'\n", ruta);
        return -1;
    }

    fprintf(f, "INFORME DE MONITOREO\n");
    fprintf(f, "Etiqueta: %s\n", d->etiqueta);
    fprintf(f, "Registros: %d\n\n", d->total);

    for (c = 0; c < NUM_CAT; c++) {
        fprintf(f, "Categoria %s\n", NOMBRES[c]);
        if (r[c].cantidad == 0) {
            fprintf(f, "  Sin datos\n\n");
            continue;
        }
        fprintf(f, "  Cantidad: %d\n", r[c].cantidad);
        fprintf(f, "  Suma: %ld\n", r[c].suma);
        fprintf(f, "  Minimo: %d\n", r[c].minimo);
        fprintf(f, "  Maximo: %d\n", r[c].maximo);
        fprintf(f, "  Promedio: %.2f\n", r[c].promedio);
        fprintf(f, "  Alertas: %d\n\n", r[c].alertas);
        total_alertas += r[c].alertas;
    }

    fprintf(f, "Observaciones que cumplen condiciones de alerta: %d\n", total_alertas);
    fprintf(f, "Umbrales utilizados con fines didacticos.\n");

    /* ferror revisa si hubo fallo de escritura; fclose tambien puede fallar */
    if (ferror(f)) {
        fprintf(stderr, "ERROR: fallo al escribir el informe\n");
        fclose(f);
        return -1;
    }
    if (fclose(f) != 0) {
        fprintf(stderr, "ERROR: fallo al cerrar el informe\n");
        return -1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    Datos            datos;
    ResumenCategoria resumen[NUM_CAT];
    int              estado = 0;

    if (argc != 3) {
        fprintf(stderr, "Uso: %s <entrada.txt> <informe.txt>\n", argv[0]);
        return 1;
    }

    if (leer_entrada(argv[1], &datos) != 0)
        return 1;                       /* leer_entrada ya libero todo */

    procesar(&datos, resumen);

    if (escribir_informe(argv[2], &datos, resumen) != 0)
        estado = 1;

    free(datos.mediciones);             /* free(NULL) es seguro */
    return estado;
}
