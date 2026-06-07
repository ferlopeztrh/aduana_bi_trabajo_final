"""Extraccion: lectura de los CSV crudos del Data Lake (capa bronze)."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

ENCODING = "utf-8"


def leer_csv(path: Path, nrows: int | None = None, chunksize: int | None = None):
    """Lee un CSV crudo como texto (dtype=str); la conversion de tipos ocurre
    en transform. Si se pasa chunksize, devuelve un iterador de DataFrames."""
    return pd.read_csv(
        path,
        sep=",",
        quotechar='"',
        dtype=str,
        encoding=ENCODING,
        encoding_errors="replace",
        nrows=nrows,
        chunksize=chunksize,
        on_bad_lines="warn",
    )
