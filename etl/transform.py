"""Transformacion: limpieza y normalizacion de los datos crudos.

Convierte un DataFrame leido de bronze al formato tipado de las tablas de
staging (decimales con coma, fechas DD/MM/YYYY, nulos, recorte de texto).
"""

from __future__ import annotations

import pandas as pd

MAPA_ITEM = {
    "DESPACHO CIFRADO": "despacho_cifrado",
    "OPERACION": "operacion",
    "DESTINACION": "destinacion",
    "REGIMEN": "regimen",
    "OFICIALIZACION": "oficializacion",
    "CANCELACION": "cancelacion",
    "AÑO": "anio",
    "MES": "mes",
    "ADUANA": "aduana",
    "COTIZACION": "cotizacion",
    "MEDIO TRANSPORTE": "medio_transporte",
    "CANAL": "canal",
    "ITEM": "item",
    "PAIS ORIGEN": "pais_origen",
    "PAIS PROCEDENCIA/DESTINO": "pais_destino",
    "USO": "uso",
    "UNIDAD MEDIDA ESTADISTICA": "unidad_medida",
    "CANTIDAD ESTADISTICA": "cantidad_estadistica",
    "KILO NETO": "kilo_neto",
    "KILO BRUTO": "kilo_bruto",
    "FOB DOLAR": "fob_usd",
    "FLETE DOLAR": "flete_usd",
    "SEGURO DOLAR": "seguro_usd",
    "IMPONIBLE DOLAR": "imponible_usd",
    "IMPONIBLE GS": "imponible_gs",
    "AJUSTE A INCLUIR": "ajuste_incluir",
    "AJUSTE A DEDUCIR": "ajuste_deducir",
    "POSICION": "posicion",
    "RUBRO": "rubro",
    "DESC CAPITULO": "desc_capitulo",
    "DESC PARTIDA": "desc_partida",
    "DESC POSICION": "desc_posicion",
    "MERCADERIA": "mercaderia",
    "MARCA ITEM": "marca_item",
    "ACUERDO": "acuerdo",
    "DERECHO": "derecho",
    "ISC": "isc",
    "SERVICIO": "servicio",
    "RENTA": "renta",
    "IVA": "iva",
    "OTROS": "otros",
    "TOTAL": "total",
}

MAPA_SUBITEM = {
    "DESPACHO CIFRADO": "despacho_cifrado",
    "ITEM": "item",
    "NUMERO SUBITEM": "numero_subitem",
    "OPERACION": "operacion",
    "DESTINACION": "destinacion",
    "REGIMEN": "regimen",
    "OFICIALIZACION": "oficializacion",
    "CANCELACION": "cancelacion",
    "ADUANA": "aduana",
    "PAIS ORIGEN": "pais_origen",
    "PAIS PROCEDENCIA/DESTINO": "pais_destino",
    "POSICION": "posicion",
    "UNIDAD MEDIDA ESTADISTICA": "unidad_medida",
    "CANTIDAD SUBITEM": "cantidad_subitem",
    "PRECION UNITARIO SUBITEM": "precio_unitario",
    "DESC SUBITEM": "desc_subitem",
    "MARCA SUBITEM": "marca_subitem",
    "ACUERDO": "acuerdo",
}

_NUM_ITEM = [
    "cotizacion", "cantidad_estadistica", "kilo_neto", "kilo_bruto",
    "fob_usd", "flete_usd", "seguro_usd", "imponible_usd", "imponible_gs",
    "ajuste_incluir", "ajuste_deducir", "derecho", "isc", "servicio",
    "renta", "iva", "otros", "total",
]
_INT_ITEM = ["anio", "item"]
_FECHA_ITEM = ["oficializacion", "cancelacion"]

_NUM_SUB = ["cantidad_subitem", "precio_unitario"]
_INT_SUB = ["item", "numero_subitem"]
_FECHA_SUB = ["oficializacion", "cancelacion"]


def _a_numero(s: pd.Series) -> pd.Series:
    # Decimal con coma y sin separador de miles: "375023,14" -> 375023.14, ",0" -> 0.0
    limpio = s.str.strip().str.replace(".", "", regex=False).str.replace(",", ".", regex=False)
    return pd.to_numeric(limpio, errors="coerce")


def _a_entero(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s.str.strip(), errors="coerce").astype("Int64")


def _a_fecha(s: pd.Series) -> pd.Series:
    return pd.to_datetime(s.str.strip(), format="%d/%m/%Y", errors="coerce").dt.strftime("%Y-%m-%d")


def _preparar(df: pd.DataFrame, mapa: dict, numericas, enteros, fechas) -> pd.DataFrame:
    df = df.rename(columns={c: c.strip() for c in df.columns})
    df = df.rename(columns=mapa)
    df = df[[c for c in mapa.values() if c in df.columns]]

    for col in df.columns:
        if col in numericas:
            df[col] = _a_numero(df[col])
        elif col in enteros:
            df[col] = _a_entero(df[col])
        elif col in fechas:
            df[col] = _a_fecha(df[col])
        else:
            df[col] = df[col].str.strip().replace("", pd.NA)
    return df


def limpiar_item(df: pd.DataFrame) -> pd.DataFrame:
    return _preparar(df, MAPA_ITEM, _NUM_ITEM, _INT_ITEM, _FECHA_ITEM)


def limpiar_subitem(df: pd.DataFrame) -> pd.DataFrame:
    return _preparar(df, MAPA_SUBITEM, _NUM_SUB, _INT_SUB, _FECHA_SUB)
