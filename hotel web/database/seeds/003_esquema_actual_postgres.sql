-- Semilla compatible con el esquema normalizado que esta activo en hotel_postgres/hotel_db.
-- No borra datos: actualiza catalogos por nombre/numero y evita duplicar imagenes.

INSERT INTO tipo_habitacion (nombre_tipo, descripcion)
VALUES
    ('Simple', 'Habitacion privada y funcional para una persona.'),
    ('Doble', 'Habitacion amplia para dos huespedes con ambiente de descanso.'),
    ('Matrimonial', 'Espacio calido para parejas con cama matrimonial.'),
    ('Triple', 'Habitacion practica para grupos pequenos o familias.'),
    ('Familiar', 'Ambiente amplio pensado para estancias familiares.'),
    ('Deluxe King', 'Habitacion premium con cama king y mayor confort.'),
    ('Suite Ejecutiva', 'Suite con zona de estar, escritorio y acabados superiores.')
ON CONFLICT (nombre_tipo) DO UPDATE
SET descripcion = EXCLUDED.descripcion;

INSERT INTO servicio (nombre, descripcion)
VALUES
    ('WiFi', 'Internet inalambrico en la habitacion.'),
    ('TV cable', 'Television con canales por cable.'),
    ('Bano privado', 'Bano privado con ducha.'),
    ('Agua caliente', 'Agua caliente disponible.'),
    ('Escritorio', 'Area de trabajo dentro de la habitacion.'),
    ('Minibar', 'Minibar para bebidas y snacks.'),
    ('Aire acondicionado', 'Climatizacion de la habitacion.'),
    ('Sala de estar', 'Ambiente adicional para descanso.'),
    ('Desayuno', 'Desayuno incluido segun tarifa.'),
    ('Vista interior', 'Habitacion con vista interior tranquila.')
ON CONFLICT (nombre) DO UPDATE
SET descripcion = EXCLUDED.descripcion;

WITH pares(tipo, servicio) AS (
    VALUES
        ('Simple', 'WiFi'),
        ('Simple', 'TV cable'),
        ('Simple', 'Bano privado'),
        ('Simple', 'Agua caliente'),
        ('Doble', 'WiFi'),
        ('Doble', 'TV cable'),
        ('Doble', 'Bano privado'),
        ('Doble', 'Escritorio'),
        ('Matrimonial', 'WiFi'),
        ('Matrimonial', 'TV cable'),
        ('Matrimonial', 'Bano privado'),
        ('Matrimonial', 'Vista interior'),
        ('Triple', 'WiFi'),
        ('Triple', 'TV cable'),
        ('Triple', 'Bano privado'),
        ('Triple', 'Agua caliente'),
        ('Familiar', 'WiFi'),
        ('Familiar', 'TV cable'),
        ('Familiar', 'Bano privado'),
        ('Familiar', 'Desayuno'),
        ('Deluxe King', 'WiFi'),
        ('Deluxe King', 'TV cable'),
        ('Deluxe King', 'Aire acondicionado'),
        ('Deluxe King', 'Minibar'),
        ('Suite Ejecutiva', 'WiFi'),
        ('Suite Ejecutiva', 'TV cable'),
        ('Suite Ejecutiva', 'Sala de estar'),
        ('Suite Ejecutiva', 'Escritorio'),
        ('Suite Ejecutiva', 'Minibar')
)
INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT th.id_tipo, s.id_servicio
FROM pares p
JOIN tipo_habitacion th ON th.nombre_tipo = p.tipo
JOIN servicio s ON s.nombre = p.servicio
ON CONFLICT DO NOTHING;

WITH habitaciones(numero, tipo, descripcion, precio, capacidad) AS (
    VALUES
        ('101', 'Simple', 'Ambiente privado y funcional para estadias cortas.', 70.00, 1),
        ('102', 'Doble', 'Habitacion doble luminosa con espacio de trabajo.', 110.00, 2),
        ('103', 'Matrimonial', 'Habitacion matrimonial con detalles calidos y descanso silencioso.', 130.00, 2),
        ('201', 'Triple', 'Habitacion triple comoda para compartir sin perder privacidad.', 155.00, 3),
        ('202', 'Familiar', 'Habitacion familiar amplia para descansar juntos.', 190.00, 4),
        ('301', 'Deluxe King', 'Habitacion deluxe con cama king, minibar y aire acondicionado.', 220.00, 2),
        ('401', 'Suite Ejecutiva', 'Suite amplia con sala de estar y escritorio ejecutivo.', 280.00, 4)
)
INSERT INTO habitacion (
    id_tipo,
    numero_habitacion,
    descripcion,
    precio_noche,
    capacidad,
    id_estado_habitacion
)
SELECT
    th.id_tipo,
    h.numero,
    h.descripcion,
    h.precio,
    h.capacidad,
    eh.id_estado_habitacion
FROM habitaciones h
JOIN tipo_habitacion th ON th.nombre_tipo = h.tipo
JOIN estado_habitacion eh ON eh.nombre = 'disponible'
ON CONFLICT (numero_habitacion) DO UPDATE
SET id_tipo = EXCLUDED.id_tipo,
    descripcion = EXCLUDED.descripcion,
    precio_noche = EXCLUDED.precio_noche,
    capacidad = EXCLUDED.capacidad,
    id_estado_habitacion = EXCLUDED.id_estado_habitacion;

WITH imagenes(numero, url, orden) AS (
    VALUES
        ('101', 'uploads/rooms/habitacion-simple.png', 1),
        ('102', 'uploads/rooms/habitacion-doble.png', 1),
        ('103', 'uploads/rooms/habitacion-matrimonial.png', 1),
        ('201', 'uploads/rooms/habitacion-triple.png', 1),
        ('202', 'uploads/rooms/habitacion-familiar.png', 1),
        ('301', 'uploads/rooms/habitacion-deluxe-king.png', 1),
        ('401', 'uploads/rooms/suite-ejecutiva.png', 1)
)
INSERT INTO habitacion_imagen (id_habitacion, url, orden, es_principal)
SELECT h.id_habitacion, i.url, i.orden, TRUE
FROM imagenes i
JOIN habitacion h ON h.numero_habitacion = i.numero
WHERE NOT EXISTS (
    SELECT 1
    FROM habitacion_imagen hi
    WHERE hi.id_habitacion = h.id_habitacion
      AND hi.url = i.url
);

INSERT INTO usuario (
    nombre,
    apellido,
    correo,
    telefono,
    password_hash,
    id_rol,
    id_estado_usuario,
    proveedor
)
SELECT
    'Administrador',
    'Casa Blanca',
    'admin@casablanca.com',
    '999999999',
    '$2b$10$lxGyhZYNLPZU4FeGb1T4gOi0cCmuqIoXfMR32FqmASJtdIPW5jnLy',
    r.id_rol,
    eu.id_estado_usuario,
    'local'
FROM rol r
JOIN estado_usuario eu ON eu.nombre = 'activo'
WHERE r.nombre = 'administrador'
ON CONFLICT (correo) DO NOTHING;
