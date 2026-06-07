"""Configuracion central del proyecto: rutas y conexion a la base de datos.

Las credenciales se leen del archivo .env con la biblioteca estandar (os/pathlib),
sin dependencias externas.
"""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR: Path = Path(__file__).resolve().parent.parent

DATA_LAKE_DIR: Path = BASE_DIR / "data-lake"
BRONZE_DIR: Path = DATA_LAKE_DIR / "bronze"
SILVER_DIR: Path = DATA_LAKE_DIR / "silver"
GOLD_DIR: Path = DATA_LAKE_DIR / "gold"

SQL_DIR: Path = BASE_DIR / "sql"
ANALYSIS_DIR: Path = BASE_DIR / "analysis"


def _load_env(path: Path) -> None:
    """Carga variables KEY=VALUE de un archivo .env al entorno (os.environ)."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_load_env(BASE_DIR / ".env")

DB_USER: str = os.getenv("POSTGRES_USER", "aduana")
DB_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "")
DB_NAME: str = os.getenv("POSTGRES_DB", "aduana_bi")
DB_HOST: str = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT: str = os.getenv("POSTGRES_PORT", "5444")


def get_database_url() -> str:
    """URL de conexion SQLAlchemy para PostgreSQL (driver psycopg v3)."""
    return (
        f"postgresql+psycopg://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
