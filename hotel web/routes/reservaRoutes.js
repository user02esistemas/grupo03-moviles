const express = require('express');
const router = express.Router();
const { verificarToken, esAdmin } = require('../middlewares/authMiddleware');
const reservaController = require('../controllers/reservaController');

// Rutas para CLIENTES (Solo requieren estar logueados)
router.get('/mis-reservas', verificarToken, reservaController.obtenerMisReservas);

// CORRECCIÓN: Cambiamos '/reservar' por '/' para que coincida exactamente con la llamada de Axios
router.post('/', verificarToken, reservaController.crearReserva);

// Rutas para el ADMINISTRADOR (Requieren estar logueado Y ser admin)
router.get('/admin/reservas', verificarToken, esAdmin, reservaController.obtenerTodasReservas);
router.post('/admin/reservas', verificarToken, esAdmin, reservaController.crearReservaAdmin);
router.put('/admin/reservas/:id', verificarToken, esAdmin, reservaController.confirmarReserva);
router.put('/admin/reservas/:id/liberar', verificarToken, esAdmin, reservaController.liberarHabitacion);

module.exports = router;
