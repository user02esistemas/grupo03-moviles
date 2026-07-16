const crypto = require('crypto');
const bcrypt = require('bcrypt');
const db = require('../db');
const { sincronizarEstadosHabitacion } = require('./habitacionController');

const ESTADOS_RESERVA = ['pendiente', 'confirmada', 'cancelada', 'completada', 'no_show'];

const esFechaValida = (fecha) => /^\d{4}-\d{2}-\d{2}$/.test(String(fecha || ''));

const fechaUtc = (fecha) => {
    const [anio, mes, dia] = fecha.split('-').map(Number);
    return Date.UTC(anio, mes - 1, dia);
};

const hoyUtc = () => {
    const hoy = new Date();
    return Date.UTC(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
};

const diasEntre = (inicio, fin) => Math.ceil((fechaUtc(fin) - fechaUtc(inicio)) / 86400000);

const crearCodigoReserva = () => `CB-${crypto.randomInt(10000, 100000)}`;

const limpiarTexto = (valor) => (typeof valor === 'string' ? valor.trim() : '');
const normalizarCorreo = (correo) => limpiarTexto(correo).toLowerCase();
const regexCorreo = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const regexTelefono = /^[0-9+()\-\s]{7,20}$/;

const normalizarEstado = (estado) => String(estado || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '_');

const estadoLegibleSql = (alias) => `INITCAP(REPLACE(${alias}.nombre, '_', ' '))`;

const pagoLegibleSql = `
    CASE ep.nombre
        WHEN 'pagado' THEN 'Completado'
        ELSE INITCAP(REPLACE(ep.nombre, '_', ' '))
    END
`;

const metodoLegibleSql = `
    CASE mp.nombre
        WHEN 'yape_plin' THEN 'Yape/Plin'
        WHEN 'tarjeta_credito' THEN 'Tarjeta de credito'
        WHEN 'tarjeta_debito' THEN 'Tarjeta de debito'
        ELSE INITCAP(REPLACE(mp.nombre, '_', ' '))
    END
`;

const buscarUsuarioPorCorreo = async (client, correo) => {
    const result = await client.query(
        `SELECT id_usuario
         FROM usuario
         WHERE LOWER(correo::text) = $1
           AND deleted_at IS NULL
         LIMIT 1`,
        [correo]
    );
    return result.rows[0]?.id_usuario;
};

const obtenerOCrearCliente = async (client, datos) => {
    const idUsuario = Number(datos.id_usuario);
    if (Number.isInteger(idUsuario) && idUsuario > 0) {
        const existe = await client.query(
            `SELECT id_usuario
             FROM usuario
             WHERE id_usuario = $1
               AND deleted_at IS NULL`,
            [idUsuario]
        );
        if (existe.rows.length === 0) {
            throw new Error('El cliente seleccionado no existe.');
        }
        return idUsuario;
    }

    const nombre = limpiarTexto(datos.nombre);
    const apellido = limpiarTexto(datos.apellido);
    const correo = normalizarCorreo(datos.correo);
    const telefono = limpiarTexto(datos.telefono);

    if (!nombre || !apellido || !correo || !telefono) {
        throw new Error('Para registrar una reserva admin, envia nombre, apellido, correo y telefono del cliente.');
    }

    if (!regexCorreo.test(correo)) {
        throw new Error('El formato de correo electronico del cliente no es valido.');
    }

    if (!regexTelefono.test(telefono)) {
        throw new Error('El telefono del cliente debe tener entre 7 y 20 caracteres validos.');
    }

    const usuarioExistente = await buscarUsuarioPorCorreo(client, correo);
    if (usuarioExistente) return usuarioExistente;

    const hashTemporal = await bcrypt.hash(`Reserva-${crypto.randomUUID()}`, 10);
    const result = await client.query(
        `INSERT INTO usuario (nombre, apellido, correo, telefono, password_hash, id_rol, proveedor)
         VALUES (
            $1,
            $2,
            $3,
            $4,
            $5,
            (SELECT id_rol FROM rol WHERE nombre = 'cliente' LIMIT 1),
            'local'
         )
         RETURNING id_usuario`,
        [nombre, apellido, correo, telefono, hashTemporal]
    );

    return result.rows[0].id_usuario;
};

const crearReservaParaUsuario = async ({
    client,
    idUsuario,
    idHabitacion,
    fechaIngreso,
    fechaSalida,
    cantidadPersonas,
    estadoInicial = 'pendiente',
}) => {
    const habResult = await client.query(
        `SELECT h.id_habitacion, h.precio_noche, h.capacidad, eh.nombre AS estado_habitacion
         FROM habitacion h
         JOIN estado_habitacion eh ON h.id_estado_habitacion = eh.id_estado_habitacion
         WHERE h.id_habitacion = $1
           AND LOWER(eh.nombre) <> 'mantenimiento'
         FOR UPDATE`,
        [idHabitacion]
    );

    if (habResult.rows.length === 0) {
        const error = new Error('La habitacion seleccionada no existe o se encuentra en mantenimiento.');
        error.status = 404;
        throw error;
    }

    const habitacion = habResult.rows[0];
    if (cantidadPersonas > Number(habitacion.capacidad)) {
        const error = new Error(`Esta habitacion permite maximo ${habitacion.capacidad} personas.`);
        error.status = 400;
        throw error;
    }

    const cruce = await client.query(
        `SELECT r.id_reserva
         FROM reserva r
         JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
         WHERE r.id_habitacion = $1
           AND r.deleted_at IS NULL
           AND LOWER(er.nombre) IN ('pendiente', 'confirmada')
           AND r.fecha_ingreso < $3::date
           AND r.fecha_salida > $2::date
         LIMIT 1`,
        [idHabitacion, fechaIngreso, fechaSalida]
    );

    if (cruce.rows.length > 0) {
        const error = new Error('La habitacion ya no esta disponible en ese rango de fechas.');
        error.status = 409;
        throw error;
    }

    const montoTotal = diasEntre(fechaIngreso, fechaSalida) * Number(habitacion.precio_noche);

    for (let intento = 0; intento < 5; intento++) {
        try {
            const query = `
                INSERT INTO reserva (
                    id_usuario,
                    id_habitacion,
                    id_estado_reserva,
                    fecha_ingreso,
                    fecha_salida,
                    cantidad_personas,
                    monto_total,
                    codigo_reserva
                )
                VALUES (
                    $1,
                    $2,
                    (SELECT id_estado_reserva FROM estado_reserva WHERE nombre = $3 LIMIT 1),
                    $4,
                    $5,
                    $6,
                    $7,
                    $8
                )
                RETURNING *
            `;

            const result = await client.query(query, [
                idUsuario,
                idHabitacion,
                estadoInicial,
                fechaIngreso,
                fechaSalida,
                cantidadPersonas,
                montoTotal.toFixed(2),
                crearCodigoReserva(),
            ]);

            await sincronizarEstadosHabitacion(client);
            return result.rows[0];
        } catch (error) {
            if (error.code !== '23505' || intento === 4) {
                throw error;
            }
        }
    }
};

const obtenerMisReservas = async (req, res) => {
    const idUsuario = req.usuario.id;

    try {
        await sincronizarEstadosHabitacion();

        const query = `
            SELECT
                r.id_reserva,
                r.fecha_ingreso,
                r.fecha_salida,
                ${estadoLegibleSql('er')} AS estado_reserva,
                r.monto_total,
                r.codigo_reserva,
                r.cantidad_personas,
                (r.fecha_salida - r.fecha_ingreso) AS noches,
                h.numero_habitacion,
                h.precio_noche,
                h.capacidad,
                t.nombre_tipo AS tipo_habitacion,
                ${pagoLegibleSql} AS estado_pago,
                ${metodoLegibleSql} AS metodo_pago,
                c.url_imagen AS imagen_comprobante
            FROM reserva r
            JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
            JOIN habitacion h ON r.id_habitacion = h.id_habitacion
            JOIN tipo_habitacion t ON h.id_tipo = t.id_tipo
            LEFT JOIN LATERAL (
                SELECT *
                FROM pago pago_actual
                WHERE pago_actual.id_reserva = r.id_reserva
                ORDER BY pago_actual.id_pago DESC
                LIMIT 1
            ) p ON TRUE
            LEFT JOIN estado_pago ep ON p.id_estado_pago = ep.id_estado_pago
            LEFT JOIN metodo_pago mp ON p.id_metodo_pago = mp.id_metodo_pago
            LEFT JOIN comprobante c ON p.id_pago = c.id_pago
            WHERE r.id_usuario = $1
              AND r.deleted_at IS NULL
            ORDER BY r.id_reserva DESC
        `;
        const resultado = await db.query(query, [idUsuario]);
        res.json(resultado.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener tus reservas: ' + error.message });
    }
};

const obtenerTodasReservas = async (req, res) => {
    try {
        await sincronizarEstadosHabitacion();

        const query = `
            SELECT
                r.id_reserva,
                r.fecha_ingreso,
                r.fecha_salida,
                ${estadoLegibleSql('er')} AS estado_reserva,
                r.monto_total,
                r.codigo_reserva,
                r.cantidad_personas,
                (r.fecha_salida - r.fecha_ingreso) AS noches,
                u.nombre AS nombre_cliente,
                u.correo AS correo_cliente,
                h.numero_habitacion,
                h.precio_noche,
                h.capacidad,
                t.nombre_tipo AS tipo_habitacion,
                ${pagoLegibleSql} AS estado_pago,
                ${metodoLegibleSql} AS metodo_pago,
                c.url_imagen AS imagen
            FROM reserva r
            JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
            JOIN usuario u ON r.id_usuario = u.id_usuario
            JOIN habitacion h ON r.id_habitacion = h.id_habitacion
            JOIN tipo_habitacion t ON h.id_tipo = t.id_tipo
            LEFT JOIN LATERAL (
                SELECT *
                FROM pago pago_actual
                WHERE pago_actual.id_reserva = r.id_reserva
                ORDER BY pago_actual.id_pago DESC
                LIMIT 1
            ) p ON TRUE
            LEFT JOIN estado_pago ep ON p.id_estado_pago = ep.id_estado_pago
            LEFT JOIN metodo_pago mp ON p.id_metodo_pago = mp.id_metodo_pago
            LEFT JOIN comprobante c ON p.id_pago = c.id_pago
            WHERE r.deleted_at IS NULL
            ORDER BY r.id_reserva DESC
        `;
        const resultado = await db.query(query);
        res.json(resultado.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener todas las reservas: ' + error.message });
    }
};

const crearReserva = async (req, res) => {
    const idHabitacion = Number(req.body.id_habitacion);
    const fechaIngreso = req.body.fecha_ingreso;
    const fechaSalida = req.body.fecha_salida;
    const cantidadPersonas = Number(req.body.cantidad_personas || 1);
    const idUsuario = req.usuario.id;

    if (!Number.isInteger(idHabitacion) || idHabitacion <= 0) {
        return res.status(400).json({ error: 'La habitacion seleccionada no es valida.' });
    }

    if (!esFechaValida(fechaIngreso) || !esFechaValida(fechaSalida)) {
        return res.status(400).json({ error: 'Las fechas deben tener formato YYYY-MM-DD.' });
    }

    if (fechaUtc(fechaIngreso) < hoyUtc()) {
        return res.status(400).json({ error: 'La fecha de ingreso no puede ser una fecha pasada.' });
    }

    const diasEstancia = diasEntre(fechaIngreso, fechaSalida);
    if (diasEstancia <= 0) {
        return res.status(400).json({ error: 'La fecha de salida debe ser posterior a la fecha de ingreso.' });
    }

    if (!Number.isInteger(cantidadPersonas) || cantidadPersonas < 1) {
        return res.status(400).json({ error: 'La cantidad de personas debe ser mayor a cero.' });
    }

    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        const nuevaReserva = await crearReservaParaUsuario({
            client,
            idUsuario,
            idHabitacion,
            fechaIngreso,
            fechaSalida,
            cantidadPersonas,
        });

        await client.query('COMMIT');
        res.status(201).json({ mensaje: 'Reserva creada con exito', reserva: nuevaReserva });
    } catch (error) {
        await client.query('ROLLBACK');
        if (error.code === '23P01') {
            return res.status(409).json({ error: 'La habitacion ya no esta disponible en ese rango de fechas.' });
        }
        if (error.status) {
            return res.status(error.status).json({ error: error.message });
        }
        res.status(500).json({ error: 'Error al crear la reserva: ' + error.message });
    } finally {
        client.release();
    }
};

const crearReservaAdmin = async (req, res) => {
    const idHabitacion = Number(req.body.id_habitacion);
    const fechaIngreso = req.body.fecha_ingreso;
    const fechaSalida = req.body.fecha_salida;
    const cantidadPersonas = Number(req.body.cantidad_personas || 1);
    const estadoInicial = normalizarEstado(req.body.estado_reserva || 'confirmada');

    if (!Number.isInteger(idHabitacion) || idHabitacion <= 0) {
        return res.status(400).json({ error: 'La habitacion seleccionada no es valida.' });
    }

    if (!esFechaValida(fechaIngreso) || !esFechaValida(fechaSalida)) {
        return res.status(400).json({ error: 'Las fechas deben tener formato YYYY-MM-DD.' });
    }

    if (fechaUtc(fechaIngreso) < hoyUtc()) {
        return res.status(400).json({ error: 'La fecha de ingreso no puede ser una fecha pasada.' });
    }

    const diasEstancia = diasEntre(fechaIngreso, fechaSalida);
    if (diasEstancia <= 0) {
        return res.status(400).json({ error: 'La fecha de salida debe ser posterior a la fecha de ingreso.' });
    }

    if (!Number.isInteger(cantidadPersonas) || cantidadPersonas < 1) {
        return res.status(400).json({ error: 'La cantidad de personas debe ser mayor a cero.' });
    }

    if (!['pendiente', 'confirmada'].includes(estadoInicial)) {
        return res.status(400).json({ error: 'El estado inicial debe ser Pendiente o Confirmada.' });
    }

    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        const idUsuario = await obtenerOCrearCliente(client, req.body.cliente || req.body);
        const nuevaReserva = await crearReservaParaUsuario({
            client,
            idUsuario,
            idHabitacion,
            fechaIngreso,
            fechaSalida,
            cantidadPersonas,
            estadoInicial,
        });

        await client.query('COMMIT');
        res.status(201).json({ mensaje: 'Reserva registrada por administrador', reserva: nuevaReserva });
    } catch (error) {
        await client.query('ROLLBACK');
        if (error.code === '23P01') {
            return res.status(409).json({ error: 'La habitacion ya no esta disponible en ese rango de fechas.' });
        }
        if (error.status) {
            return res.status(error.status).json({ error: error.message });
        }
        res.status(500).json({ error: 'Error al registrar la reserva admin: ' + error.message });
    } finally {
        client.release();
    }
};

const liberarHabitacion = async (req, res) => {
    const idReserva = Number(req.params.id);

    if (!Number.isInteger(idReserva) || idReserva <= 0) {
        return res.status(400).json({ error: 'Reserva invalida.' });
    }

    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        const reserva = await client.query(
            `SELECT id_reserva, id_habitacion
             FROM reserva
             WHERE id_reserva = $1
               AND deleted_at IS NULL
             FOR UPDATE`,
            [idReserva]
        );

        if (reserva.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Reserva no encontrada.' });
        }

        const idHabitacion = reserva.rows[0].id_habitacion;

        const resultado = await client.query(
            `UPDATE reserva
             SET id_estado_reserva = (
                    SELECT id_estado_reserva
                    FROM estado_reserva
                    WHERE nombre = 'completada'
                    LIMIT 1
                 )
             WHERE id_reserva = $1
             RETURNING *`,
            [idReserva]
        );

        await client.query(
            `UPDATE habitacion
             SET id_estado_habitacion = (
                    SELECT id_estado_habitacion
                    FROM estado_habitacion
                    WHERE nombre = 'disponible'
                    LIMIT 1
                 )
             WHERE id_habitacion = $1
               AND id_estado_habitacion <> (
                    SELECT id_estado_habitacion
                    FROM estado_habitacion
                    WHERE nombre = 'mantenimiento'
                    LIMIT 1
               )`,
            [idHabitacion]
        );

        await sincronizarEstadosHabitacion(client);
        await client.query('COMMIT');
        res.json({ mensaje: 'Habitacion liberada con exito.', reserva: resultado.rows[0] });
    } catch (error) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: 'Error al liberar la habitacion: ' + error.message });
    } finally {
        client.release();
    }
};

