-- ============================================================================
--  03_views_olap.sql  —  Vistas analiticas (simulacion OLAP)
--  Denormalizan el esquema estrella para facilitar consultas y Power BI.
-- ============================================================================

SET search_path TO dw;

-- Vista base: hechos de item con todas sus dimensiones resueltas.
CREATE OR REPLACE VIEW dw.vw_item AS
SELECT
    f.item_sk, f.despacho_cifrado, f.item,
    fo.fecha AS fecha_oficializacion, fo.anio, fo.mes_numero, fo.mes_nombre,
    fo.trimestre, fo.anio_mes,
    o.operacion, o.es_importacion, o.es_exportacion,
    des.cod_destinacion, des.descripcion AS destinacion_desc,
    r.regimen, a.aduana,
    po.pais AS pais_origen, pd.pais AS pais_destino,
    pr.posicion_ncm, pr.rubro,
    mt.medio_transporte, c.canal, um.unidad_medida, ac.acuerdo, m.marca,
    f.uso, f.mercaderia,
    f.cantidad_estadistica, f.kilo_neto, f.kilo_bruto,
    f.fob_usd, f.flete_usd, f.seguro_usd,
    f.imponible_usd AS cif_usd, f.imponible_gs,
    f.derecho, f.isc, f.servicio, f.renta, f.iva, f.otros, f.total
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha            fo  ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_operacion        o   ON f.operacion_sk            = o.operacion_sk
JOIN dw.dim_destinacion      des ON f.destinacion_sk          = des.destinacion_sk
JOIN dw.dim_regimen          r   ON f.regimen_sk              = r.regimen_sk
JOIN dw.dim_aduana           a   ON f.aduana_sk               = a.aduana_sk
JOIN dw.dim_pais             po  ON f.pais_origen_sk          = po.pais_sk
JOIN dw.dim_pais             pd  ON f.pais_destino_sk         = pd.pais_sk
JOIN dw.dim_producto         pr  ON f.producto_sk             = pr.producto_sk
JOIN dw.dim_medio_transporte mt  ON f.medio_transporte_sk     = mt.medio_transporte_sk
JOIN dw.dim_canal            c   ON f.canal_sk                = c.canal_sk
JOIN dw.dim_unidad_medida    um  ON f.unidad_medida_sk        = um.unidad_medida_sk
JOIN dw.dim_acuerdo          ac  ON f.acuerdo_sk              = ac.acuerdo_sk
JOIN dw.dim_marca            m   ON f.marca_sk                = m.marca_sk;

-- Evolucion mensual de las medidas economicas (por tipo de operacion).
CREATE OR REPLACE VIEW dw.vw_evolucion_mensual AS
SELECT
    fo.anio, fo.anio_mes, o.operacion,
    count(*)                AS items,
    sum(f.fob_usd)          AS fob_usd,
    sum(f.imponible_usd)    AS cif_usd,
    sum(f.total)            AS tributos_total,
    sum(f.kilo_neto)        AS kilo_neto
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha     fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_operacion o  ON f.operacion_sk            = o.operacion_sk
GROUP BY fo.anio, fo.anio_mes, o.operacion;

-- Importaciones por pais de origen.
CREATE OR REPLACE VIEW dw.vw_importaciones_pais AS
SELECT
    po.pais AS pais_origen,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.fob_usd)       AS fob_usd,
    sum(f.kilo_neto)     AS kilo_neto
FROM dw.fact_aduana_item f
JOIN dw.dim_operacion o  ON f.operacion_sk   = o.operacion_sk
JOIN dw.dim_pais      po ON f.pais_origen_sk = po.pais_sk
WHERE o.es_importacion
GROUP BY po.pais;

-- Ranking de productos (posicion NCM / rubro).
CREATE OR REPLACE VIEW dw.vw_top_productos AS
SELECT
    pr.posicion_ncm, pr.rubro,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.kilo_neto)     AS kilo_neto
FROM dw.fact_aduana_item f
JOIN dw.dim_producto pr ON f.producto_sk = pr.producto_sk
GROUP BY pr.posicion_ncm, pr.rubro;

-- Volumen por aduana.
CREATE OR REPLACE VIEW dw.vw_aduana_volumen AS
SELECT
    a.aduana,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.kilo_bruto)    AS kilo_bruto
FROM dw.fact_aduana_item f
JOIN dw.dim_aduana a ON f.aduana_sk = a.aduana_sk
GROUP BY a.aduana;

-- Relacion CIF vs FOB (sobrecosto logistico = flete + seguro).
CREATE OR REPLACE VIEW dw.vw_cif_vs_fob AS
SELECT
    fo.anio_mes,
    sum(f.fob_usd)                                   AS fob_usd,
    sum(f.imponible_usd)                             AS cif_usd,
    sum(f.flete_usd + f.seguro_usd)                  AS logistica_usd,
    round(sum(f.imponible_usd) / NULLIF(sum(f.fob_usd),0), 4) AS ratio_cif_fob
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha fo ON f.fecha_oficializacion_sk = fo.fecha_sk
GROUP BY fo.anio_mes;
