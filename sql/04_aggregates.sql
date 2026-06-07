-- ============================================================================
--  04_aggregates.sql  —  Tablas agregadas (vistas materializadas)
--  Pre-calculan resumenes para acelerar Power BI y los analisis frecuentes.
--  Refrescar con:  REFRESH MATERIALIZED VIEW dw.<nombre>;
-- ============================================================================

SET search_path TO dw;

DROP MATERIALIZED VIEW IF EXISTS dw.agg_mensual_operacion;
DROP MATERIALIZED VIEW IF EXISTS dw.agg_pais_mensual;
DROP MATERIALIZED VIEW IF EXISTS dw.agg_producto;
DROP MATERIALIZED VIEW IF EXISTS dw.agg_aduana_mensual;

-- Resumen mensual por tipo de operacion.
CREATE MATERIALIZED VIEW dw.agg_mensual_operacion AS
SELECT
    fo.anio, fo.mes_numero, fo.anio_mes, o.operacion,
    count(*)             AS items,
    sum(f.fob_usd)       AS fob_usd,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.iva)           AS iva,
    sum(f.total)         AS tributos_total,
    sum(f.kilo_neto)     AS kilo_neto
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha     fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_operacion o  ON f.operacion_sk            = o.operacion_sk
GROUP BY fo.anio, fo.mes_numero, fo.anio_mes, o.operacion;

-- Resumen por pais de origen y mes (operacion).
CREATE MATERIALIZED VIEW dw.agg_pais_mensual AS
SELECT
    po.pais AS pais_origen, fo.anio_mes, o.operacion,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.fob_usd)       AS fob_usd
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha     fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_operacion o  ON f.operacion_sk            = o.operacion_sk
JOIN dw.dim_pais      po ON f.pais_origen_sk          = po.pais_sk
GROUP BY po.pais, fo.anio_mes, o.operacion;

-- Resumen por producto (NCM / rubro).
CREATE MATERIALIZED VIEW dw.agg_producto AS
SELECT
    pr.posicion_ncm, pr.rubro,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.kilo_neto)     AS kilo_neto
FROM dw.fact_aduana_item f
JOIN dw.dim_producto pr ON f.producto_sk = pr.producto_sk
GROUP BY pr.posicion_ncm, pr.rubro;

-- Resumen por aduana y mes.
CREATE MATERIALIZED VIEW dw.agg_aduana_mensual AS
SELECT
    a.aduana, fo.anio_mes,
    count(*)             AS items,
    sum(f.imponible_usd) AS cif_usd,
    sum(f.kilo_bruto)    AS kilo_bruto
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha  fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_aduana a  ON f.aduana_sk               = a.aduana_sk
GROUP BY a.aduana, fo.anio_mes;

CREATE INDEX ix_agg_pais_mensual_pais   ON dw.agg_pais_mensual (pais_origen);
CREATE INDEX ix_agg_producto_cif        ON dw.agg_producto (cif_usd DESC);
CREATE INDEX ix_agg_aduana_mensual_mes  ON dw.agg_aduana_mensual (anio_mes);
