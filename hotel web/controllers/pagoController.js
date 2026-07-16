const path = require('path');
const db = require('../db');
const { MercadoPagoConfig, Preference, Payment } = require('mercadopago');

const client = new MercadoPagoConfig({ accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN || '' });
const FACTOR_IGV = 1.18;

const totalConIgv = (montoBase) => Number((Number(montoBase) * FACTOR_IGV).toFixed(2));

const normalizar = (valor) => String(valor || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[\/\s-]+/g, '_');

const mapMetodoManual = (metodo) => {
    const valor = normalizar(metodo);
    if (['yape', 'plin', 'yape_plin'].includes(valor)) return 'yape_plin';
    if (valor === 'transferencia') return 'transferencia';
    return null;
};

const mapMetodoMercadoPago = (detalle) => {
    const tipo = normalizar(detalle.payment_type_id || detalle.payment_method_id);
    if (tipo.includes('debit')) return 'tarjeta_debito';
    if (tipo.includes('credit')) return 'tarjeta_credito';
    return 'tarjeta_credito';
};

const mapEstadoMercadoPago = (status) => {
    if (status === 'approved') return 'pagado';
    if (status === 'rejected') return 'rechazado';
    return 'pendiente';
};

const frontendPublico = () => {
    const valor = process.env.PUBLIC_FRONTEND_URL || process.env.FRONTEND_URL || 'http://localhost:5173';
    return String(valor).split(',')[0].trim().replace(/\/$/, '');
};

const obtenerIdPorNombre = async (clientDb, tabla, columnaId, nombre) => {
    const result = await clientDb.query(
        `SELECT ${columnaId} AS id FROM ${tabla} WHERE nombre = $1 LIMIT 1`,
        [nombre]
    );

    if (result.rows.length === 0) {
        throw new Error(`No existe ${tabla}.${nombre} en la base actual.`);
    }

    return result.rows[0].id;
};

const guardarPago = async (clientDb, { idReserva, monto, metodo, estado }) => {
    const idMetodoPago = await obtenerIdPorNombre(clientDb, 'metodo_pago', 'id_metodo_pago', metodo);
    const idEstadoPago = await obtenerIdPorNombre(clientDb, 'estado_pago', 'id_estado_pago', estado);

    const pagoActual = await clientDb.query(
        `SELECT id_pago
         FROM pago
         WHERE id_reserva = $1
         ORDER BY id_pago DESC
         LIMIT 1`,
        [idReserva]
    );

    if (pagoActual.rows.length > 0) {
        const actualizado = await clientDb.query(
            `UPDATE pago
             SET monto = $1,
                 id_metodo_pago = $2,
                 id_estado_pago = $3,
                 fecha_pago = NOW()
             WHERE id_pago = $4
             RETURNING id_pago`,
            [monto, idMetodoPago, idEstadoPago, pagoActual.rows[0].id_pago]
        );
        return actualizado.rows[0].id_pago;
    }

    const creado = await clientDb.query(
        `INSERT INTO pago (id_reserva, monto, id_metodo_pago, id_estado_pago)
         VALUES ($1, $2, $3, $4)
         RETURNING id_pago`,
        [idReserva, monto, idMetodoPago, idEstadoPago]
    );
    return creado.rows[0].id_pago;
};

const obtenerReservaDelUsuario = async (clientDb, idReserva, idUsuario) => {
    const result = await clientDb.query(
        `SELECT r.id_reserva, r.monto_total, er.nombre AS estado_reserva, h.numero_habitacion, u.correo
         FROM reserva r
         JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
         JOIN habitacion h ON r.id_habitacion = h.id_habitacion
         JOIN usuario u ON r.id_usuario = u.id_usuario
         WHERE r.id_reserva = $1
           AND r.id_usuario = $2
           AND r.deleted_at IS NULL`,
        [idReserva, idUsuario]
    );

    return result.rows[0];
};

const subirComprobante = async (req, res) => {
    const idReserva = Number(req.body.id_reserva);
    const metodoPago = mapMetodoManual(req.body.metodo_pago);

    if (!req.file) {
        return res.status(400).json({ error: 'No se proceso ningun archivo. Intenta subir el comprobante nuevamente.' });
    }

    if (!Number.isInteger(idReserva) || idReserva <= 0) {
        return res.status(400).json({ error: 'La reserva no es valida.' });
    }

    if (!metodoPago) {
        return res.status(400).json({ error: 'Selecciona un metodo de pago valido.' });
    }

    const imagenUrl = path.posix.join('uploads', req.file.filename);
    const clientDb = await db.getClient();

    try {
        await clientDb.query('BEGIN');

        const reserva = await obtenerReservaDelUsuario(clientDb, idReserva, req.usuario.id);
        if (!reserva) {
            await clientDb.query('ROLLBACK');
            return res.status(404).json({ error: 'Reserva no encontrada para este usuario.' });
        }

        if (reserva.estado_reserva === 'cancelada') {
            await clientDb.query('ROLLBACK');
            return res.status(409).json({ error: 'No se puede pagar una reserva cancelada.' });
        }

        const idPago = await guardarPago(clientDb, {
            idReserva,
            monto: totalConIgv(reserva.monto_total),
            metodo: metodoPago,
            estado: 'pendiente',
        });

        await clientDb.query(
            `INSERT INTO comprobante (id_pago, url_imagen, fecha_subida)
             VALUES ($1, $2, NOW())
             ON CONFLICT (id_pago)
             DO UPDATE SET url_imagen = EXCLUDED.url_imagen,
                           fecha_subida = NOW()`,
            [idPago, imagenUrl]
        );

        await clientDb.query('COMMIT');
        res.status(201).json({ mensaje: 'Comprobante subido con exito, pendiente de validacion' });
    } catch (error) {
        await clientDb.query('ROLLBACK');
        res.status(500).json({ error: 'Error al subir comprobante: ' + error.message });
    } finally {
        clientDb.release();
    }
};

