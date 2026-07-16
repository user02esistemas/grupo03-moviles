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

CREATE TABLE IF NOT EXISTS usuario (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    telefono VARCHAR(30),
    contrasena_hash VARCHAR(255) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'Activo',
    rol VARCHAR(20) NOT NULL DEFAULT 'Cliente' CHECK (rol IN ('Cliente', 'Admin')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tipo_habitacion (
    id_tipo SERIAL PRIMARY KEY,
    nombre_tipo VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    servicios VARCHAR(255)
);

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

CREATE TABLE IF NOT EXISTS habitacion (
    id_habitacion SERIAL PRIMARY KEY,
    id_tipo INTEGER REFERENCES tipo_habitacion(id_tipo),
    numero_habitacion VARCHAR(20) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    precio_noche NUMERIC(10, 2) NOT NULL CHECK (precio_noche > 0),
    capacidad INTEGER NOT NULL CHECK (capacidad > 0),
    disponibilidad VARCHAR(20) DEFAULT 'Disponible',
    imagen VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS habitacion_imagen (
    id_imagen SERIAL PRIMARY KEY,
    id_habitacion INTEGER NOT NULL REFERENCES habitacion(id_habitacion) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    orden INTEGER NOT NULL DEFAULT 0,
    es_principal BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reserva (
    id_reserva SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuario(id_usuario),
    id_habitacion INTEGER REFERENCES habitacion(id_habitacion),
    fecha_reserva TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ingreso DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    cantidad_personas INTEGER NOT NULL CHECK (cantidad_personas > 0),
    monto_total NUMERIC(10, 2) NOT NULL CHECK (monto_total >= 0),
    codigo_reserva VARCHAR(30) UNIQUE,
    estado_reserva VARCHAR(20) DEFAULT 'Pendiente' CHECK (estado_reserva IN ('Pendiente', 'Confirmada', 'Cancelada')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    CHECK (fecha_salida > fecha_ingreso),
    CONSTRAINT reserva_sin_solapamiento
        EXCLUDE USING gist (
            id_habitacion WITH =,
            daterange(fecha_ingreso, fecha_salida, '[)') WITH &&
        )
        WHERE (estado_reserva IN ('Pendiente', 'Confirmada'))
);

CREATE TABLE IF NOT EXISTS pago (
    id_pago SERIAL PRIMARY KEY,
    id_reserva INTEGER UNIQUE REFERENCES reserva(id_reserva),
    fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    monto NUMERIC(10, 2) NOT NULL CHECK (monto >= 0),
    metodo_pago VARCHAR(100),
    estado_pago VARCHAR(20) DEFAULT 'Pendiente' CHECK (estado_pago IN ('Pendiente', 'Completado', 'Rechazado')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS comprobante (
    id_comprobante SERIAL PRIMARY KEY,
    id_pago INTEGER UNIQUE REFERENCES pago(id_pago),
    imagen VARCHAR(255) NOT NULL,
    fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notificacion (
    id_notificacion SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuario(id_usuario),
    mensaje VARCHAR(255) NOT NULL,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo VARCHAR(50),
    estado VARCHAR(20) DEFAULT 'No leido',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TRIGGER trg_valida_capacidad
    BEFORE INSERT OR UPDATE ON reserva
    FOR EACH ROW EXECUTE FUNCTION valida_capacidad_reserva();

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

INSERT INTO tipo_habitacion (id_tipo, nombre_tipo, descripcion, servicios)
VALUES
    (1, 'Simple', 'Habitacion acogedora y funcional, ideal para una persona.', 'WiFi, TV, bano privado'),
    (2, 'Doble', 'Espacio confortable y amplio, ideal para dos personas.', 'WiFi, TV, bano privado, escritorio'),
    (3, 'Suite Ejecutiva', 'Habitacion premium con mayor espacio y sala de estar.', 'WiFi, TV, minibar, sala de estar')
ON CONFLICT (id_tipo) DO UPDATE
SET nombre_tipo = EXCLUDED.nombre_tipo,
    descripcion = EXCLUDED.descripcion,
    servicios = EXCLUDED.servicios;

SELECT setval('tipo_habitacion_id_tipo_seq', GREATEST((SELECT MAX(id_tipo) FROM tipo_habitacion), 1), true);

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

INSERT INTO habitacion (id_habitacion, id_tipo, numero_habitacion, descripcion, precio_noche, capacidad, disponibilidad, imagen)
VALUES
    (1, 1, '101', 'Ambiente privado y funcional para estadias cortas.', 50.00, 1, 'Disponible', NULL),
    (2, 2, '102', 'Habitacion doble luminosa con espacio de trabajo.', 85.00, 2, 'Disponible', NULL),
    (3, 3, '201', 'Suite amplia para descansar con mayor comodidad.', 150.00, 4, 'Disponible', NULL)
ON CONFLICT (id_habitacion) DO NOTHING;

SELECT setval('habitacion_id_habitacion_seq', GREATEST((SELECT MAX(id_habitacion) FROM habitacion), 1), true);

INSERT INTO usuario (nombre, apellido, correo, telefono, contrasena_hash, rol)
VALUES (
    'Administrador',
    'Casa Blanca',
    'admin@casablanca.com',
    '999999999',
    '$2b$10$lxGyhZYNLPZU4FeGb1T4gOi0cCmuqIoXfMR32FqmASJtdIPW5jnLy',
    'Admin'
)
ON CONFLICT (correo) DO NOTHING;
