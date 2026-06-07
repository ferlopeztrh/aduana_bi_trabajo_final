"""Exporta el modelo dimensional a la capa gold del Data Lake (CSV).

Gold = datos estructurados para análisis: las dimensiones y las tablas
agregadas. Los hechos completos viven en PostgreSQL (DWH) y en silver.

Uso:  python -m etl.export_gold
"""

from __future__ import annotations

import logging

import pandas as pd

from etl import config, load

DIMENSIONES = [
    "dim_fecha", "dim_operacion", "dim_destinacion", "dim_regimen",
    "dim_aduana", "dim_pais", "dim_producto", "dim_medio_transporte",
    "dim_canal", "dim_unidad_medida", "dim_acuerdo", "dim_marca",
]
AGREGADOS = ["agg_mensual_operacion", "agg_pais_mensual", "agg_producto", "agg_aduana_mensual"]

log = logging.getLogger("export_gold")


def exportar(engine, tablas: list[str]) -> None:
    config.GOLD_DIR.mkdir(parents=True, exist_ok=True)
    for tabla in tablas:
        df = pd.read_sql(f"SELECT * FROM dw.{tabla}", engine)
        destino = config.GOLD_DIR / f"{tabla}.csv"
        df.to_csv(destino, index=False)
        log.info("  %-22s -> %s (%d filas)", tabla, destino.name, len(df))


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    engine = load.crear_engine()
    log.info("Exportando dimensiones y agregados a gold...")
    exportar(engine, DIMENSIONES + AGREGADOS)
    log.info("Gold exportado en %s", config.GOLD_DIR)


if __name__ == "__main__":
    main()
