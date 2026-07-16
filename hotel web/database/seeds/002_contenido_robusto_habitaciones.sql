BEGIN;

ALTER TABLE tipo_habitacion ADD COLUMN IF NOT EXISTS descripcion VARCHAR(255);
ALTER TABLE tipo_habitacion ADD COLUMN IF NOT EXISTS servicios VARCHAR(255);

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

DELETE FROM tipo_habitacion_servicio
USING servicio
WHERE tipo_habitacion_servicio.id_servicio = servicio.id_servicio
  AND servicio.nombre IN ('Bano privado', 'Ba?o privado');

DELETE FROM servicio
WHERE nombre IN ('Bano privado', 'Ba?o privado');

INSERT INTO servicio (nombre, descripcion)
VALUES
    ('WiFi', U&'Internet inal\00E1mbrico de alta velocidad'),
    ('TV', U&'Television en habitaci\00F3n'),
    (U&'Ba\00F1o privado', U&'Ba\00F1o privado con agua caliente'),
    ('Escritorio', 'Area de trabajo compacta'),
    ('Minibar', U&'Minibar en habitaci\00F3n'),
    ('Sala de estar', 'Zona adicional para descanso'),
    ('Desayuno incluido', 'Desayuno continental incluido'),
    ('Aire acondicionado', 'Climatizacion independiente'),
    ('Caja fuerte', 'Caja de seguridad para objetos personales'),
    ('Vista interior tranquila', U&'Habitaci\00F3n alejada del ruido exterior'),
    ('Mesa para dos', 'Mesa auxiliar para desayuno o trabajo ligero'),
    ('Espacio familiar', 'Distribucion amplia para grupos o familias'),
    ('Amenities premium', 'Set de cortesia mejorado')
ON CONFLICT (nombre) DO UPDATE
SET descripcion = EXCLUDED.descripcion;

INSERT INTO tipo_habitacion (id_tipo, nombre_tipo, descripcion, servicios)
VALUES
    (1, 'Simple', U&'Ideal para viajes individuales, trabajo breve o estad\00EDas practicas.', U&'WiFi, TV, ba\00F1o privado, escritorio'),
    (2, 'Doble', U&'Pensada para dos hu\00E9spedes que buscan comodidad y buena distribuci\00F3n.', U&'WiFi, TV, ba\00F1o privado, escritorio, desayuno incluido'),
    (3, 'Suite Ejecutiva', 'Ambiente amplio con zona de descanso, detalles premium y mayor privacidad.', 'WiFi, TV, minibar, sala de estar, caja fuerte, amenities premium'),
    (4, 'Matrimonial', U&'Habitaci\00F3n calida para parejas, con cama queen y ambiente tranquilo.', U&'WiFi, TV, ba\00F1o privado, mesa para dos, desayuno incluido'),
    (5, 'Familiar', U&'Opci\00F3n amplia para familias o grupos peque\00F1os, con camas multiples y mayor capacidad.', U&'WiFi, TV, ba\00F1o privado, espacio familiar, aire acondicionado'),
    (6, 'Deluxe King', U&'Habitaci\00F3n superior con cama king, escritorio y acabados mas refinados.', U&'WiFi, TV, ba\00F1o privado, escritorio, caja fuerte, amenities premium'),
    (7, 'Triple', U&'Distribucion practica para tres hu\00E9spedes, ideal para amigos o viajes de trabajo grupales.', U&'WiFi, TV, ba\00F1o privado, vista interior tranquila')
ON CONFLICT (id_tipo) DO UPDATE
SET nombre_tipo = EXCLUDED.nombre_tipo,
    descripcion = EXCLUDED.descripcion,
    servicios = EXCLUDED.servicios;

DO $$
BEGIN
    IF to_regclass('public.tipohabitacion') IS NOT NULL THEN
        INSERT INTO tipohabitacion (id_tipo, nombre_tipo, descripcion, servicios)
        SELECT id_tipo, nombre_tipo, descripcion, servicios
        FROM tipo_habitacion
        WHERE id_tipo IN (1, 2, 3, 4, 5, 6, 7)
        ON CONFLICT (id_tipo) DO UPDATE
        SET nombre_tipo = EXCLUDED.nombre_tipo,
            descripcion = EXCLUDED.descripcion,
            servicios = EXCLUDED.servicios;
    END IF;
