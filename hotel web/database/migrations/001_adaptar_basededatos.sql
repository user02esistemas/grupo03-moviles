BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION valida_capacidad_reserva()
RETURNS TRIGGER AS $$
DECLARE
    capacidad_habitacion INTEGER;
BEGIN
    SELECT capacidad INTO capacidad_habitacion
    FROM habitacion
    WHERE id_habitacion = NEW.id_habitacion;

    IF NEW.cantidad_personas > capacidad_habitacion THEN
        RAISE EXCEPTION 'La cantidad de personas (%) excede la capacidad de la habitacion (%)',
            NEW.cantidad_personas, capacidad_habitacion;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE usuario ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

ALTER TABLE tipo_habitacion ADD COLUMN IF NOT EXISTS descripcion VARCHAR(255);
ALTER TABLE tipo_habitacion ADD COLUMN IF NOT EXISTS servicios VARCHAR(255);

DO $$
BEGIN
    IF to_regclass('public.tipohabitacion') IS NOT NULL THEN
        INSERT INTO tipo_habitacion (id_tipo, nombre_tipo, descripcion, servicios)
        SELECT id_tipo, nombre_tipo, descripcion, servicios
        FROM tipohabitacion
        ON CONFLICT (id_tipo) DO UPDATE
        SET nombre_tipo = EXCLUDED.nombre_tipo,
            descripcion = COALESCE(tipo_habitacion.descripcion, EXCLUDED.descripcion),
            servicios = COALESCE(tipo_habitacion.servicios, EXCLUDED.servicios);
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'habitacion_id_tipo_fkey'
          AND conrelid = 'habitacion'::regclass
          AND pg_get_constraintdef(oid) LIKE '%tipohabitacion%'
    ) THEN
        ALTER TABLE habitacion DROP CONSTRAINT habitacion_id_tipo_fkey;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'habitacion_id_tipo_fkey'
          AND conrelid = 'habitacion'::regclass
    ) THEN
        ALTER TABLE habitacion
        ADD CONSTRAINT habitacion_id_tipo_fkey
        FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id_tipo);
    END IF;
END;
$$;

ALTER TABLE habitacion ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE habitacion ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE reserva ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE reserva ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE reserva ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

ALTER TABLE pago ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE pago ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE comprobante ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE notificacion ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

UPDATE usuario
SET rol = CASE WHEN LOWER(rol) = 'admin' THEN 'Admin' ELSE 'Cliente' END
WHERE rol NOT IN ('Cliente', 'Admin');

