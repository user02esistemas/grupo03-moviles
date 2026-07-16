-- ============================================================================
--  DATOS DE PRUEBA PARA LA DEMO
--  Se ejecuta al final (initdb corre los *.sql en orden alfabetico) y SOLO
--  cuando el volumen esta vacio. Para recargarlo:
--      docker compose down -v && docker compose up --build
--
--  Todas las PK son GENERATED ALWAYS AS IDENTITY, asi que no se fijan a mano:
--  las FK se resuelven por clave natural (nombre_tipo, numero_habitacion, ...).
--  Asi el seed no se rompe si cambia el orden de los INSERT.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. USUARIOS (uno por rol)
-- ----------------------------------------------------------------------------
-- Contrasena de los tres: Demo1234
-- Hash argon2id generado con app/core/security.hash_password y verificado con
-- verify_password. La sal va dentro del hash, por eso los tres pueden
-- compartirlo: solo significa "misma contrasena".
-- Regenerar con:
--   docker compose exec -T api python -c "from app.core.security import hash_password; print(hash_password('Demo1234'))"
INSERT INTO usuario (nombre, apellido, correo, telefono, password_hash, id_rol) VALUES
  ('Ana',   'Torres',  'cliente@demo.com', '987111222',
   '$argon2id$v=19$m=65536,t=3,p=4$RlFfimuXWP3bmtgsJnCXeQ$vOSs+ZEr0XpKt/qZ4fIU2G0zRyMFtjNyn3PA1q7Wbqo', 1),
  ('Luis',  'Ramirez', 'recepcion@demo.com', '987333444',
   '$argon2id$v=19$m=65536,t=3,p=4$RlFfimuXWP3bmtgsJnCXeQ$vOSs+ZEr0XpKt/qZ4fIU2G0zRyMFtjNyn3PA1q7Wbqo', 2),
  ('Marta', 'Vega',    'admin@demo.com', '987555666',
   '$argon2id$v=19$m=65536,t=3,p=4$RlFfimuXWP3bmtgsJnCXeQ$vOSs+ZEr0XpKt/qZ4fIU2G0zRyMFtjNyn3PA1q7Wbqo', 3);

-- ----------------------------------------------------------------------------
-- 2. TIPOS DE HABITACION Y SERVICIOS (M:N)
-- ----------------------------------------------------------------------------
INSERT INTO tipo_habitacion (nombre_tipo, descripcion) VALUES
  ('Simple', 'Habitacion individual con lo esencial'),
  ('Doble',  'Habitacion doble estandar'),
  ('Suite',  'Suite amplia con sala y jacuzzi');

INSERT INTO servicio (nombre, descripcion) VALUES
  ('WiFi',               'Internet inalambrico de alta velocidad'),
  ('TV Cable',           'Television por cable'),
  ('Aire acondicionado', 'Climatizacion regulable'),
  ('Desayuno incluido',  'Desayuno buffet de 7 a 10 am'),
  ('Jacuzzi',            'Jacuzzi privado en la habitacion');

INSERT INTO tipo_habitacion_servicio (id_tipo, id_servicio)
SELECT t.id_tipo, s.id_servicio
FROM tipo_habitacion t
JOIN servicio s ON (
       (t.nombre_tipo = 'Simple' AND s.nombre IN ('WiFi', 'TV Cable'))
    OR (t.nombre_tipo = 'Doble'  AND s.nombre IN ('WiFi', 'TV Cable', 'Aire acondicionado'))
    OR (t.nombre_tipo = 'Suite'  AND s.nombre IN ('WiFi', 'TV Cable', 'Aire acondicionado',
                                                  'Desayuno incluido', 'Jacuzzi'))
);

-- ----------------------------------------------------------------------------
-- 3. HABITACIONES (2 por tipo, para que el filtro por fechas siempre devuelva algo)
-- ----------------------------------------------------------------------------
INSERT INTO habitacion (id_tipo, numero_habitacion, descripcion, precio_noche, capacidad, id_estado_habitacion)
SELECT t.id_tipo, v.numero, v.descripcion, v.precio, v.capacidad, v.estado
FROM (VALUES
    ('Simple', '101', 'Simple con vista interior',  120.00, 1, 1),
    ('Simple', '102', 'Simple con vista a la calle',130.00, 2, 1),
    ('Doble',  '201', 'Doble estandar',             220.00, 2, 1),
    ('Doble',  '202', 'Doble superior con balcon',  250.00, 3, 1),
    ('Suite',  '301', 'Suite presidencial',         480.00, 4, 1),
    ('Suite',  '302', 'Suite familiar',             450.00, 5, 4)  -- 4 = mantenimiento
  ) AS v(tipo, numero, descripcion, precio, capacidad, estado)
