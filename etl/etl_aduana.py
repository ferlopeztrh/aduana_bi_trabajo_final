"""Orquestador del ETL: bronze -> silver -> staging -> dimensiones -> hechos.

Uso:
    python -m etl.etl_aduana                 # todos los meses, completo
    python -m etl.etl_aduana --meses ENERO   # solo enero
    python -m etl.etl_aduana --muestra 5000  # 5000 filas por archivo (prueba)
    python -m etl.etl_aduana --sin-silver    # no escribe la capa silver
"""

from __future__ import annotations

import argparse
import logging
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from etl import build_dimensions, build_facts, config, extract, load, transform

MESES = [
    "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
    "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE",
]
CHUNK = 200_000

log = logging.getLogger("etl_aduana")


def _procesar_archivo(engine, path: Path, tabla: str, limpiar, silver: Path | None,
                      muestra: int | None) -> int:
    if not path.exists():
        log.warning("No existe %s; se omite.", path.name)
        return 0

    total = 0
    primero = True
    chunksize = None if muestra else CHUNK
    iterador = extract.leer_csv(path, nrows=muestra, chunksize=chunksize)
    bloques = iterador if chunksize else [iterador]

    for bruto in bloques:
        limpio = limpiar(bruto)
        total += load.copiar_dataframe(engine, limpio, tabla)
        if silver is not None:
            limpio.to_csv(silver, mode="w" if primero else "a",
                          header=primero, index=False)
        primero = False
    log.info("  %-9s -> %s: %d filas", path.name, tabla, total)
    return total


def ejecutar(meses: list[str], muestra: int | None, escribir_silver: bool, hilos: int) -> None:
    engine = load.crear_engine(pool_size=hilos + 1)

    if escribir_silver:
        config.SILVER_DIR.mkdir(parents=True, exist_ok=True)

    log.info("Limpiando el Data Warehouse (rebuild completo)...")
    load.truncar(
        engine,
        "dw.fact_aduana_item", "dw.fact_aduana_subitem",
        "dw.dim_fecha", "dw.dim_operacion", "dw.dim_destinacion", "dw.dim_regimen",
        "dw.dim_aduana", "dw.dim_pais", "dw.dim_producto", "dw.dim_medio_transporte",
        "dw.dim_canal", "dw.dim_unidad_medida", "dw.dim_acuerdo", "dw.dim_marca",
        "dw.stg_item", "dw.stg_subitem",
    )

    # Una tarea por archivo (mes x nivel); se procesan en paralelo.
    tareas = []
    for mes in meses:
        item = config.BRONZE_DIR / f"2025_{mes}_Nivel_Item.csv"
        sub = config.BRONZE_DIR / f"2025_{mes}.csv"
        sv_item = (config.SILVER_DIR / f"{mes.lower()}_item.csv") if escribir_silver else None
        sv_sub = (config.SILVER_DIR / f"{mes.lower()}_subitem.csv") if escribir_silver else None
        tareas.append((item, "dw.stg_item", transform.limpiar_item, sv_item))
        tareas.append((sub, "dw.stg_subitem", transform.limpiar_subitem, sv_sub))

    log.info("Cargando staging con %d hilos (%d archivos)...", hilos, len(tareas))
    with ThreadPoolExecutor(max_workers=hilos) as pool:
        futuros = [pool.submit(_procesar_archivo, engine, *t, muestra) for t in tareas]
        for f in as_completed(futuros):
            f.result()  # propaga cualquier excepcion de los hilos

    log.info("Construyendo dimensiones...")
    build_dimensions.poblar(engine)

    log.info("Construyendo hechos...")
    build_facts.poblar(engine)

    log.info("ETL finalizado.")


def main() -> None:
    parser = argparse.ArgumentParser(description="ETL Aduana BI")
    parser.add_argument("--meses", nargs="+", default=MESES, help="Meses a procesar")
    parser.add_argument("--muestra", type=int, default=None, help="Filas por archivo (prueba)")
    parser.add_argument("--sin-silver", action="store_true", help="No escribir capa silver")
    parser.add_argument("--hilos", type=int, default=min(4, os.cpu_count() or 2),
                        help="Cantidad de hilos para cargar archivos en paralelo")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    ejecutar([m.upper() for m in args.meses], args.muestra, not args.sin_silver, args.hilos)


if __name__ == "__main__":
    main()
