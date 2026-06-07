"""Construccion de las tablas de hechos uniendo staging con las dimensiones.

Las claves no encontradas se resuelven al miembro -1 ('NO DEFINIDO').
"""

from __future__ import annotations

from sqlalchemy.engine import Engine

from etl import load

_FACT_ITEM = """
INSERT INTO dw.fact_aduana_item (
    despacho_cifrado, item,
    fecha_oficializacion_sk, fecha_cancelacion_sk,
    operacion_sk, destinacion_sk, regimen_sk, aduana_sk,
    pais_origen_sk, pais_destino_sk, producto_sk,
    medio_transporte_sk, canal_sk, unidad_medida_sk, acuerdo_sk, marca_sk,
    uso, mercaderia, cotizacion,
    cantidad_estadistica, kilo_neto, kilo_bruto,
    fob_usd, flete_usd, seguro_usd, imponible_usd, imponible_gs,
    ajuste_incluir, ajuste_deducir,
    derecho, isc, servicio, renta, iva, otros, total
)
SELECT
    s.despacho_cifrado, s.item,
    COALESCE(to_char(s.oficializacion,'YYYYMMDD')::int, -1),
    COALESCE(to_char(s.cancelacion,'YYYYMMDD')::int, -1),
    COALESCE(o.operacion_sk,   -1),
    COALESCE(d.destinacion_sk, -1),
    COALESCE(r.regimen_sk,     -1),
    COALESCE(a.aduana_sk,      -1),
    COALESCE(po.pais_sk,       -1),
    COALESCE(pd.pais_sk,       -1),
    COALESCE(pr.producto_sk,   -1),
    COALESCE(mt.medio_transporte_sk, -1),
    COALESCE(c.canal_sk,       -1),
    COALESCE(um.unidad_medida_sk, -1),
    COALESCE(ac.acuerdo_sk,    -1),
    COALESCE(m.marca_sk,       -1),
    s.uso, s.mercaderia, s.cotizacion,
    s.cantidad_estadistica, s.kilo_neto, s.kilo_bruto,
    s.fob_usd, s.flete_usd, s.seguro_usd, s.imponible_usd, s.imponible_gs,
    s.ajuste_incluir, s.ajuste_deducir,
    s.derecho, s.isc, s.servicio, s.renta, s.iva, s.otros, s.total
FROM dw.stg_item s
LEFT JOIN dw.dim_operacion        o  ON s.operacion        = o.operacion
LEFT JOIN dw.dim_destinacion      d  ON s.destinacion      = d.cod_destinacion
LEFT JOIN dw.dim_regimen          r  ON s.regimen          = r.regimen
LEFT JOIN dw.dim_aduana           a  ON s.aduana           = a.aduana
LEFT JOIN dw.dim_pais             po ON s.pais_origen      = po.pais
LEFT JOIN dw.dim_pais             pd ON s.pais_destino     = pd.pais
LEFT JOIN dw.dim_producto         pr ON s.posicion         = pr.posicion_ncm
LEFT JOIN dw.dim_medio_transporte mt ON s.medio_transporte = mt.medio_transporte
LEFT JOIN dw.dim_canal            c  ON s.canal            = c.canal
LEFT JOIN dw.dim_unidad_medida    um ON s.unidad_medida    = um.unidad_medida
LEFT JOIN dw.dim_acuerdo          ac ON s.acuerdo          = ac.acuerdo
LEFT JOIN dw.dim_marca            m  ON s.marca_item       = m.marca;
"""

_FACT_SUBITEM = """
INSERT INTO dw.fact_aduana_subitem (
    despacho_cifrado, item, numero_subitem,
    fecha_oficializacion_sk,
    operacion_sk, destinacion_sk, regimen_sk, aduana_sk,
    pais_origen_sk, pais_destino_sk, producto_sk,
    unidad_medida_sk, acuerdo_sk, marca_subitem_sk,
    desc_subitem, cantidad_subitem, precio_unitario
)
SELECT
    s.despacho_cifrado, s.item, s.numero_subitem,
    COALESCE(to_char(s.oficializacion,'YYYYMMDD')::int, -1),
    COALESCE(o.operacion_sk,   -1),
    COALESCE(d.destinacion_sk, -1),
    COALESCE(r.regimen_sk,     -1),
    COALESCE(a.aduana_sk,      -1),
    COALESCE(po.pais_sk,       -1),
    COALESCE(pd.pais_sk,       -1),
    COALESCE(pr.producto_sk,   -1),
    COALESCE(um.unidad_medida_sk, -1),
    COALESCE(ac.acuerdo_sk,    -1),
    COALESCE(m.marca_sk,       -1),
    s.desc_subitem, s.cantidad_subitem, s.precio_unitario
FROM dw.stg_subitem s
LEFT JOIN dw.dim_operacion     o  ON s.operacion     = o.operacion
LEFT JOIN dw.dim_destinacion   d  ON s.destinacion   = d.cod_destinacion
LEFT JOIN dw.dim_regimen       r  ON s.regimen       = r.regimen
LEFT JOIN dw.dim_aduana        a  ON s.aduana        = a.aduana
LEFT JOIN dw.dim_pais          po ON s.pais_origen   = po.pais
LEFT JOIN dw.dim_pais          pd ON s.pais_destino  = pd.pais
LEFT JOIN dw.dim_producto      pr ON s.posicion      = pr.posicion_ncm
LEFT JOIN dw.dim_unidad_medida um ON s.unidad_medida = um.unidad_medida
LEFT JOIN dw.dim_acuerdo       ac ON s.acuerdo       = ac.acuerdo
LEFT JOIN dw.dim_marca         m  ON s.marca_subitem = m.marca;
"""


def poblar(engine: Engine) -> None:
    load.truncar(engine, "dw.fact_aduana_item", "dw.fact_aduana_subitem")
    load.ejecutar(engine, [_FACT_ITEM, _FACT_SUBITEM])
