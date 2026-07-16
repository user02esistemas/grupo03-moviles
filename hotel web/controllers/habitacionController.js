const db = require('../db');

const fechaValida = (fecha) => /^\d{4}-\d{2}-\d{2}$/.test(String(fecha || ''));

const sincronizarEstadosHabitacion = async (client = db) => {
    await client.query(`
        UPDATE habitacion h
        SET id_estado_habitacion = CASE
            WHEN EXISTS (
                SELECT 1
                FROM reserva r
                JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
                WHERE r.id_habitacion = h.id_habitacion
                  AND r.deleted_at IS NULL
                  AND er.nombre IN ('pendiente', 'confirmada')
                  AND CURRENT_DATE >= r.fecha_ingreso
                  AND CURRENT_DATE < r.fecha_salida
            )
            THEN (SELECT id_estado_habitacion FROM estado_habitacion WHERE nombre = 'reservada' LIMIT 1)
            ELSE (SELECT id_estado_habitacion FROM estado_habitacion WHERE nombre = 'disponible' LIMIT 1)
        END
        WHERE h.id_estado_habitacion <> (SELECT id_estado_habitacion FROM estado_habitacion WHERE nombre = 'mantenimiento' LIMIT 1)
    `);
};

const selectHabitaciones = `
    SELECT
        h.id_habitacion,
        h.id_tipo,
        h.numero_habitacion,
        h.descripcion,
        h.precio_noche,
        h.capacidad,
        eh.nombre AS disponibilidad,
        img.url AS imagen,
        t.nombre_tipo AS tipo_habitacion,
        t.descripcion AS descripcion_tipo,
        COALESCE(array_remove(array_agg(DISTINCT s.nombre ORDER BY s.nombre), NULL), '{}') AS servicios
    FROM habitacion h
    JOIN tipo_habitacion t ON h.id_tipo = t.id_tipo
    JOIN estado_habitacion eh ON h.id_estado_habitacion = eh.id_estado_habitacion
    LEFT JOIN LATERAL (
        SELECT hi.url
        FROM habitacion_imagen hi
        WHERE hi.id_habitacion = h.id_habitacion
        ORDER BY hi.es_principal DESC, hi.orden ASC, hi.id_imagen ASC
        LIMIT 1
    ) img ON TRUE
    LEFT JOIN tipo_habitacion_servicio ths ON t.id_tipo = ths.id_tipo
    LEFT JOIN servicio s ON ths.id_servicio = s.id_servicio
`;

const groupHabitaciones = `
    GROUP BY
        h.id_habitacion,
        h.id_tipo,
        h.numero_habitacion,
        h.descripcion,
        h.precio_noche,
        h.capacidad,
        eh.nombre,
        img.url,
        t.nombre_tipo,
        t.descripcion
    ORDER BY h.numero_habitacion ASC
`;

const listarDisponibles = async (req, res) => {
    const { fecha_ingreso, fecha_salida, id_tipo } = req.query;

    if (!fechaValida(fecha_ingreso) || !fechaValida(fecha_salida)) {
        return res.status(400).json({ error: 'Debes enviar fecha_ingreso y fecha_salida en formato YYYY-MM-DD.' });
    }

    if (new Date(fecha_salida) <= new Date(fecha_ingreso)) {
        return res.status(400).json({ error: 'La fecha de salida debe ser posterior a la fecha de ingreso.' });
    }

    try {
        await sincronizarEstadosHabitacion();

        let query = `
            ${selectHabitaciones}
            WHERE LOWER(eh.nombre) <> 'mantenimiento'
              AND NOT EXISTS (
                SELECT 1
                FROM reserva r
                JOIN estado_reserva er ON r.id_estado_reserva = er.id_estado_reserva
                WHERE r.id_habitacion = h.id_habitacion
                  AND r.deleted_at IS NULL
                  AND LOWER(er.nombre) IN ('pendiente', 'confirmada')
                  AND r.fecha_ingreso < $2::date
                  AND r.fecha_salida > $1::date
            )
        `;

        const params = [fecha_ingreso, fecha_salida];

        if (id_tipo) {
            query += ' AND h.id_tipo = $3';
            params.push(Number(id_tipo));
        }

        query += groupHabitaciones;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error al consultar disponibilidad: ' + error.message });
    }
};

const buscarHabitaciones = async (req, res) => {
    const { tipo, capacidad } = req.query;

    let query = `
        ${selectHabitaciones}
        WHERE LOWER(eh.nombre) <> 'mantenimiento'
    `;
    const values = [];

    if (tipo) {
        values.push(Number(tipo));
        query += ` AND h.id_tipo = $${values.length}`;
    }

    if (capacidad) {
        values.push(Number(capacidad));
        query += ` AND h.capacidad >= $${values.length}`;
    }

    query += groupHabitaciones;

    try {
        await sincronizarEstadosHabitacion();
        const result = await db.query(query, values);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error al filtrar el catalogo: ' + error.message });
    }
};

module.exports = {
    listarDisponibles,
    buscarHabitaciones,
    sincronizarEstadosHabitacion,
};
