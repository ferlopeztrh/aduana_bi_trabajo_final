-- ============================================================================
--  01_schema.sql  —  Esquema estrella del Data Warehouse de Aduana (DNIT 2025)
--  Motor: PostgreSQL 16
-- ----------------------------------------------------------------------------
--  Crea: schema dw, tablas de staging, dimensiones y tablas de hechos.
--  Las claves foráneas, índices y restricciones UNIQUE van en 02_constraints.sql.
--
--  Las columnas de texto usan TEXT (los datos reales de la DNIT traen
--  descripciones de longitud muy variable). IDEMPOTENTE: recrea todo.
-- ============================================================================

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

SET search_path TO dw;

-- ============================================================================
--  CAPA STAGING  (datos limpios provenientes de la capa silver del Data Lake)
-- ============================================================================

CREATE TABLE dw.stg_item (
    despacho_cifrado       TEXT,
    operacion              TEXT,
    destinacion            TEXT,
    regimen                TEXT,
    oficializacion         DATE,
    cancelacion            DATE,
    anio                   SMALLINT,
    mes                    TEXT,
    aduana                 TEXT,
    cotizacion             NUMERIC(18,4),
    medio_transporte       TEXT,
    canal                  TEXT,
    item                   INTEGER,
    pais_origen            TEXT,
    pais_destino           TEXT,
    uso                    TEXT,
    unidad_medida          TEXT,
    cantidad_estadistica   NUMERIC(18,3),
    kilo_neto              NUMERIC(18,3),
    kilo_bruto             NUMERIC(18,3),
    fob_usd                NUMERIC(18,2),
    flete_usd              NUMERIC(18,2),
    seguro_usd             NUMERIC(18,2),
    imponible_usd          NUMERIC(18,2),   -- valor CIF
    imponible_gs           NUMERIC(20,2),
    ajuste_incluir         NUMERIC(18,2),
    ajuste_deducir         NUMERIC(18,2),
    posicion               TEXT,            -- código NCM
    rubro                  TEXT,
    desc_capitulo          TEXT,
    desc_partida           TEXT,
    desc_posicion          TEXT,
    mercaderia             TEXT,
    marca_item             TEXT,
    acuerdo                TEXT,
    derecho                NUMERIC(18,2),
    isc                    NUMERIC(18,2),
    servicio               NUMERIC(18,2),
    renta                  NUMERIC(18,2),
    iva                    NUMERIC(18,2),
    otros                  NUMERIC(18,2),
    total                  NUMERIC(18,2)
);

CREATE TABLE dw.stg_subitem (
    despacho_cifrado       TEXT,
    item                   INTEGER,
    numero_subitem         INTEGER,
    operacion              TEXT,
    destinacion            TEXT,
    regimen                TEXT,
    oficializacion         DATE,
    cancelacion            DATE,
    aduana                 TEXT,
    pais_origen            TEXT,
    pais_destino           TEXT,
    posicion               TEXT,
    unidad_medida          TEXT,
    cantidad_subitem       NUMERIC(18,3),
    precio_unitario        NUMERIC(18,4),
    desc_subitem           TEXT,
    marca_subitem          TEXT,
    acuerdo                TEXT
);

-- ============================================================================
--  DIMENSIONES
--  Patrón: clave sustituta (surrogate) IDENTITY + clave de negocio (UNIQUE en 02).
--  Cada dimensión reserva la sk = -1 para el miembro "NO DEFINIDO" (nulos).
-- ============================================================================

-- Dim Fecha — clave inteligente YYYYMMDD (-1 = fecha desconocida)
CREATE TABLE dw.dim_fecha (
    fecha_sk      INTEGER      PRIMARY KEY,   -- formato AAAAMMDD
    fecha         DATE,
    anio          SMALLINT,
    mes_numero    SMALLINT,
    mes_nombre    TEXT,
    trimestre     SMALLINT,
    semestre      SMALLINT,
    anio_mes      CHAR(7),                    -- 'AAAA-MM'
    dia           SMALLINT,
    dia_semana    SMALLINT,                   -- 1=lunes ... 7=domingo
    nombre_dia    TEXT
);

