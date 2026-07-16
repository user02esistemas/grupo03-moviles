const express = require('express');
const router = express.Router();
const habController = require('../controllers/habitacionController');
const db = require('../db');

router.get('/tipos', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT
                t.id_tipo,
                t.nombre_tipo,
                t.descripcion,
                COALESCE(array_remove(array_agg(DISTINCT s.nombre ORDER BY s.nombre), NULL), '{}') AS servicios_lista
            FROM tipo_habitacion t
            LEFT JOIN tipo_habitacion_servicio ths ON t.id_tipo = ths.id_tipo
            LEFT JOIN servicio s ON ths.id_servicio = s.id_servicio
            GROUP BY t.id_tipo, t.nombre_tipo, t.descripcion
            ORDER BY t.id_tipo ASC
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener tipos de habitacion: ' + error.message });
    }
});

router.get('/disponibles', habController.listarDisponibles);
router.get('/', habController.buscarHabitaciones);

module.exports = router;
