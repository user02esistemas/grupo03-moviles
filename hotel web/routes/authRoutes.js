const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
// Importamos el middleware para asegurar que solo los logueados vean su perfil
const { verificarToken } = require('../middlewares/authMiddleware'); 

router.post('/registro', authController.registrar);
router.post('/login', authController.login);
router.post('/google', authController.googleLogin);

// NUEVAS RUTAS DE PERFIL
router.get('/perfil', verificarToken, authController.obtenerPerfil);
router.put('/perfil', verificarToken, authController.actualizarPerfil);

module.exports = router;