JOIN tipo_habitacion t ON t.nombre_tipo = v.tipo
-- El ORDER BY no es decorativo: sin el, el JOIN puede emitir las filas en
-- cualquier orden y los id_habitacion (IDENTITY) no coincidirian con el numero
-- de habitacion. Asi la 101 es la id 1, la 102 la id 2, etc., que es lo que
-- cualquiera espera al probar en Swagger.
ORDER BY v.numero;

-- La 302 queda en mantenimiento a proposito: demuestra que el filtro de
-- disponibilidad excluye las habitaciones no operativas.

-- ----------------------------------------------------------------------------
-- 4. IMAGENES (solo URLs; el esquema no guarda binarios)
-- ----------------------------------------------------------------------------
INSERT INTO habitacion_imagen (id_habitacion, url, orden, es_principal)
SELECT h.id_habitacion, v.url, v.orden, v.principal
FROM (VALUES
    ('101', 'https://picsum.photos/seed/hab101a/800/600', 0, true),
    ('101', 'https://picsum.photos/seed/hab101b/800/600', 1, false),
    ('102', 'https://picsum.photos/seed/hab102a/800/600', 0, true),
    ('201', 'https://picsum.photos/seed/hab201a/800/600', 0, true),
    ('201', 'https://picsum.photos/seed/hab201b/800/600', 1, false),
    ('202', 'https://picsum.photos/seed/hab202a/800/600', 0, true),
    ('301', 'https://picsum.photos/seed/hab301a/800/600', 0, true),
    ('302', 'https://picsum.photos/seed/hab302a/800/600', 0, true)
  ) AS v(numero, url, orden, principal)
JOIN habitacion h ON h.numero_habitacion = v.numero
ORDER BY v.numero, v.orden;

-- ----------------------------------------------------------------------------
-- 5. RESERVAS DE EJEMPLO
-- ----------------------------------------------------------------------------
-- Fechas relativas a CURRENT_DATE para que el dashboard tenga datos el dia de
-- la presentacion, sea cual sea. codigo_reserva sale de la misma secuencia que
-- usara el backend, para que no colisione con las reservas nuevas de la demo.
INSERT INTO reserva (id_usuario, id_habitacion, id_estado_reserva,
                     fecha_ingreso, fecha_salida, cantidad_personas,
                     monto_total, codigo_reserva)
SELECT u.id_usuario, h.id_habitacion, v.estado,
       v.ingreso, v.salida, v.personas,
       h.precio_noche * (v.salida - v.ingreso),   -- noches * precio congelado
       'RSV-' || lpad(nextval('seq_codigo_reserva')::text, 6, '0')
FROM (VALUES
    -- Confirmada, con check-in HOY -> alimenta "checkins_hoy" del dashboard.
    ('201', 2, CURRENT_DATE,                CURRENT_DATE + 2, 2),
    -- Pendiente, a futuro -> se ve en "mis reservas" y en /admin/reservas.
    ('301', 1, CURRENT_DATE + 5,            CURRENT_DATE + 8, 3)
  ) AS v(numero, estado, ingreso, salida, personas)
JOIN habitacion h ON h.numero_habitacion = v.numero
JOIN usuario  u ON u.correo = 'cliente@demo.com';

-- ----------------------------------------------------------------------------
-- 6. PAGO DE EJEMPLO
-- ----------------------------------------------------------------------------
-- Pago aprobado hoy de la reserva confirmada -> "ingresos_hoy" no sale en cero.
INSERT INTO pago (id_reserva, id_metodo_pago, id_estado_pago, monto, fecha_pago, referencia_externa)
SELECT r.id_reserva, 2, 2, r.monto_total, now(), 'FAKE-SEED000001'
FROM reserva r
JOIN habitacion h ON h.id_habitacion = r.id_habitacion
WHERE h.numero_habitacion = '201';

-- ----------------------------------------------------------------------------
-- 7. NOTIFICACIONES DE EJEMPLO
-- ----------------------------------------------------------------------------
INSERT INTO notificacion (id_usuario, id_tipo_notificacion, id_estado_notificacion, mensaje)
SELECT u.id_usuario, v.tipo, v.estado, v.mensaje
FROM (VALUES
    (1, 1, 'Tu reserva de la habitacion 201 fue confirmada'),
    (2, 1, 'Tu pago fue procesado correctamente'),
    (3, 2, 'Aprovecha 20% de descuento en suites este mes')
  ) AS v(tipo, estado, mensaje)
CROSS JOIN usuario u
WHERE u.correo = 'cliente@demo.com';
