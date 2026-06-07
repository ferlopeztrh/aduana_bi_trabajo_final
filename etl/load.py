"""Carga: conexion a PostgreSQL y utilidades de carga masiva (COPY)."""

from __future__ import annotations

import io

import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine

from etl import config

_NULL = r"\N"


def crear_engine(pool_size: int = 5) -> Engine:
    return create_engine(config.get_database_url(), pool_size=pool_size, max_overflow=4)


def ejecutar(engine: Engine, sentencias: list[str]) -> None:
    """Ejecuta una lista de sentencias SQL en una sola transaccion."""
    with engine.begin() as conn:
        for sql in sentencias:
            conn.exec_driver_sql(sql)


def truncar(engine: Engine, *tablas: str) -> None:
    """Vacia las tablas dadas en una sola sentencia (atomica respecto a las FK)."""
    ejecutar(engine, [f"TRUNCATE {', '.join(tablas)} RESTART IDENTITY CASCADE;"])


def copiar_dataframe(engine: Engine, df: pd.DataFrame, tabla: str) -> int:
    """Carga un DataFrame a una tabla via COPY (formato CSV). Devuelve filas."""
    if df.empty:
        return 0
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False, na_rep=_NULL)
    buffer.seek(0)

    columnas = ", ".join(df.columns)
    sql = f"COPY {tabla} ({columnas}) FROM STDIN WITH (FORMAT csv, NULL '{_NULL}')"

    raw = engine.raw_connection()
    try:
        with raw.cursor() as cur, cur.copy(sql) as copy:
            copy.write(buffer.read())
        raw.commit()
    finally:
        raw.close()
    return len(df)