const confirmarReserva = async (req, res) => {
    const idReserva = Number(req.params.id);
    const estadoReserva = normalizarEstado(req.body.estado_reserva);

    if (!Number.isInteger(idReserva) || idReserva <= 0) {
        return res.status(400).json({ error: 'Reserva invalida.' });
    }

    if (!ESTADOS_RESERVA.includes(estadoReserva)) {
        return res.status(400).json({ error: 'Estado de reserva invalido.' });
    }

    const client = await db.getClient();

    try {
        await client.query('BEGIN');

        const resultado = await client.query(
            `UPDATE reserva
             SET id_estado_reserva = (
                SELECT id_estado_reserva
                FROM estado_reserva
                WHERE nombre = $1
                LIMIT 1
             )
             WHERE id_reserva = $2
             RETURNING *`,
            [estadoReserva, idReserva]
        );

        if (resultado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Reserva no encontrada' });
        }

        if (estadoReserva === 'confirmada') {
            await client.query(
                `UPDATE pago
                 SET id_estado_pago = (SELECT id_estado_pago FROM estado_pago WHERE nombre = 'pagado' LIMIT 1)
                 WHERE id_reserva = $1
                   AND id_estado_pago = (SELECT id_estado_pago FROM estado_pago WHERE nombre = 'pendiente' LIMIT 1)`,
                [idReserva]
            );
        }

        await sincronizarEstadosHabitacion(client);
        await client.query('COMMIT');
        res.json({ mensaje: 'Reserva actualizada con exito', reserva: resultado.rows[0] });
    } catch (error) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: 'Error al actualizar la reserva: ' + error.message });
    } finally {
        client.release();
    }
};

module.exports = {
    obtenerMisReservas,
    obtenerTodasReservas,
    crearReserva,
    crearReservaAdmin,
    confirmarReserva,
    liberarHabitacion,
};
