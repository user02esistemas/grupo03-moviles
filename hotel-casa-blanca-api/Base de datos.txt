-- ============================================================================
--  SISTEMA DE HOTEL - ESQUEMA POSTGRESQL
--  Normalizado a 3FN | PostgreSQL 14+
--  Incluye: tipos correctos, catalogos (lookup), FKs, indices,
--           CHECKs, triggers de auditoria, validacion de capacidad
--           y restriccion de exclusion anti-overbooking.
-- ============================================================================

-- Recomendado ejecutar dentro de su propio schema (opcional).
-- DROP SCHEMA IF EXISTS hotel CASCADE;
-- CREATE SCHEMA hotel;
-- SET search_path TO hotel, public;

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONES
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext;      -- correo case-insensitive
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- requerido por EXCLUDE (= con &&)

-- ----------------------------------------------------------------------------
-- 2. FUNCIONES AUXILIARES (triggers)
-- ----------------------------------------------------------------------------

-- 2.1 Mantiene updated_at automaticamente
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2.2 Valida que la cantidad de personas no exceda la capacidad de la habitacion
--     (regla de negocio que cruza dos tablas -> no se puede en un CHECK simple)
CREATE OR REPLACE FUNCTION valida_capacidad_reserva()
RETURNS TRIGGER AS $$
DECLARE
  v_capacidad SMALLINT;
BEGIN
  SELECT capacidad INTO v_capacidad
  FROM habitacion
  WHERE id_habitacion = NEW.id_habitacion;

  IF NEW.cantidad_personas > v_capacidad THEN
    RAISE EXCEPTION
      'cantidad_personas (%) excede la capacidad de la habitacion (%)',
      NEW.cantidad_personas, v_capacidad;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. TABLAS DE CATALOGO (lookup)
--    Reemplazan los varchar libres (estado/rol/metodo/tipo) -> 3FN.
--    IDs fijos asignados a mano para que sean deterministas y se puedan
--    referenciar en constraints (p. ej. el EXCLUDE de reserva).
-- ============================================================================

