-- ============================================================================
--  consultas_olap.sql  —  20 analisis obligatorios (consigna seccion 4)
--  5 temporales + 5 geograficos + 5 por producto + 5 operativos.
--  Cubre tambien las 5 preguntas de ejemplo de la consigna (seccion 5).
-- ============================================================================

SET search_path TO dw;

-- ============================  TEMPORALES  ==================================

-- T1. Evolucion mensual del valor CIF importado (2025).
SELECT anio_mes, round(cif_usd/1e6,2) AS cif_millones
FROM dw.vw_evolucion_mensual
WHERE operacion = 'IMPORTACION' AND anio = 2025
ORDER BY anio_mes;

-- T2. Valor CIF importado por trimestre (2025).
SELECT fo.trimestre, round(sum(f.imponible_usd)/1e6,2) AS cif_millones
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_operacion o ON f.operacion_sk = o.operacion_sk
WHERE o.es_importacion AND fo.anio = 2025
GROUP BY fo.trimestre ORDER BY fo.trimestre;

-- T3. Mes con mayor y menor importacion (2025).
(SELECT anio_mes, round(cif_usd/1e6,2) AS cif_millones, 'MAXIMO' AS tipo
 FROM dw.vw_evolucion_mensual WHERE operacion='IMPORTACION' AND anio=2025
 ORDER BY cif_usd DESC LIMIT 1)
UNION ALL
(SELECT anio_mes, round(cif_usd/1e6,2), 'MINIMO'
 FROM dw.vw_evolucion_mensual WHERE operacion='IMPORTACION' AND anio=2025
 ORDER BY cif_usd ASC LIMIT 1);

-- T4. Cantidad de items (despachos) por mes y operacion (2025).
SELECT anio_mes, operacion, items
FROM dw.vw_evolucion_mensual
WHERE anio = 2025
ORDER BY anio_mes, operacion;

-- T5. Tiempo promedio (dias) entre oficializacion y cancelacion.
SELECT round(avg(fc.fecha - fo.fecha), 1) AS dias_promedio
FROM dw.fact_aduana_item f
JOIN dw.dim_fecha fo ON f.fecha_oficializacion_sk = fo.fecha_sk
JOIN dw.dim_fecha fc ON f.fecha_cancelacion_sk    = fc.fecha_sk
WHERE fo.fecha_sk <> -1 AND fc.fecha_sk <> -1;

-- ============================  GEOGRAFICOS  =================================

-- G1. Top 10 paises de origen por valor CIF importado.  [pregunta de ejemplo 1]
SELECT pais_origen, round(cif_usd/1e6,2) AS cif_millones, items
FROM dw.vw_importaciones_pais
ORDER BY cif_usd DESC LIMIT 10;

-- G2. Top 10 paises de destino por valor FOB exportado.
SELECT pd.pais AS pais_destino, round(sum(f.fob_usd)/1e6,2) AS fob_millones, count(*) AS items
FROM dw.fact_aduana_item f
JOIN dw.dim_operacion o ON f.operacion_sk = o.operacion_sk
JOIN dw.dim_pais pd ON f.pais_destino_sk = pd.pais_sk
WHERE o.es_exportacion
GROUP BY pd.pais ORDER BY 2 DESC LIMIT 10;

-- G3. Participacion porcentual de cada pais en la importacion (top 10).
SELECT pais_origen,
       round(100.0 * cif_usd / sum(cif_usd) OVER (), 2) AS participacion_pct
FROM dw.vw_importaciones_pais
ORDER BY cif_usd DESC LIMIT 10;

-- G4. Evolucion mensual de los 5 principales paises importadores.
WITH top5 AS (
    SELECT pais_origen FROM dw.vw_importaciones_pais ORDER BY cif_usd DESC LIMIT 5
)
SELECT a.anio_mes, a.pais_origen, round(a.cif_usd/1e6,2) AS cif_millones
FROM dw.agg_pais_mensual a
JOIN top5 t ON a.pais_origen = t.pais_origen
WHERE a.operacion = 'IMPORTACION'
ORDER BY a.pais_origen, a.anio_mes;

-- G5. Ticket promedio (CIF por item) por pais, minimo 1000 items.
SELECT pais_origen, items, round(cif_usd/items, 2) AS cif_promedio_item
FROM dw.vw_importaciones_pais
WHERE items >= 1000
ORDER BY cif_promedio_item DESC LIMIT 10;

-- ============================  POR PRODUCTO  ================================

-- P1. Top 10 posiciones NCM por valor CIF.  [pregunta de ejemplo 2]
SELECT posicion_ncm, rubro, round(cif_usd/1e6,2) AS cif_millones
FROM dw.agg_producto
ORDER BY cif_usd DESC LIMIT 10;

