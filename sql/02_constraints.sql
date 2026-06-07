-- ============================================================================
--  02_constraints.sql  —  Claves únicas de negocio, foráneas e índices
--  Se ejecuta DESPUÉS de cargar las dimensiones (las FK requieren que existan
--  los valores referidos, incluido el miembro -1 "NO DEFINIDO").
-- ============================================================================

SET search_path TO dw;

-- ----------------------------------------------------------------------------
--  Claves de negocio únicas en dimensiones (garantizan no duplicar miembros)
-- ----------------------------------------------------------------------------
ALTER TABLE dw.dim_operacion        ADD CONSTRAINT uq_operacion        UNIQUE (operacion);
ALTER TABLE dw.dim_destinacion      ADD CONSTRAINT uq_destinacion      UNIQUE (cod_destinacion);
ALTER TABLE dw.dim_regimen          ADD CONSTRAINT uq_regimen          UNIQUE (regimen);
ALTER TABLE dw.dim_aduana           ADD CONSTRAINT uq_aduana           UNIQUE (aduana);
ALTER TABLE dw.dim_pais             ADD CONSTRAINT uq_pais             UNIQUE (pais);
ALTER TABLE dw.dim_producto         ADD CONSTRAINT uq_producto         UNIQUE (posicion_ncm);
ALTER TABLE dw.dim_medio_transporte ADD CONSTRAINT uq_medio_transporte UNIQUE (medio_transporte);
ALTER TABLE dw.dim_canal            ADD CONSTRAINT uq_canal            UNIQUE (canal);
ALTER TABLE dw.dim_unidad_medida    ADD CONSTRAINT uq_unidad_medida    UNIQUE (unidad_medida);
ALTER TABLE dw.dim_acuerdo          ADD CONSTRAINT uq_acuerdo          UNIQUE (acuerdo);
ALTER TABLE dw.dim_marca            ADD CONSTRAINT uq_marca            UNIQUE (marca);

-- ----------------------------------------------------------------------------
--  Claves foráneas — fact_aduana_item → dimensiones
-- ----------------------------------------------------------------------------
ALTER TABLE dw.fact_aduana_item
    ADD CONSTRAINT fk_item_fecha_ofi   FOREIGN KEY (fecha_oficializacion_sk) REFERENCES dw.dim_fecha (fecha_sk),
    ADD CONSTRAINT fk_item_fecha_can   FOREIGN KEY (fecha_cancelacion_sk)    REFERENCES dw.dim_fecha (fecha_sk),
    ADD CONSTRAINT fk_item_operacion   FOREIGN KEY (operacion_sk)            REFERENCES dw.dim_operacion (operacion_sk),
    ADD CONSTRAINT fk_item_destinacion FOREIGN KEY (destinacion_sk)          REFERENCES dw.dim_destinacion (destinacion_sk),
    ADD CONSTRAINT fk_item_regimen     FOREIGN KEY (regimen_sk)              REFERENCES dw.dim_regimen (regimen_sk),
    ADD CONSTRAINT fk_item_aduana      FOREIGN KEY (aduana_sk)               REFERENCES dw.dim_aduana (aduana_sk),
    ADD CONSTRAINT fk_item_pais_ori    FOREIGN KEY (pais_origen_sk)          REFERENCES dw.dim_pais (pais_sk),
    ADD CONSTRAINT fk_item_pais_des    FOREIGN KEY (pais_destino_sk)         REFERENCES dw.dim_pais (pais_sk),
    ADD CONSTRAINT fk_item_producto    FOREIGN KEY (producto_sk)             REFERENCES dw.dim_producto (producto_sk),
    ADD CONSTRAINT fk_item_medio       FOREIGN KEY (medio_transporte_sk)     REFERENCES dw.dim_medio_transporte (medio_transporte_sk),
    ADD CONSTRAINT fk_item_canal       FOREIGN KEY (canal_sk)                REFERENCES dw.dim_canal (canal_sk),
    ADD CONSTRAINT fk_item_unidad      FOREIGN KEY (unidad_medida_sk)        REFERENCES dw.dim_unidad_medida (unidad_medida_sk),
    ADD CONSTRAINT fk_item_acuerdo     FOREIGN KEY (acuerdo_sk)              REFERENCES dw.dim_acuerdo (acuerdo_sk),
    ADD CONSTRAINT fk_item_marca       FOREIGN KEY (marca_sk)                REFERENCES dw.dim_marca (marca_sk);