CREATE TABLE rol (
  id_rol  SMALLINT     PRIMARY KEY,
  nombre  VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO rol (id_rol, nombre) VALUES
  (1, 'cliente'),
  (2, 'recepcionista'),
  (3, 'administrador');

CREATE TABLE estado_usuario (
  id_estado_usuario SMALLINT     PRIMARY KEY,
  nombre            VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO estado_usuario (id_estado_usuario, nombre) VALUES
  (1, 'activo'),
  (2, 'inactivo'),
  (3, 'bloqueado');

-- Estado OPERATIVO de la habitacion (recepcion / housekeeping).
-- NO es la disponibilidad por fechas: eso se deriva de las reservas (ver EXCLUDE).
CREATE TABLE estado_habitacion (
  id_estado_habitacion SMALLINT     PRIMARY KEY,
  nombre               VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO estado_habitacion (id_estado_habitacion, nombre) VALUES
  (1, 'disponible'),
  (2, 'ocupada'),
  (3, 'reservada'),
  (4, 'mantenimiento');

CREATE TABLE metodo_pago (
  id_metodo_pago SMALLINT     PRIMARY KEY,
  nombre         VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO metodo_pago (id_metodo_pago, nombre) VALUES
  (1, 'efectivo'),
  (2, 'tarjeta_credito'),
  (3, 'tarjeta_debito'),
  (4, 'transferencia'),
  (5, 'yape_plin');

CREATE TABLE estado_pago (
  id_estado_pago SMALLINT     PRIMARY KEY,
  nombre         VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO estado_pago (id_estado_pago, nombre) VALUES
  (1, 'pendiente'),
  (2, 'pagado'),
  (3, 'rechazado'),
  (4, 'reembolsado');

-- IDs 1 y 2 (pendiente, confirmada) son los que BLOQUEAN fechas en el EXCLUDE.
CREATE TABLE estado_reserva (
  id_estado_reserva SMALLINT     PRIMARY KEY,
  nombre            VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO estado_reserva (id_estado_reserva, nombre) VALUES
  (1, 'pendiente'),
  (2, 'confirmada'),
  (3, 'cancelada'),
  (4, 'completada'),
  (5, 'no_show');

CREATE TABLE tipo_notificacion (
  id_tipo_notificacion SMALLINT     PRIMARY KEY,
  nombre               VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO tipo_notificacion (id_tipo_notificacion, nombre) VALUES
  (1, 'reserva'),
  (2, 'pago'),
  (3, 'promocion'),
  (4, 'sistema');

CREATE TABLE estado_notificacion (
  id_estado_notificacion SMALLINT     PRIMARY KEY,
  nombre                 VARCHAR(30)  NOT NULL UNIQUE
);
INSERT INTO estado_notificacion (id_estado_notificacion, nombre) VALUES
  (1, 'no_leida'),
  (2, 'leida');

-- ============================================================================
-- 4. TABLAS PRINCIPALES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 USUARIO
--     - contrasena -> password_hash (jamas texto plano; usar argon2/bcrypt)
--     - correo CITEXT UNIQUE (case-insensitive) + CHECK de formato
-- ----------------------------------------------------------------------------
CREATE TABLE usuario (
  id_usuario        BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre            VARCHAR(60)  NOT NULL,
  apellido          VARCHAR(60)  NOT NULL,
  correo            CITEXT       NOT NULL UNIQUE,
  telefono          VARCHAR(20),
  password_hash     VARCHAR(255) NOT NULL,
  id_rol            SMALLINT     NOT NULL REFERENCES rol(id_rol),
  id_estado_usuario SMALLINT     NOT NULL DEFAULT 1
                                 REFERENCES estado_usuario(id_estado_usuario),
  fecha_registro    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ,  -- soft delete (trazabilidad)
  CONSTRAINT chk_correo_formato
    CHECK (correo ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);

-- ----------------------------------------------------------------------------
-- 4.2 TIPO DE HABITACION  (servicios sacados a M:N -> 1FN/3FN)
-- ----------------------------------------------------------------------------
CREATE TABLE tipo_habitacion (
  id_tipo     SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_tipo VARCHAR(60)  NOT NULL UNIQUE,
  descripcion TEXT
);

CREATE TABLE servicio (
  id_servicio SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre      VARCHAR(60)  NOT NULL UNIQUE,
  descripcion TEXT
);

-- Tabla puente: que servicios incluye cada tipo de habitacion (M:N)
CREATE TABLE tipo_habitacion_servicio (
  id_tipo     SMALLINT NOT NULL REFERENCES tipo_habitacion(id_tipo) ON DELETE CASCADE,
  id_servicio SMALLINT NOT NULL REFERENCES servicio(id_servicio)    ON DELETE CASCADE,
  PRIMARY KEY (id_tipo, id_servicio)
);

-- ----------------------------------------------------------------------------
-- 4.3 HABITACION
--     - precio_noche NUMERIC(10,2)
--     - id_estado_habitacion = estado OPERATIVO (no la disponibilidad por fecha)
--     - imagen sacada a tabla aparte (1:N)
-- ----------------------------------------------------------------------------
CREATE TABLE habitacion (
  id_habitacion        BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_tipo              SMALLINT      NOT NULL REFERENCES tipo_habitacion(id_tipo)
                                              ON DELETE RESTRICT,
  numero_habitacion    VARCHAR(10)   NOT NULL UNIQUE,
  descripcion          TEXT,
  precio_noche         NUMERIC(10,2) NOT NULL CHECK (precio_noche >= 0),
  capacidad            SMALLINT      NOT NULL CHECK (capacidad > 0),
  id_estado_habitacion SMALLINT      NOT NULL DEFAULT 1
                                     REFERENCES estado_habitacion(id_estado_habitacion),
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE habitacion_imagen (
  id_imagen     BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_habitacion BIGINT       NOT NULL REFERENCES habitacion(id_habitacion)
                                      ON DELETE CASCADE,
  url           VARCHAR(500) NOT NULL,   -- ruta/URL, NO el binario
  orden         SMALLINT     NOT NULL DEFAULT 0,
  es_principal  BOOLEAN      NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4.4 RESERVA
--     - monto_total = snapshot del precio al reservar (dato congelado)
--     - CHECK fecha_salida > fecha_ingreso
--     - EXCLUDE: imposible solapar fechas de la misma habitacion (anti-overbooking)
-- ----------------------------------------------------------------------------
CREATE TABLE reserva (
  id_reserva        BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_usuario        BIGINT        NOT NULL REFERENCES usuario(id_usuario)
                                           ON DELETE RESTRICT,
  id_habitacion     BIGINT        NOT NULL REFERENCES habitacion(id_habitacion)
                                           ON DELETE RESTRICT,
  id_estado_reserva SMALLINT      NOT NULL DEFAULT 1
                                  REFERENCES estado_reserva(id_estado_reserva),
  fecha_reserva     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  fecha_ingreso     DATE          NOT NULL,
  fecha_salida      DATE          NOT NULL,
  cantidad_personas SMALLINT      NOT NULL CHECK (cantidad_personas > 0),
  monto_total       NUMERIC(10,2) NOT NULL CHECK (monto_total >= 0),
  codigo_reserva    VARCHAR(20)   NOT NULL UNIQUE,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ,
  CONSTRAINT chk_fechas_reserva CHECK (fecha_salida > fecha_ingreso),

  -- Anti-overbooking: dos reservas ACTIVAS (1=pendiente, 2=confirmada) de la
  -- misma habitacion no pueden tener rangos de fecha que se solapen.
  -- '[)' = incluye ingreso, excluye salida (el dia de salida queda libre).
  CONSTRAINT reserva_sin_solapamiento
    EXCLUDE USING gist (
      id_habitacion                                  WITH =,
      daterange(fecha_ingreso, fecha_salida, '[)')   WITH &&
    )
    WHERE (id_estado_reserva IN (1, 2))
);

-- ----------------------------------------------------------------------------
-- 4.5 PAGO  (1 reserva puede tener N pagos: anticipo + saldo, reembolsos)
-- ----------------------------------------------------------------------------
CREATE TABLE pago (
  id_pago        BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_reserva     BIGINT        NOT NULL REFERENCES reserva(id_reserva)
                                        ON DELETE RESTRICT,
  id_metodo_pago SMALLINT      NOT NULL REFERENCES metodo_pago(id_metodo_pago),
  id_estado_pago SMALLINT      NOT NULL DEFAULT 1
                               REFERENCES estado_pago(id_estado_pago),
  fecha_pago     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  monto          NUMERIC(10,2) NOT NULL CHECK (monto > 0),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4.6 COMPROBANTE  (1:1 con pago via UNIQUE en id_pago)
-- ----------------------------------------------------------------------------
CREATE TABLE comprobante (
  id_comprobante BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pago        BIGINT       NOT NULL UNIQUE REFERENCES pago(id_pago)
                                              ON DELETE CASCADE,
  url_imagen     VARCHAR(500) NOT NULL,       -- ruta/URL del comprobante
  fecha_subida   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4.7 NOTIFICACION
-- ----------------------------------------------------------------------------
CREATE TABLE notificacion (
  id_notificacion        BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_usuario             BIGINT      NOT NULL REFERENCES usuario(id_usuario)
                                              ON DELETE CASCADE,
  id_tipo_notificacion   SMALLINT    NOT NULL REFERENCES tipo_notificacion(id_tipo_notificacion),
  id_estado_notificacion SMALLINT    NOT NULL DEFAULT 1
                                     REFERENCES estado_notificacion(id_estado_notificacion),
  mensaje                TEXT        NOT NULL,
  fecha_envio            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 5. TRIGGERS
-- ============================================================================

-- 5.1 updated_at en tablas mutables
CREATE TRIGGER trg_usuario_updated
  BEFORE UPDATE ON usuario
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_habitacion_updated
  BEFORE UPDATE ON habitacion
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_reserva_updated
  BEFORE UPDATE ON reserva
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pago_updated
  BEFORE UPDATE ON pago
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5.2 Validacion de capacidad en reserva
CREATE TRIGGER trg_valida_capacidad
  BEFORE INSERT OR UPDATE ON reserva
  FOR EACH ROW EXECUTE FUNCTION valida_capacidad_reserva();

-- ============================================================================
-- 6. INDICES
--    PostgreSQL NO indexa las FK automaticamente -> hay que crearlos.
--    (El EXCLUDE ya crea un indice GIST que sirve para busquedas por fecha.)
-- ============================================================================

-- FKs y busquedas frecuentes
CREATE INDEX idx_habitacion_tipo            ON habitacion(id_tipo);
CREATE INDEX idx_habitacion_estado          ON habitacion(id_estado_habitacion);
CREATE INDEX idx_habitacion_imagen_hab      ON habitacion_imagen(id_habitacion);
CREATE INDEX idx_ths_servicio               ON tipo_habitacion_servicio(id_servicio);

CREATE INDEX idx_reserva_usuario            ON reserva(id_usuario);
CREATE INDEX idx_reserva_habitacion         ON reserva(id_habitacion);
CREATE INDEX idx_reserva_fechas             ON reserva(fecha_ingreso, fecha_salida);
CREATE INDEX idx_reserva_estado             ON reserva(id_estado_reserva);

CREATE INDEX idx_pago_reserva               ON pago(id_reserva);
CREATE INDEX idx_pago_estado                ON pago(id_estado_pago);

CREATE INDEX idx_notif_usuario              ON notificacion(id_usuario);

-- Indices parciales (mas pequenos y rapidos para consultas tipicas)
CREATE INDEX idx_notif_no_leidas
  ON notificacion(id_usuario)
  WHERE id_estado_notificacion = 1;  -- no_leida

CREATE INDEX idx_usuario_activos
  ON usuario(id_usuario)
  WHERE deleted_at IS NULL;

-- Solo UNA imagen principal por habitacion
CREATE UNIQUE INDEX uq_habitacion_imagen_principal
  ON habitacion_imagen(id_habitacion)
  WHERE es_principal;

-- ============================================================================
-- 7. NOTAS DE OPERACION
-- ============================================================================
-- * Crear una reserva debe hacerse dentro de una transaccion:
--     BEGIN;
--       INSERT INTO reserva (...) VALUES (...);   -- el EXCLUDE protege solapamientos
--       INSERT INTO pago (...) VALUES (...);
--     COMMIT;
--   Si otra transaccion intenta solapar fechas, el INSERT falla
--   (error 23P01 exclusion_violation) -> capturarlo y avisar "sin disponibilidad".
--
-- * password_hash: almacenar SOLO el hash (argon2id o bcrypt). Nunca texto plano.
--
-- * Imagenes/comprobantes: en la BD va la URL/ruta; el archivo va en
--   almacenamiento de objetos (S3/MinIO) o filesystem.
--
-- * A futuro, si Reserva/Notificacion crecen mucho, evaluar particionado por fecha.
-- ============================================================================


ALTER TABLE usuario
  ADD COLUMN proveedor VARCHAR(20) NOT NULL DEFAULT 'local',
  ADD COLUMN google_sub VARCHAR(255),
  ALTER COLUMN password_hash DROP NOT NULL;

ALTER TABLE usuario
  ADD CONSTRAINT chk_usuario_proveedor
  CHECK (proveedor IN ('local', 'google'));

ALTER TABLE usuario
  ADD CONSTRAINT chk_usuario_password_hash_no_vacio
  CHECK (
    password_hash IS NULL OR btrim(password_hash) <> ''
  );

ALTER TABLE usuario
  ADD CONSTRAINT chk_usuario_google_sub_no_vacio
  CHECK (
    google_sub IS NULL OR btrim(google_sub) <> ''
  );

ALTER TABLE usuario
  ADD CONSTRAINT chk_usuario_auth_consistente
  CHECK (
    (
      proveedor = 'local'
      AND password_hash IS NOT NULL
      AND google_sub IS NULL
    )
    OR
    (
      proveedor = 'google'
      AND google_sub IS NOT NULL
    )
  );

CREATE UNIQUE INDEX uq_usuario_google_sub
  ON usuario(google_sub)
  WHERE google_sub IS NOT NULL;