const crearPreferencia = async (req, res) => {
    const idReserva = Number(req.body.id_reserva);

    if (!process.env.MERCADOPAGO_ACCESS_TOKEN) {
        return res.status(500).json({ error: 'MERCADOPAGO_ACCESS_TOKEN no esta configurado.' });
    }

    if (!Number.isInteger(idReserva) || idReserva <= 0) {
        return res.status(400).json({ error: 'La reserva no es valida.' });
    }

    const clientDb = await db.getClient();

    try {
        const reserva = await obtenerReservaDelUsuario(clientDb, idReserva, req.usuario.id);
        if (!reserva) {
            return res.status(404).json({ error: 'Reserva no encontrada para este usuario.' });
        }

        if (reserva.estado_reserva === 'cancelada') {
            return res.status(409).json({ error: 'No se puede pagar una reserva cancelada.' });
        }

        const montoFinal = totalConIgv(reserva.monto_total);
        const preference = new Preference(client);
        const frontendUrl = frontendPublico();

        const result = await preference.create({
            body: {
                items: [
                    {
                        id: String(idReserva),
                        title: `Reserva Habitacion ${reserva.numero_habitacion}`,
                        quantity: 1,
                        unit_price: montoFinal,
                        currency_id: 'PEN',
                    },
                ],
                payer: {
                    email: reserva.correo,
                },
                external_reference: String(idReserva),
                metadata: {
                    id_reserva: idReserva,
                },
                back_urls: {
                    success: `${frontendUrl}/mis-reservas`,
                    failure: `${frontendUrl}/mis-reservas`,
                    pending: `${frontendUrl}/mis-reservas`,
                },
                ...(process.env.MERCADOPAGO_WEBHOOK_URL
                    ? { notification_url: process.env.MERCADOPAGO_WEBHOOK_URL }
                    : {}),
            },
        });

        res.json({ id: result.id, init_point: result.init_point });
    } catch (error) {
        console.error('Error en Mercado Pago:', error.message);
        res.status(500).json({ error: 'No se pudo conectar con Mercado Pago.' });
    } finally {
        clientDb.release();
    }
};

const recibirNotificacion = async (req, res) => {
    const paymentId = req.body?.data?.id || req.query?.['data.id'] || req.query?.id;

    if (!paymentId) {
        return res.status(200).json({ recibido: true });
    }

    if (!process.env.MERCADOPAGO_ACCESS_TOKEN) {
        console.error('MERCADOPAGO_ACCESS_TOKEN no esta configurado para procesar webhook.');
        return res.status(200).json({ recibido: true });
    }

    try {
        const payment = new Payment(client);
        const detalle = await payment.get({ id: paymentId });
        const idReserva = Number(detalle.external_reference || detalle.metadata?.id_reserva);

        if (!Number.isInteger(idReserva) || idReserva <= 0) {
            console.error('Webhook sin id_reserva valido:', paymentId);
            return res.status(200).json({ recibido: true });
        }

        const estadoPago = mapEstadoMercadoPago(detalle.status);
        const metodoPago = mapMetodoMercadoPago(detalle);
        const monto = Number(detalle.transaction_amount || 0);
        const clientDb = await db.getClient();

        try {
            await clientDb.query('BEGIN');

            await guardarPago(clientDb, {
                idReserva,
                monto,
                metodo: metodoPago,
                estado: estadoPago,
            });

            if (estadoPago === 'pagado') {
                await clientDb.query(
                    `UPDATE reserva
                     SET id_estado_reserva = (
                        SELECT id_estado_reserva
                        FROM estado_reserva
                        WHERE nombre = 'confirmada'
                        LIMIT 1
                     )
                     WHERE id_reserva = $1`,
                    [idReserva]
                );
            }

            await clientDb.query('COMMIT');
        } catch (error) {
            await clientDb.query('ROLLBACK');
            throw error;
        } finally {
            clientDb.release();
        }

        res.status(200).json({ recibido: true });
    } catch (error) {
        console.error('Error procesando webhook de Mercado Pago:', error.message);
        res.status(200).json({ recibido: true });
    }
};

module.exports = { subirComprobante, crearPreferencia, recibirNotificacion };
