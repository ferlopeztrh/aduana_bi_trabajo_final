# Aduana BI - Data Warehouse, ETL y OLAP (DNIT 2025)

Solución de **Inteligencia de Negocios end-to-end** sobre datos reales de la Aduana
paraguaya (DNIT), año 2025. Trabajo Final de la materia _Inteligencia de Negocios_
(Ingeniería en Sistemas, Universidad Columbia del Paraguay).

## Arquitectura

```
bronze (CSV crudo) → silver (CSV limpio) → staging → modelo estrella (PostgreSQL) → OLAP → Power BI
```

El ETL en Python conecta el Data Lake con el Data Warehouse (extract → transform → load con COPY).

## Estructura del proyecto

| Carpeta / archivo   | Contenido                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| `data-lake/bronze/` | CSV originales sin modificar (24 archivos = 12 meses × 2 niveles)                                     |
| `data-lake/silver/` | datos limpios y normalizados (CSV, los genera el ETL)                                                 |
| `data-lake/gold/`   | dimensiones y agregados listos para análisis (CSV, los genera `export_gold`)                          |
| `etl/`              | scripts Python: `etl_aduana` (orquestador ETL), `run_sql` (ejecuta `.sql`), `export_gold` (capa gold) |
| `sql/`              | `01_schema`, `02_constraints`, `03_views_olap`, `04_aggregates`                                       |
| `analysis/`         | `consultas_olap.sql` (los análisis del proyecto)                                                      |
| `docker/`           | `docker-compose.yml` del motor PostgreSQL                                                             |

---

# Guía paso a paso (desde cero)

Pensada para alguien que clona el repo por primera vez. Los comandos se muestran en
**PowerShell (Windows)**; los `python -m ...` funcionan igual en cualquier sistema operativo.

## Requisitos previos

- **Docker Desktop** con Docker Compose, en ejecución.
- **Python 3.11+** (probado en 3.14).
- **Git**.
- Los **24 archivos CSV** de la DNIT (no se versionan por su tamaño, ~8.8 GB).

## Paso 0 - Clonar el repositorio

```powershell
git clone https://github.com/ferlopeztrh/aduana_bi_trabajo_final.git
cd aduana_bi_trabajo_final
```

## Paso 1 - Colocar los datos en bronze

Copiá los 24 CSV en `data-lake/bronze/`. Nombres esperados (por cada mes en mayúsculas):

```
data-lake/bronze/2025_ENERO_Nivel_Item.csv      # nivel ÍTEM
data-lake/bronze/2025_ENERO.csv                 # nivel SUBÍTEM
... (FEBRERO, MARZO, ..., DICIEMBRE)
```

## Paso 2 - Configurar variables de entorno

```powershell
Copy-Item .env.example .env
# Editá .env con tu usuario, clave, puerto y nombre de la base.
```

## Paso 3 - Levantar PostgreSQL (contenedor `aduana_db`)

```powershell
docker compose --env-file .env -f docker/docker-compose.yml up -d
docker compose --env-file .env -f docker/docker-compose.yml ps   # debe figurar "healthy"
```

La base queda en `localhost:5444` (puerto configurable en `.env`).

## Paso 4 - Entorno virtual e instalación de dependencias

Buena práctica: aislar las dependencias del proyecto en un entorno virtual (`venv`).
Se crea una sola vez y se **activa** cada vez que abrís una terminal para trabajar; a partir
de ahí, `python` y `pip` apuntan al entorno del proyecto.

```powershell
# 1) Crear el entorno virtual (una sola vez)
python -m venv .venv

# 2) Activarlo (el prompt pasa a mostrar "(.venv)")
.\.venv\Scripts\Activate.ps1

# 3) Instalar las dependencias (una sola vez)
pip install -r requirements.txt
```

> **Primera vez en Windows:** si la activación falla con _"la ejecución de scripts está
> deshabilitada en este sistema"_, habilitá los scripts para tu usuario (una sola vez) y
> volvé a activar:
>
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```
>
> Es el ajuste estándar para usar entornos virtuales de Python en PowerShell.

Con el entorno activado, **todos los comandos siguientes** se corren con `python ...`.

## Paso 5 - Crear el esquema estrella

Los scripts SQL se ejecutan con un comando Python (multiplataforma, no depende del shell):

```powershell
python -m etl.run_sql sql/01_schema.sql sql/02_constraints.sql
```

> El `01_schema.sql` es **idempotente** (recrea el esquema desde cero); se puede correr las veces que haga falta.

## Paso 6 - Ejecutar el ETL (bronze → silver → staging → estrella)

```powershell
# Carga completa de todo el año (con la capa silver), tarda ~30-50 min:
python -m etl.etl_aduana --hilos 6

# Prueba rápida (sin cargar los 8.8 GB): 5000 filas de un mes, sin silver
python -m etl.etl_aduana --meses ENERO --muestra 5000 --sin-silver
```

Opciones: `--meses ENERO FEBRERO` (meses puntuales), `--muestra N` (límite por archivo),
`--sin-silver` (no escribe silver), `--hilos N` (paralelismo, default = nº de núcleos hasta 4).

## Paso 7 - Crear las vistas y agregados OLAP

```powershell
python -m etl.run_sql sql/03_views_olap.sql sql/04_aggregates.sql
```

> `04_aggregates.sql` crea **vistas materializadas**: se llenan con los datos al crearse,
> por eso este paso va **después** del ETL.

## Paso 8 - Exportar la capa gold (dimensiones y agregados a CSV)

```powershell
python -m etl.export_gold     # escribe data-lake/gold/*.csv
```

## Paso 9 - Verificar / correr los análisis

```powershell
python -m etl.run_sql analysis/consultas_olap.sql   # imprime los resultados en consola
```

## Paso 10 - Conectar Power BI

1. Power BI Desktop → **Obtener datos → Base de datos PostgreSQL**
   (la primera vez ofrece instalar el proveedor **Npgsql**; aceptar).
2. Servidor: `localhost:5444` · Base de datos: `aduana_bi`.
3. Usuario y clave: los que definiste en `.env`.
4. Importar las tablas `dw.dim_*` y `dw.fact_aduana_item` (modelo estrella nativo;
   Power BI detecta las relaciones por las claves), o las `dw.agg_*` para visuales rápidos.

---

## Comandos útiles / mantenimiento

```powershell
# Detener / arrancar el contenedor (conserva los datos)
docker compose --env-file .env -f docker/docker-compose.yml stop
docker compose --env-file .env -f docker/docker-compose.yml start

# Borrar TODO (contenedor + datos del volumen)
docker compose --env-file .env -f docker/docker-compose.yml down -v

# Refrescar los agregados tras recargar datos (recrea las vistas materializadas)
python -m etl.run_sql sql/04_aggregates.sql

# Consola SQL interactiva (opcional, para consultas ad-hoc)
docker exec -it aduana_db psql -U aduana -d aduana_bi
```

## Solución de problemas

| Síntoma                                        | Causa / solución                                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| `pip install` falla en alguna librería         | Python 3.14 muy nuevo: usar Python 3.12/3.13 para el venv.                          |
| OneDrive sincroniza muchos GB al correr el ETL | La capa silver pesa ~8.8 GB; pausar la sincronización, o correr con `--sin-silver`. |
| `port is already allocated` al levantar Docker | El puerto 5444 está ocupado: cambiar `POSTGRES_PORT` en `.env`.                     |
| Power BI no encuentra el conector              | Instalar el proveedor **Npgsql** (Power BI lo ofrece al conectar).                  |
| `psql: could not connect`                      | El contenedor no está "healthy": revisar con `docker compose ... ps`.               |