END;
$$;

SELECT setval('tipo_habitacion_id_tipo_seq', GREATEST((SELECT MAX(id_tipo) FROM tipo_habitacion), 1), true);

DELETE FROM tipo_habitacion_servicio
WHERE id_tipo IN (1, 2, 3, 4, 5, 6, 7);

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Escritorio')
WHERE tipo.id_tipo = 1
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Escritorio', 'Desayuno incluido')
WHERE tipo.id_tipo = 2
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', 'Minibar', 'Sala de estar', 'Caja fuerte', 'Amenities premium')
WHERE tipo.id_tipo = 3
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Mesa para dos', 'Desayuno incluido')
WHERE tipo.id_tipo = 4
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Espacio familiar', 'Aire acondicionado')
WHERE tipo.id_tipo = 5
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Escritorio', 'Caja fuerte', 'Amenities premium')
WHERE tipo.id_tipo = 6
ON CONFLICT DO NOTHING;

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT tipo.id_tipo, servicio.id_servicio
FROM tipo_habitacion tipo
JOIN servicio ON servicio.nombre IN ('WiFi', 'TV', U&'Ba\00F1o privado', 'Vista interior tranquila')
WHERE tipo.id_tipo = 7
ON CONFLICT DO NOTHING;

INSERT INTO habitacion (id_habitacion, id_tipo, numero_habitacion, descripcion, precio_noche, capacidad, disponibilidad, imagen)
VALUES
    (1, 1, '101', U&'Habitaci\00F3n simple con cama individual, escritorio compacto, ba\00F1o privado y ambiente silencioso para descansar o trabajar.', 55.00, 1, 'Disponible', 'uploads/rooms/habitacion-simple.png'),
    (2, 2, '102', U&'Habitaci\00F3n doble con dos camas, escritorio y buena iluminaci\00F3n natural; practica para dos hu\00E9spedes.', 90.00, 2, 'Disponible', 'uploads/rooms/habitacion-doble.png'),
    (3, 3, '201', U&'Suite ejecutiva con cama amplia, sala de estar, minibar y detalles premium para una estad\00EDa mas completa.', 165.00, 4, 'Disponible', 'uploads/rooms/suite-ejecutiva.png'),
    (4, 4, '202', U&'Habitaci\00F3n matrimonial con cama queen, mesa para dos y atmosfera calida para una estad\00EDa tranquila.', 115.00, 2, 'Disponible', 'uploads/rooms/habitacion-matrimonial.png'),
    (5, 5, '301', U&'Habitaci\00F3n familiar con cama queen y dos camas individuales; ideal para familias o grupos peque\00F1os.', 190.00, 4, 'Disponible', 'uploads/rooms/habitacion-familiar.png'),
    (6, 6, '302', 'Deluxe King con cama king, escritorio, caja fuerte y amenities premium para mayor comodidad.', 145.00, 2, 'Disponible', 'uploads/rooms/habitacion-deluxe-king.png'),
    (7, 7, '103', U&'Habitaci\00F3n triple con tres camas individuales, ba\00F1o privado y distribuci\00F3n eficiente para grupos.', 130.00, 3, 'Disponible', 'uploads/rooms/habitacion-triple.png')
ON CONFLICT (id_habitacion) DO UPDATE
SET id_tipo = EXCLUDED.id_tipo,
    numero_habitacion = EXCLUDED.numero_habitacion,
    descripcion = EXCLUDED.descripcion,
    precio_noche = EXCLUDED.precio_noche,
    capacidad = EXCLUDED.capacidad,
    disponibilidad = EXCLUDED.disponibilidad,
    imagen = EXCLUDED.imagen;

SELECT setval('habitacion_id_habitacion_seq', GREATEST((SELECT MAX(id_habitacion) FROM habitacion), 1), true);

CREATE UNIQUE INDEX IF NOT EXISTS uq_habitacion_imagen_principal
    ON habitacion_imagen(id_habitacion)
    WHERE es_principal;

INSERT INTO habitacion_imagen (id_habitacion, url, orden, es_principal)
SELECT h.id_habitacion, h.imagen, 0, true
FROM habitacion h
WHERE h.imagen IS NOT NULL
ON CONFLICT DO NOTHING;

COMMIT;



