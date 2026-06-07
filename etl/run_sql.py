"""Ejecuta archivos .sql contra el Data Warehouse (alternativa a psql, multiplataforma).

Las sentencias que devuelven filas (SELECT) imprimen su resultado, lo que permite
usar este mismo comando tanto para el esquema/vistas como para los análisis.

Uso:
    python -m etl.run_sql sql/01_schema.sql sql/02_constraints.sql
    python -m etl.run_sql sql/03_views_olap.sql sql/04_aggregates.sql
    python -m etl.run_sql analysis/consultas_olap.sql      # imprime resultados
"""

from __future__ import annotations

import argparse
import logging
import re
from pathlib import Path

import pandas as pd

from etl import load

log = logging.getLogger("run_sql")


def _sentencias(texto: str):
    """Separa un script SQL en sentencias, quitando los comentarios de línea."""
    sin_comentarios = "\n".join(re.sub(r"--.*", "", linea) for linea in texto.splitlines())
    for sentencia in sin_comentarios.split(";"):
        sentencia = sentencia.strip()
        if sentencia:
            yield sentencia


def ejecutar_archivo(engine, path: Path) -> None:
    log.info("Ejecutando %s", path.name)
    with engine.begin() as conn:
        for sentencia in _sentencias(path.read_text(encoding="utf-8")):
            resultado = conn.exec_driver_sql(sentencia)
            if resultado.returns_rows:
                df = pd.DataFrame(resultado.fetchall(), columns=list(resultado.keys()))
                print(df.to_string(index=False), "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Ejecuta archivos .sql contra PostgreSQL")
    parser.add_argument("archivos", nargs="+", help="Rutas a los archivos .sql")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    engine = load.crear_engine()
    for archivo in args.archivos:
        ejecutar_archivo(engine, Path(archivo))


if __name__ == "__main__":
    main()