-- ----------------------------------------------------------------------------
--  Claves foráneas — fact_aduana_subitem → dimensiones
-- ----------------------------------------------------------------------------
ALTER TABLE dw.fact_aduana_subitem
    ADD CONSTRAINT fk_sub_fecha_ofi   FOREIGN KEY (fecha_oficializacion_sk) REFERENCES dw.dim_fecha (fecha_sk),
    ADD CONSTRAINT fk_sub_operacion   FOREIGN KEY (operacion_sk)            REFERENCES dw.dim_operacion (operacion_sk),
    ADD CONSTRAINT fk_sub_destinacion FOREIGN KEY (destinacion_sk)          REFERENCES dw.dim_destinacion (destinacion_sk),
    ADD CONSTRAINT fk_sub_regimen     FOREIGN KEY (regimen_sk)              REFERENCES dw.dim_regimen (regimen_sk),
    ADD CONSTRAINT fk_sub_aduana      FOREIGN KEY (aduana_sk)               REFERENCES dw.dim_aduana (aduana_sk),
    ADD CONSTRAINT fk_sub_pais_ori    FOREIGN KEY (pais_origen_sk)          REFERENCES dw.dim_pais (pais_sk),
    ADD CONSTRAINT fk_sub_pais_des    FOREIGN KEY (pais_destino_sk)         REFERENCES dw.dim_pais (pais_sk),
    ADD CONSTRAINT fk_sub_producto    FOREIGN KEY (producto_sk)             REFERENCES dw.dim_producto (producto_sk),
    ADD CONSTRAINT fk_sub_unidad      FOREIGN KEY (unidad_medida_sk)        REFERENCES dw.dim_unidad_medida (unidad_medida_sk),
    ADD CONSTRAINT fk_sub_acuerdo     FOREIGN KEY (acuerdo_sk)              REFERENCES dw.dim_acuerdo (acuerdo_sk),
    ADD CONSTRAINT fk_sub_marca       FOREIGN KEY (marca_subitem_sk)        REFERENCES dw.dim_marca (marca_sk);

-- ----------------------------------------------------------------------------
--  Índices sobre las claves foráneas (aceleran los JOIN del star schema)
-- ----------------------------------------------------------------------------
CREATE INDEX ix_item_fecha_ofi  ON dw.fact_aduana_item (fecha_oficializacion_sk);
CREATE INDEX ix_item_operacion  ON dw.fact_aduana_item (operacion_sk);
CREATE INDEX ix_item_aduana     ON dw.fact_aduana_item (aduana_sk);
CREATE INDEX ix_item_pais_ori   ON dw.fact_aduana_item (pais_origen_sk);
CREATE INDEX ix_item_producto   ON dw.fact_aduana_item (producto_sk);
CREATE INDEX ix_item_destinacion ON dw.fact_aduana_item (destinacion_sk);
CREATE INDEX ix_item_despacho   ON dw.fact_aduana_item (despacho_cifrado, item);

CREATE INDEX ix_sub_fecha_ofi   ON dw.fact_aduana_subitem (fecha_oficializacion_sk);
CREATE INDEX ix_sub_aduana      ON dw.fact_aduana_subitem (aduana_sk);
CREATE INDEX ix_sub_pais_ori    ON dw.fact_aduana_subitem (pais_origen_sk);
CREATE INDEX ix_sub_producto    ON dw.fact_aduana_subitem (producto_sk);
CREATE INDEX ix_sub_despacho    ON dw.fact_aduana_subitem (despacho_cifrado, item, numero_subitem);
