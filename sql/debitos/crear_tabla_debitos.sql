-- =====================================================
-- Tabla: debitos
-- Descripción: Almacena débitos históricos por agencia/semana
--              Solo débitos por día, sin métricas de cobranza
-- Autor: Sistema
-- Fecha: 2026-01-20
-- =====================================================

CREATE TABLE IF NOT EXISTS debitos (
    -- Identificadores (PRIMARY KEY compuesto)
    agencia VARCHAR(32) NOT NULL,
    semana TINYINT NOT NULL,
    anio YEAR NOT NULL,

    -- Débitos por día de la semana
    debito_miercoles DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    debito_jueves DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    debito_viernes DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    -- Control
    origen ENUM('sp_automatico', 'manual', 'correccion') DEFAULT 'sp_automatico',
    created_at DATETIME NOT NULL DEFAULT (CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')),
    updated_at DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,

    -- Índices
    PRIMARY KEY (agencia, semana, anio),
    INDEX idx_semana_anio (semana, anio)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_general_ci
  COMMENT='Débitos por agencia/semana desglosados por día';

-- =====================================================
-- Comentarios de campos
-- =====================================================

-- agencia: Código de la agencia (ej: AGE068, AGC001)
-- semana/anio: Semana ISO del año (PRIMARY KEY junto con agencia)
-- debito_miercoles: Débito de clientes que pagan los miércoles
-- debito_jueves: Débito de clientes que pagan los jueves
-- debito_viernes: Débito de clientes que pagan los viernes
-- origen: Forma en que se capturó el registro (sp_automatico, manual, correccion)
-- created_at: Fecha/hora de primera captura en zona horaria de Ciudad de México
-- updated_at: Fecha/hora de última actualización (NULL si nunca se actualizó)

-- =====================================================
-- Notas de diseño
-- =====================================================

-- 1. PRIMARY KEY compuesto (agencia, semana, anio) asegura:
--    - Un solo registro por agencia/semana
--    - Búsquedas eficientes sin índice adicional
--    - Menos espacio que un id auto-increment

-- 2. Para obtener la gerencia, hacer JOIN con tabla agencias:
--    SELECT d.*, a.GerenciaID
--    FROM debitos d
--    INNER JOIN agencias a ON d.agencia = a.AgenciaID

-- 3. created_at usa zona horaria de México al momento de inserción
--    updated_at usa CURRENT_TIMESTAMP (UTC) por defecto de MariaDB

-- 4. Estimación de datos:
--    - 352 agencias × 52 semanas = ~18,300 registros/año
--    - Muy eficiente para consultas históricas