ALTER TABLE pago ALTER COLUMN estado_pago SET DEFAULT 'Pendiente';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'usuario_rol_check'
          AND conrelid = 'usuario'::regclass
    ) THEN
        ALTER TABLE usuario
        ADD CONSTRAINT usuario_rol_check CHECK (rol IN ('Cliente', 'Admin'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'reserva_fechas_check'
          AND conrelid = 'reserva'::regclass
    ) THEN
        ALTER TABLE reserva
        ADD CONSTRAINT reserva_fechas_check CHECK (fecha_salida > fecha_ingreso);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'reserva_estado_reserva_check'
          AND conrelid = 'reserva'::regclass
    ) THEN
        ALTER TABLE reserva
        ADD CONSTRAINT reserva_estado_reserva_check CHECK (estado_reserva IN ('Pendiente', 'Confirmada', 'Cancelada'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'pago_estado_pago_check'
          AND conrelid = 'pago'::regclass
    ) THEN
        ALTER TABLE pago
        ADD CONSTRAINT pago_estado_pago_check CHECK (estado_pago IN ('Pendiente', 'Completado', 'Rechazado'));
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS servicio (
    id_servicio SERIAL PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL UNIQUE,
    descripcion TEXT
);

CREATE TABLE IF NOT EXISTS tipo_habitacion_servicio (
    id_tipo INTEGER NOT NULL REFERENCES tipo_habitacion(id_tipo) ON DELETE CASCADE,
    id_servicio INTEGER NOT NULL REFERENCES servicio(id_servicio) ON DELETE CASCADE,
    PRIMARY KEY (id_tipo, id_servicio)
);

CREATE TABLE IF NOT EXISTS habitacion_imagen (
    id_imagen SERIAL PRIMARY KEY,
    id_habitacion INTEGER NOT NULL REFERENCES habitacion(id_habitacion) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    orden INTEGER NOT NULL DEFAULT 0,
    es_principal BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO servicio (nombre, descripcion)
VALUES
    ('WiFi', 'Internet inalambrico'),
    ('TV', 'Television en habitacion'),
    ('Bano privado', 'Bano privado con agua caliente'),
    ('Escritorio', 'Espacio de trabajo'),
    ('Minibar', 'Minibar en habitacion'),
    ('Sala de estar', 'Ambiente adicional para descanso')
ON CONFLICT (nombre) DO UPDATE
SET descripcion = EXCLUDED.descripcion;

UPDATE tipo_habitacion
SET descripcion = CASE nombre_tipo
    WHEN 'Simple' THEN COALESCE(descripcion, 'Habitacion acogedora y funcional, ideal para una persona.')
    WHEN 'Doble' THEN COALESCE(descripcion, 'Espacio confortable y amplio, ideal para dos personas.')
    WHEN 'Suite Ejecutiva' THEN COALESCE(descripcion, 'Habitacion premium con mayor espacio y sala de estar.')
    ELSE descripcion
END,
servicios = CASE nombre_tipo
    WHEN 'Simple' THEN 'WiFi, TV, bano privado'
    WHEN 'Doble' THEN 'WiFi, TV, bano privado, escritorio'
    WHEN 'Suite Ejecutiva' THEN 'WiFi, TV, minibar, sala de estar'
    ELSE servicios
END;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', 'Bano privado')
WHERE tipo.nombre_tipo = 'Simple'
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', 'Bano privado', 'Escritorio')
WHERE tipo.nombre_tipo = 'Doble'
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', 'Bano privado', 'Minibar', 'Sala de estar')
WHERE tipo.nombre_tipo = 'Suite Ejecutiva'
ON CONFLICT DO NOTHING;

INSERT INTO habitacion_imagen (id_habitacion, url, orden, es_principal)
SELECT id_habitacion, imagen, 0, true
FROM habitacion
WHERE imagen IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM habitacion_imagen hi
      WHERE hi.id_habitacion = habitacion.id_habitacion
        AND hi.url = habitacion.imagen
  );

CREATE INDEX IF NOT EXISTS idx_habitacion_tipo ON habitacion(id_tipo);
CREATE INDEX IF NOT EXISTS idx_habitacion_disponibilidad ON habitacion(disponibilidad);
CREATE INDEX IF NOT EXISTS idx_habitacion_imagen_habitacion ON habitacion_imagen(id_habitacion);
CREATE INDEX IF NOT EXISTS idx_tipo_habitacion_servicio_servicio ON tipo_habitacion_servicio(id_servicio);
CREATE INDEX IF NOT EXISTS idx_reserva_usuario ON reserva(id_usuario);
CREATE INDEX IF NOT EXISTS idx_reserva_habitacion ON reserva(id_habitacion);
CREATE INDEX IF NOT EXISTS idx_reserva_fechas ON reserva(fecha_ingreso, fecha_salida);
CREATE INDEX IF NOT EXISTS idx_reserva_estado ON reserva(estado_reserva);
CREATE INDEX IF NOT EXISTS idx_pago_reserva ON pago(id_reserva);
CREATE INDEX IF NOT EXISTS idx_pago_estado ON pago(estado_pago);
CREATE INDEX IF NOT EXISTS idx_notificacion_usuario ON notificacion(id_usuario);
CREATE INDEX IF NOT EXISTS idx_notificacion_no_leidas ON notificacion(id_usuario) WHERE estado = 'No leido';
CREATE UNIQUE INDEX IF NOT EXISTS uq_habitacion_imagen_principal
    ON habitacion_imagen(id_habitacion)
    WHERE es_principal;
CREATE UNIQUE INDEX IF NOT EXISTS uq_usuario_correo_lower ON usuario(LOWER(correo));

DROP TRIGGER IF EXISTS trg_usuario_updated ON usuario;
CREATE TRIGGER trg_usuario_updated
    BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_habitacion_updated ON habitacion;
CREATE TRIGGER trg_habitacion_updated
    BEFORE UPDATE ON habitacion
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reserva_updated ON reserva;
CREATE TRIGGER trg_reserva_updated
    BEFORE UPDATE ON reserva
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pago_updated ON pago;
CREATE TRIGGER trg_pago_updated
    BEFORE UPDATE ON pago
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_valida_capacidad ON reserva;
CREATE TRIGGER trg_valida_capacidad
    BEFORE INSERT OR UPDATE ON reserva
    FOR EACH ROW EXECUTE FUNCTION valida_capacidad_reserva();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'reserva_sin_solapamiento'
          AND conrelid = 'reserva'::regclass
    ) THEN
        ALTER TABLE reserva
        ADD CONSTRAINT reserva_sin_solapamiento
        EXCLUDE USING gist (
            id_habitacion WITH =,
            daterange(fecha_ingreso, fecha_salida, '[)') WITH &&
        )
        WHERE (estado_reserva IN ('Pendiente', 'Confirmada'));
    END IF;
END;
$$;

COMMIT;