CREATE TABLE dw.dim_operacion (
    operacion_sk     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operacion        TEXT,
    es_importacion   BOOLEAN,
    es_exportacion   BOOLEAN
);

CREATE TABLE dw.dim_destinacion (
    destinacion_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cod_destinacion  TEXT,
    descripcion      TEXT
);

CREATE TABLE dw.dim_regimen (
    regimen_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    regimen      TEXT
);

CREATE TABLE dw.dim_aduana (
    aduana_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aduana      TEXT
);

CREATE TABLE dw.dim_pais (
    pais_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pais      TEXT
);

-- Dim Producto — granularidad por posición NCM (la mercadería de texto libre
-- queda como atributo degenerado en los hechos, para no inflar la dimensión).
CREATE TABLE dw.dim_producto (
    producto_sk    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    posicion_ncm   TEXT,
    rubro          TEXT,
    desc_capitulo  TEXT,
    desc_partida   TEXT,
    desc_posicion  TEXT
);

CREATE TABLE dw.dim_medio_transporte (
    medio_transporte_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medio_transporte      TEXT
);

CREATE TABLE dw.dim_canal (
    canal_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canal      TEXT
);

CREATE TABLE dw.dim_unidad_medida (
    unidad_medida_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unidad_medida      TEXT
);

CREATE TABLE dw.dim_acuerdo (
    acuerdo_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    acuerdo      TEXT
);

CREATE TABLE dw.dim_marca (
    marca_sk   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    marca      TEXT
);

-- ============================================================================
--  TABLAS DE HECHOS
-- ============================================================================

-- Hechos nivel ÍTEM — grano: una línea de ítem por despacho.
CREATE TABLE dw.fact_aduana_item (
    item_sk                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    despacho_cifrado         TEXT,
    item                     INTEGER,
    fecha_oficializacion_sk  INTEGER,
    fecha_cancelacion_sk     INTEGER,
    operacion_sk             INTEGER,
    destinacion_sk           INTEGER,
    regimen_sk               INTEGER,
    aduana_sk                INTEGER,
    pais_origen_sk           INTEGER,
    pais_destino_sk          INTEGER,
    producto_sk              INTEGER,
    medio_transporte_sk      INTEGER,
    canal_sk                 INTEGER,
    unidad_medida_sk         INTEGER,
    acuerdo_sk               INTEGER,
    marca_sk                 INTEGER,
    uso                      TEXT,
    mercaderia               TEXT,
    cotizacion               NUMERIC(18,4),
    cantidad_estadistica     NUMERIC(18,3),
    kilo_neto                NUMERIC(18,3),
    kilo_bruto               NUMERIC(18,3),
    fob_usd                  NUMERIC(18,2),
    flete_usd                NUMERIC(18,2),
    seguro_usd               NUMERIC(18,2),
    imponible_usd            NUMERIC(18,2),   -- CIF
    imponible_gs             NUMERIC(20,2),
    ajuste_incluir           NUMERIC(18,2),
    ajuste_deducir           NUMERIC(18,2),
    derecho                  NUMERIC(18,2),
    isc                      NUMERIC(18,2),
    servicio                 NUMERIC(18,2),
    renta                    NUMERIC(18,2),
    iva                      NUMERIC(18,2),
    otros                    NUMERIC(18,2),
    total                    NUMERIC(18,2)
);

-- Hechos nivel SUBÍTEM — grano: un subítem por (despacho, ítem).
-- Los importes monetarios viven en el grano de ítem; aquí solo medidas del subítem.
CREATE TABLE dw.fact_aduana_subitem (
    subitem_sk               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    despacho_cifrado         TEXT,
    item                     INTEGER,
    numero_subitem           INTEGER,
    fecha_oficializacion_sk  INTEGER,
    operacion_sk             INTEGER,
    destinacion_sk           INTEGER,
    regimen_sk               INTEGER,
    aduana_sk                INTEGER,
    pais_origen_sk           INTEGER,
    pais_destino_sk          INTEGER,
    producto_sk              INTEGER,
    unidad_medida_sk         INTEGER,
    acuerdo_sk               INTEGER,
    marca_subitem_sk         INTEGER,
    desc_subitem             TEXT,
    cantidad_subitem         NUMERIC(18,3),
    precio_unitario          NUMERIC(18,4)
);