-- P2. Top 10 rubros por valor CIF.
SELECT rubro, round(sum(cif_usd)/1e6,2) AS cif_millones, sum(items) AS items
FROM dw.agg_producto
GROUP BY rubro ORDER BY 2 DESC LIMIT 10;

-- P3. Top 10 productos por peso neto (toneladas).
SELECT posicion_ncm, rubro, round(kilo_neto/1000,1) AS toneladas
FROM dw.agg_producto
ORDER BY kilo_neto DESC LIMIT 10;

-- P4. Precio implicito (USD por kilo) por rubro (top 10, peso > 1000 kg).
SELECT rubro,
       round(sum(cif_usd) / NULLIF(sum(kilo_neto),0), 2) AS usd_por_kilo
FROM dw.agg_producto
GROUP BY rubro
HAVING sum(kilo_neto) > 1000
ORDER BY usd_por_kilo DESC LIMIT 10;

-- P5. Productos mas frecuentes (cantidad de items).
SELECT posicion_ncm, rubro, items
FROM dw.agg_producto
ORDER BY items DESC LIMIT 10;

-- ============================  OPERATIVOS  ==================================

-- O1. Importacion vs Exportacion (totales).
SELECT o.operacion,
       count(*)                  AS items,
       round(sum(f.fob_usd)/1e6,2)       AS fob_millones,
       round(sum(f.imponible_usd)/1e6,2) AS cif_millones
FROM dw.fact_aduana_item f
JOIN dw.dim_operacion o ON f.operacion_sk = o.operacion_sk
GROUP BY o.operacion ORDER BY 2 DESC;

-- O2. Top 10 aduanas por volumen.  [pregunta de ejemplo 4]
SELECT aduana, items, round(cif_usd/1e6,2) AS cif_millones
FROM dw.vw_aduana_volumen
ORDER BY items DESC LIMIT 10;

-- O3. Distribucion por canal (rojo/verde/etc.).
SELECT c.canal, count(*) AS items, round(sum(f.imponible_usd)/1e6,2) AS cif_millones
FROM dw.fact_aduana_item f
JOIN dw.dim_canal c ON f.canal_sk = c.canal_sk
GROUP BY c.canal ORDER BY items DESC;

-- O4. Distribucion por medio de transporte.
SELECT mt.medio_transporte, count(*) AS items,
       round(sum(f.kilo_bruto)/1e6,1) AS kilo_bruto_millones
FROM dw.fact_aduana_item f
JOIN dw.dim_medio_transporte mt ON f.medio_transporte_sk = mt.medio_transporte_sk
GROUP BY mt.medio_transporte ORDER BY items DESC;

-- O5. Relacion CIF/FOB y costo logistico mensual.  [pregunta de ejemplo 5]
SELECT anio_mes,
       round(fob_usd/1e6,2)        AS fob_millones,
       round(cif_usd/1e6,2)        AS cif_millones,
       round(logistica_usd/1e6,2)  AS logistica_millones,
       ratio_cif_fob
FROM dw.vw_cif_vs_fob
ORDER BY anio_mes;

-- ====================  NIVEL SUBITEM (fact_aduana_subitem)  =================
-- La consigna exige usar ambas tablas de hechos; estos analisis explotan el detalle.

-- S1. Promedio de subitems por item (granularidad del detalle).
SELECT round(count(*)::numeric / count(DISTINCT (despacho_cifrado, item)), 2) AS subitems_por_item
FROM dw.fact_aduana_subitem;

-- S2. Top 10 productos por cantidad total a nivel subitem.
SELECT pr.posicion_ncm, pr.rubro,
       round(sum(s.cantidad_subitem),0) AS cantidad_total,
       count(*) AS subitems
FROM dw.fact_aduana_subitem s
JOIN dw.dim_producto pr ON s.producto_sk = pr.producto_sk
GROUP BY pr.posicion_ncm, pr.rubro
ORDER BY cantidad_total DESC LIMIT 10;

-- S3. Top 10 subitems por precio unitario (USD).
SELECT s.despacho_cifrado, s.item, s.numero_subitem,
       left(s.desc_subitem, 50) AS descripcion, s.precio_unitario
FROM dw.fact_aduana_subitem s
WHERE s.precio_unitario IS NOT NULL
ORDER BY s.precio_unitario DESC LIMIT 10;

-- S4. Marcas con mayor cantidad de subitems.
SELECT m.marca, count(*) AS subitems
FROM dw.fact_aduana_subitem s
JOIN dw.dim_marca m ON s.marca_subitem_sk = m.marca_sk
WHERE m.marca <> 'NO DEFINIDO'
GROUP BY m.marca ORDER BY subitems DESC LIMIT 10;
