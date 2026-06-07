"""Construccion de las dimensiones a partir de las tablas de staging.

Cada dimension siembra primero su miembro -1 ('NO DEFINIDO') para los nulos,
y luego inserta los valores distintos. ON CONFLICT garantiza idempotencia.
"""

from __future__ import annotations

from sqlalchemy.engine import Engine

from etl import load

_SENTENCIAS = [
    # dim_fecha (clave AAAAMMDD; -1 = desconocida)
    """INSERT INTO dw.dim_fecha (fecha_sk, fecha) VALUES (-1, NULL)
       ON CONFLICT (fecha_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_fecha
         (fecha_sk, fecha, anio, mes_numero, mes_nombre, trimestre, semestre,
          anio_mes, dia, dia_semana, nombre_dia)
       SELECT DISTINCT
         to_char(f,'YYYYMMDD')::int, f,
         extract(year  from f)::smallint,
         extract(month from f)::smallint,
         initcap(trim(to_char(f,'TMMonth'))),
         extract(quarter from f)::smallint,
         (case when extract(month from f) <= 6 then 1 else 2 end)::smallint,
         to_char(f,'YYYY-MM'),
         extract(day from f)::smallint,
         extract(isodow from f)::smallint,
         initcap(trim(to_char(f,'TMDay')))
       FROM (
         SELECT oficializacion AS f FROM dw.stg_item    WHERE oficializacion IS NOT NULL
         UNION SELECT cancelacion FROM dw.stg_item       WHERE cancelacion   IS NOT NULL
         UNION SELECT oficializacion FROM dw.stg_subitem WHERE oficializacion IS NOT NULL
         UNION SELECT cancelacion FROM dw.stg_subitem    WHERE cancelacion   IS NOT NULL
       ) d
       ON CONFLICT (fecha_sk) DO NOTHING;""",

    # dim_operacion
    """INSERT INTO dw.dim_operacion (operacion_sk, operacion, es_importacion, es_exportacion)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO', false, false)
       ON CONFLICT (operacion_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_operacion (operacion, es_importacion, es_exportacion)
       SELECT DISTINCT operacion, upper(operacion)='IMPORTACION', upper(operacion)='EXPORTACION'
       FROM dw.stg_item WHERE operacion IS NOT NULL
       ON CONFLICT (operacion) DO NOTHING;""",

    # dim_destinacion (codigo + descripcion = regimen asociado)
    """INSERT INTO dw.dim_destinacion (destinacion_sk, cod_destinacion, descripcion)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'ND', 'NO DEFINIDO')
       ON CONFLICT (destinacion_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_destinacion (cod_destinacion, descripcion)
       SELECT DISTINCT ON (destinacion) destinacion, regimen
       FROM dw.stg_item WHERE destinacion IS NOT NULL
       ORDER BY destinacion, regimen
       ON CONFLICT (cod_destinacion) DO NOTHING;""",

    # dim_regimen
    """INSERT INTO dw.dim_regimen (regimen_sk, regimen)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (regimen_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_regimen (regimen)
       SELECT DISTINCT regimen FROM dw.stg_item WHERE regimen IS NOT NULL
       ON CONFLICT (regimen) DO NOTHING;""",

    # dim_aduana
    """INSERT INTO dw.dim_aduana (aduana_sk, aduana)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (aduana_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_aduana (aduana)
       SELECT DISTINCT aduana FROM dw.stg_item WHERE aduana IS NOT NULL
       ON CONFLICT (aduana) DO NOTHING;""",

    # dim_pais (union origen + destino, ambos staging)
    """INSERT INTO dw.dim_pais (pais_sk, pais)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (pais_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_pais (pais)
       SELECT DISTINCT p FROM (
         SELECT pais_origen AS p FROM dw.stg_item    WHERE pais_origen  IS NOT NULL
         UNION SELECT pais_destino FROM dw.stg_item   WHERE pais_destino IS NOT NULL
         UNION SELECT pais_origen FROM dw.stg_subitem WHERE pais_origen  IS NOT NULL
         UNION SELECT pais_destino FROM dw.stg_subitem WHERE pais_destino IS NOT NULL
       ) x
       ON CONFLICT (pais) DO NOTHING;""",

    # dim_producto (una fila por posicion NCM)
    """INSERT INTO dw.dim_producto (producto_sk, posicion_ncm, rubro)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'ND', 'NO DEFINIDO')
       ON CONFLICT (producto_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_producto (posicion_ncm, rubro, desc_capitulo, desc_partida, desc_posicion)
       SELECT DISTINCT ON (posicion) posicion, rubro, desc_capitulo, desc_partida, desc_posicion
       FROM dw.stg_item WHERE posicion IS NOT NULL
       ORDER BY posicion
       ON CONFLICT (posicion_ncm) DO NOTHING;""",

    # dim_medio_transporte
    """INSERT INTO dw.dim_medio_transporte (medio_transporte_sk, medio_transporte)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (medio_transporte_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_medio_transporte (medio_transporte)
       SELECT DISTINCT medio_transporte FROM dw.stg_item WHERE medio_transporte IS NOT NULL
       ON CONFLICT (medio_transporte) DO NOTHING;""",

    # dim_canal
    """INSERT INTO dw.dim_canal (canal_sk, canal)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'ND')
       ON CONFLICT (canal_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_canal (canal)
       SELECT DISTINCT canal FROM dw.stg_item WHERE canal IS NOT NULL
       ON CONFLICT (canal) DO NOTHING;""",

    # dim_unidad_medida
    """INSERT INTO dw.dim_unidad_medida (unidad_medida_sk, unidad_medida)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (unidad_medida_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_unidad_medida (unidad_medida)
       SELECT DISTINCT unidad_medida FROM dw.stg_item WHERE unidad_medida IS NOT NULL
       ON CONFLICT (unidad_medida) DO NOTHING;""",

    # dim_acuerdo
    """INSERT INTO dw.dim_acuerdo (acuerdo_sk, acuerdo)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (acuerdo_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_acuerdo (acuerdo)
       SELECT DISTINCT acuerdo FROM dw.stg_item WHERE acuerdo IS NOT NULL
       ON CONFLICT (acuerdo) DO NOTHING;""",

    # dim_marca (union item + subitem)
    """INSERT INTO dw.dim_marca (marca_sk, marca)
       OVERRIDING SYSTEM VALUE VALUES (-1, 'NO DEFINIDO')
       ON CONFLICT (marca_sk) DO NOTHING;""",
    """INSERT INTO dw.dim_marca (marca)
       SELECT DISTINCT m FROM (
         SELECT marca_item AS m FROM dw.stg_item       WHERE marca_item   IS NOT NULL
         UNION SELECT marca_subitem FROM dw.stg_subitem WHERE marca_subitem IS NOT NULL
       ) x
       ON CONFLICT (marca) DO NOTHING;""",
]


def poblar(engine: Engine) -> None:
    load.ejecutar(engine, _SENTENCIAS)
